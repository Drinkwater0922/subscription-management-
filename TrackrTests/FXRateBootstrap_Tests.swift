import XCTest
import SwiftData
@testable import Trackr

/// Tests for `FXRateBootstrap` — the seed-on-first-launch + refresh-when-stale
/// service that keeps `FXRateTable` populated for the v1.1 Home hero.
@MainActor
final class FXRateBootstrapTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - Seed-from-fallback when no table exists

    func test_seedIfNeeded_writesFallback_whenNoTable() throws {
        let repo = FXRateTableRepository(context: context)
        let fallback = FXFallbackLoader.Bundle(
            baseCurrency: "USD",
            fetchedAt: Date(timeIntervalSince1970: 0),
            rates: ["CNY": Decimal(string: "7.2")!, "EUR": Decimal(string: "0.92")!]
        )

        FXRateBootstrap.seedIfNeeded(repository: repo, fallback: fallback)

        let table = try XCTUnwrap(try repo.current())
        XCTAssertEqual(table.baseCurrency, "USD")
        XCTAssertEqual(table.decodedRates["CNY"], Decimal(string: "7.2"))
    }

    func test_seedIfNeeded_isNoOp_whenTableAlreadyExists() throws {
        let repo = FXRateTableRepository(context: context)
        try repo.replace(baseCurrency: "USD",
                         rates: ["CNY": Decimal(string: "9.9")!],
                         fetchedAt: Date(timeIntervalSince1970: 1_000))

        let fallback = FXFallbackLoader.Bundle(
            baseCurrency: "USD",
            fetchedAt: Date(timeIntervalSince1970: 0),
            rates: ["CNY": Decimal(string: "7.2")!]
        )

        FXRateBootstrap.seedIfNeeded(repository: repo, fallback: fallback)

        // The pre-existing 9.9 rate must NOT be overwritten by the bundled
        // 7.2 fallback — the cached table is always fresher than the bundle.
        let table = try XCTUnwrap(try repo.current())
        XCTAssertEqual(table.decodedRates["CNY"], Decimal(string: "9.9"))
    }

    // MARK: - Refresh-when-stale via FXLatestRatesClient

    func test_refreshIfStale_refreshes_whenOlderThan24Hours() async throws {
        let repo = FXRateTableRepository(context: context)
        let stale = Date(timeIntervalSinceNow: -25 * 3600)
        try repo.replace(baseCurrency: "USD",
                         rates: ["CNY": Decimal(string: "7.0")!],
                         fetchedAt: stale)

        let fakeClient = FakeFXLatestRatesClient(
            rates: ["CNY": Decimal(string: "7.5")!, "EUR": Decimal(string: "0.90")!]
        )

        let didRefresh = await FXRateBootstrap.refreshIfStale(
            repository: repo,
            client: fakeClient,
            now: Date()
        )

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(fakeClient.callCount, 1)
        let table = try XCTUnwrap(try repo.current())
        XCTAssertEqual(table.decodedRates["CNY"], Decimal(string: "7.5"))
        XCTAssertEqual(table.decodedRates["EUR"], Decimal(string: "0.90"))
    }

    func test_refreshIfStale_skips_whenWithin24Hours() async throws {
        let repo = FXRateTableRepository(context: context)
        let fresh = Date(timeIntervalSinceNow: -2 * 3600)
        try repo.replace(baseCurrency: "USD",
                         rates: ["CNY": Decimal(string: "7.0")!],
                         fetchedAt: fresh)

        let fakeClient = FakeFXLatestRatesClient(
            rates: ["CNY": Decimal(string: "999")!]
        )

        let didRefresh = await FXRateBootstrap.refreshIfStale(
            repository: repo,
            client: fakeClient,
            now: Date()
        )

        XCTAssertFalse(didRefresh)
        XCTAssertEqual(fakeClient.callCount, 0,
                       "fresh cache must NOT trigger a network call")
        XCTAssertEqual(try repo.current()?.decodedRates["CNY"],
                       Decimal(string: "7.0"))
    }

    func test_refreshIfStale_swallowsNetworkErrors_keepsCachedTable() async throws {
        let repo = FXRateTableRepository(context: context)
        let stale = Date(timeIntervalSinceNow: -48 * 3600)
        try repo.replace(baseCurrency: "USD",
                         rates: ["CNY": Decimal(string: "7.0")!],
                         fetchedAt: stale)

        let failingClient = FakeFXLatestRatesClient(error: FXError.network("offline"))

        let didRefresh = await FXRateBootstrap.refreshIfStale(
            repository: repo,
            client: failingClient,
            now: Date()
        )

        XCTAssertFalse(didRefresh, "network failure must not signal a refresh")
        // The old rate is still readable — the user keeps seeing converted
        // totals even if the refresh fails.
        XCTAssertEqual(try repo.current()?.decodedRates["CNY"],
                       Decimal(string: "7.0"))
    }

    func test_refreshIfStale_doesNotTouchTable_whenEmptyResult() async throws {
        let repo = FXRateTableRepository(context: context)
        let stale = Date(timeIntervalSinceNow: -48 * 3600)
        try repo.replace(baseCurrency: "USD",
                         rates: ["CNY": Decimal(string: "7.0")!],
                         fetchedAt: stale)

        // Defensive: a successful response with zero rates is suspicious;
        // we treat it as a soft failure and keep the cached table rather
        // than wiping it.
        let emptyClient = FakeFXLatestRatesClient(rates: [:])

        let didRefresh = await FXRateBootstrap.refreshIfStale(
            repository: repo,
            client: emptyClient,
            now: Date()
        )

        XCTAssertFalse(didRefresh)
        XCTAssertEqual(try repo.current()?.decodedRates["CNY"],
                       Decimal(string: "7.0"))
    }
}

// MARK: - Test doubles

private final class FakeFXLatestRatesClient: FXLatestRatesClient {
    let rates: [String: Decimal]
    let error: Error?
    private(set) var callCount = 0

    init(rates: [String: Decimal] = [:], error: Error? = nil) {
        self.rates = rates
        self.error = error
    }

    func latestRates(base: String) async throws -> [String: Decimal] {
        callCount += 1
        if let error { throw error }
        return rates
    }
}
