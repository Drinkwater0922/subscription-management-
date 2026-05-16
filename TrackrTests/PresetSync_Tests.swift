import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class PresetSyncTests: XCTestCase {

    private var container: ModelContainer!
    private var fetcher: FakePresetFetcher!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        fetcher = FakePresetFetcher()
    }

    override func tearDownWithError() throws {
        fetcher = nil
        container = nil
        try super.tearDownWithError()
    }

    private func catalog(version: String, amountForA: String = "10") throws -> PresetCatalog {
        let json = #"""
        {
          "version": "\#(version)",
          "items": [
            {
              "id": "a",
              "name": "Service A",
              "defaultPlanName": "Standard",
              "defaultAmount": "\#(amountForA)",
              "defaultCurrency": "USD",
              "defaultCycle": "monthly",
              "category": "streaming",
              "iconRef": "preset:a"
            }
          ]
        }
        """#
        return try JSONDecoder().decode(PresetCatalog.self, from: Data(json.utf8))
    }

    private func seedSubscription(presetId: String) throws {
        let sub = Subscription(
            name: "X", amount: 10, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now,
            category: .streaming,
            presetId: presetId
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()
    }

    func test_firstRun_seedsCacheFromRemote_andEmitsNoAlerts() async throws {
        fetcher.result = try catalog(version: "1.0.0")
        let sync = PresetSync(fetcher: fetcher, container: container)

        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        let cached = try container.mainContext.fetch(FetchDescriptor<PresetCache>())
        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(cached.first?.version, "1.0.0")
        let alerts = try AlertRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(alerts.count, 0,
                       "first run has no previous cache → no diff possible")
    }

    func test_sameVersion_noOp() async throws {
        let initial = try catalog(version: "1.0.0")
        let payload = try JSONEncoder().encode(initial)
        let cache = PresetCache(version: "1.0.0", fetchedAt: .now, data: payload)
        container.mainContext.insert(cache)
        try container.mainContext.save()

        fetcher.result = try catalog(version: "1.0.0", amountForA: "999")

        try seedSubscription(presetId: "a")
        let sync = PresetSync(fetcher: fetcher, container: container)

        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        let alerts = try AlertRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(alerts.count, 0,
                       "version match short-circuits the diff path")
    }

    func test_versionBumpWithAmountChange_emitsAlertAndUpdatesCache() async throws {
        let initial = try catalog(version: "1.0.0", amountForA: "10")
        let payload = try JSONEncoder().encode(initial)
        let cache = PresetCache(version: "1.0.0", fetchedAt: .now, data: payload)
        container.mainContext.insert(cache)
        try seedSubscription(presetId: "a")
        try container.mainContext.save()

        fetcher.result = try catalog(version: "1.1.0", amountForA: "12")
        let sync = PresetSync(fetcher: fetcher, container: container)

        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        let alerts = try AlertRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.presetId, "a")
        XCTAssertEqual(alerts.first?.oldAmount, 10)
        XCTAssertEqual(alerts.first?.newAmount, 12)

        let cached = try container.mainContext.fetch(FetchDescriptor<PresetCache>())
        XCTAssertEqual(cached.count, 1, "cache stays a singleton")
        XCTAssertEqual(cached.first?.version, "1.1.0",
                       "cache version flips to the freshly-fetched one")
    }
}
