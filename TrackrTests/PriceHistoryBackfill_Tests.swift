import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class PriceHistoryBackfillTests: XCTestCase {

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

    /// Constructs a Subscription directly (bypassing the v1.1
    /// `SubscriptionRepository.insert` baseline) to simulate a legacy
    /// TestFlight row carried over from v1.0.
    private func insertLegacySub(name: String,
                                  amount: Decimal = 10,
                                  currency: String = "USD") {
        let sub = Subscription(
            name: name,
            amount: amount,
            currency: currency,
            billingCycle: .monthly,
            nextBillingDate: .now,
            startDate: .now,
            category: .other
        )
        context.insert(sub)
        try? context.save()
    }

    func test_run_backfillsLegacySub() throws {
        insertLegacySub(name: "Old Netflix")

        let written = PriceHistoryBackfill.run(context: context)

        XCTAssertEqual(written, 1)
        let sub = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Subscription>()).first
        )
        XCTAssertEqual(sub.priceHistory.count, 1)
        XCTAssertEqual(sub.priceHistory.first?.source, .initial)
        XCTAssertEqual(sub.priceHistory.first?.amount, 10)
        XCTAssertEqual(sub.priceHistory.first?.currency, "USD")
    }

    func test_run_isIdempotent() throws {
        insertLegacySub(name: "Old Netflix")

        let first = PriceHistoryBackfill.run(context: context)
        let second = PriceHistoryBackfill.run(context: context)

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 0, "second pass must not re-backfill")
        let sub = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Subscription>()).first
        )
        XCTAssertEqual(sub.priceHistory.count, 1)
    }

    func test_run_doesNotTouchSubsWithExistingHistory() throws {
        // Sub already has an .initial baseline + a .userEdit row.
        let sub = Subscription(
            name: "Spotify", amount: 10, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .now, startDate: .now, category: .music
        )
        context.insert(sub)
        let initial = PriceHistoryEntry(subscription: sub, amount: 10,
                                         currency: "USD",
                                         recordedAt: .now, source: .initial)
        let edit = PriceHistoryEntry(subscription: sub, amount: 12,
                                      currency: "USD",
                                      recordedAt: .now, source: .userEdit)
        context.insert(initial)
        context.insert(edit)
        try context.save()

        let written = PriceHistoryBackfill.run(context: context)

        XCTAssertEqual(written, 0)
        XCTAssertEqual(sub.priceHistory.count, 2,
                       "must not append another .initial when history already exists")
    }

    func test_run_emptyStore_isNoOp() {
        XCTAssertEqual(PriceHistoryBackfill.run(context: context), 0)
    }

    func test_run_mixedSubs_onlyBackfillsLegacyOnes() throws {
        // One legacy + one v1.1 sub created through the repository.
        insertLegacySub(name: "Legacy")
        let v11 = Subscription(name: "Hulu", amount: 20, currency: "USD",
                                billingCycle: .monthly,
                                nextBillingDate: .now, startDate: .now,
                                category: .streaming)
        try SubscriptionRepository(context: context).insert(v11)

        let written = PriceHistoryBackfill.run(context: context)
        XCTAssertEqual(written, 1, "only the legacy sub should get a baseline")

        let legacy = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Subscription>())
                .first(where: { $0.name == "Legacy" })
        )
        XCTAssertEqual(legacy.priceHistory.count, 1)
        XCTAssertEqual(v11.priceHistory.count, 1)
    }
}
