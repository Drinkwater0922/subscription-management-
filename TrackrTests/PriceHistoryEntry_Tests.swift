import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class PriceHistoryEntryTests: XCTestCase {

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

    // MARK: - Model basics

    func test_canBeInsertedAndFetched() throws {
        let entry = PriceHistoryEntry(amount: 9.99, currency: "USD",
                                       source: .userEdit)
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PriceHistoryEntry>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.amount, Decimal(string: "9.99"))
        XCTAssertEqual(fetched.first?.currency, "USD")
        XCTAssertEqual(fetched.first?.source, .userEdit)
    }

    func test_sourceEnum_allCasesPersistRoundTrip() throws {
        for source in PriceHistorySource.allCases {
            let entry = PriceHistoryEntry(amount: 1, currency: "USD",
                                           source: source)
            context.insert(entry)
        }
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<PriceHistoryEntry>())
        XCTAssertEqual(Set(fetched.map(\.source)),
                       Set(PriceHistorySource.allCases))
    }

    // MARK: - Repository writes `.initial` baseline on insert

    func test_repositoryInsert_writesInitialBaseline() throws {
        let repo = SubscriptionRepository(context: context)
        let sub = Subscription(
            name: "Netflix", amount: Decimal(string: "15.49")!,
            currency: "USD", billingCycle: .monthly,
            nextBillingDate: .now, startDate: .now, category: .streaming
        )
        try repo.insert(sub)

        let history = try context.fetch(FetchDescriptor<PriceHistoryEntry>())
        XCTAssertEqual(history.count, 1)
        let baseline = try XCTUnwrap(history.first)
        XCTAssertEqual(baseline.source, .initial)
        XCTAssertEqual(baseline.amount, Decimal(string: "15.49"))
        XCTAssertEqual(baseline.currency, "USD")
        XCTAssertEqual(baseline.subscription?.id, sub.id,
                       "baseline should be linked back to its subscription")
    }

    func test_repositoryInsert_baselineRecordedAtMatchesCreatedAt() throws {
        let repo = SubscriptionRepository(context: context)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let sub = Subscription(
            name: "Spotify", amount: 9.99, currency: "USD",
            billingCycle: .monthly, nextBillingDate: .now, startDate: .now,
            category: .music, createdAt: createdAt
        )
        try repo.insert(sub)

        let baseline = try XCTUnwrap(
            context.fetch(FetchDescriptor<PriceHistoryEntry>()).first
        )
        XCTAssertEqual(baseline.recordedAt, createdAt,
                       "baseline timestamp must match the sub's createdAt")
    }

    // MARK: - Relationship + cascade delete

    func test_subscriptionRelationship_exposesEntries() throws {
        let repo = SubscriptionRepository(context: context)
        let sub = Subscription(
            name: "Apple Music", amount: 9.99, currency: "USD",
            billingCycle: .monthly, nextBillingDate: .now, startDate: .now,
            category: .music
        )
        try repo.insert(sub)

        // Add a userEdit entry on top of the auto-written .initial.
        let edit = PriceHistoryEntry(subscription: sub, amount: 10.99,
                                      currency: "USD", source: .userEdit)
        context.insert(edit)
        try context.save()

        XCTAssertEqual(sub.priceHistory.count, 2)
        XCTAssertEqual(Set(sub.priceHistory.map(\.source)),
                       [.initial, .userEdit])
    }

    func test_deletingSubscription_cascadesPriceHistory() throws {
        let repo = SubscriptionRepository(context: context)
        let sub = Subscription(
            name: "Hulu", amount: 7.99, currency: "USD",
            billingCycle: .monthly, nextBillingDate: .now, startDate: .now,
            category: .streaming
        )
        try repo.insert(sub)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<PriceHistoryEntry>()).count, 1
        )

        try repo.delete(sub)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<PriceHistoryEntry>()).count, 0,
            "deleting the sub should cascade-delete its price history"
        )
    }
}
