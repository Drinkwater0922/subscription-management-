import XCTest
import SwiftData
@testable import Trackr

/// Tests for the v1.1 price-history write rules on the
/// `SubscriptionDetailView.applyEdits` path:
///   * Amount change → one `.userEdit` row appended.
///   * Currency change → one `.userEdit` row appended.
///   * Editing other fields (name, notes, URL, category, cycle, trial) →
///     no new row.
///   * Invalid edits (empty name, bad amount) → no mutation, no history.
@MainActor
final class PriceHistoryWriteTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    private func makeSub(amount: Decimal = 10,
                         currency: String = "USD",
                         name: String = "Netflix",
                         notes: String? = nil,
                         url: String? = nil) throws -> Subscription {
        let sub = Subscription(
            name: name,
            amount: amount,
            currency: currency,
            billingCycle: .monthly,
            nextBillingDate: .now,
            startDate: .now,
            category: .streaming,
            notes: notes,
            url: url.flatMap(URL.init(string:))
        )
        try SubscriptionRepository(context: container.mainContext).insert(sub)
        return sub
    }

    private func draft(from sub: Subscription, mutate: (inout SubscriptionDraft) -> Void)
        -> SubscriptionDraft
    {
        var d = SubscriptionDraft(
            name: sub.name,
            planName: sub.planName ?? "",
            amountString: "\(sub.amount)",
            currency: sub.currency,
            billingCycle: sub.billingCycle,
            customDays: { if case .customDays(let n) = sub.billingCycle { return n }; return 30 }(),
            startDate: sub.startDate,
            category: sub.category,
            notes: sub.notes ?? "",
            urlString: sub.url?.absoluteString ?? ""
        )
        mutate(&d)
        return d
    }

    // MARK: - PH-001 / PH-002

    func test_create_writesInitialBaseline() throws {
        let sub = try makeSub(amount: 15)
        XCTAssertEqual(sub.priceHistory.count, 1)
        XCTAssertEqual(sub.priceHistory.first?.source, .initial)
        XCTAssertEqual(sub.priceHistory.first?.amount, 15)
    }

    func test_amountEdit_appendsUserEditEntry() async throws {
        let sub = try makeSub(amount: 15.49)
        let edit = draft(from: sub) { $0.amountString = "17.99" }
        _ = await SubscriptionDetailView.applyEdits(
            to: sub, draft: edit, context: container.mainContext
        )

        XCTAssertEqual(sub.priceHistory.count, 2,
                       "edit must append one row on top of the initial baseline")
        let latest = sub.priceHistory.sorted { $0.recordedAt > $1.recordedAt }.first
        XCTAssertEqual(latest?.source, .userEdit)
        XCTAssertEqual(latest?.amount, Decimal(string: "17.99"))
        XCTAssertEqual(sub.amount, Decimal(string: "17.99"))
    }

    // MARK: - PH-003

    func test_currencyEdit_appendsUserEditEntry() async throws {
        let sub = try makeSub(amount: 10, currency: "USD")
        let edit = draft(from: sub) { $0.currency = "CNY" }
        _ = await SubscriptionDetailView.applyEdits(
            to: sub, draft: edit, context: container.mainContext
        )

        XCTAssertEqual(sub.priceHistory.count, 2)
        let latest = sub.priceHistory.sorted { $0.recordedAt > $1.recordedAt }.first
        XCTAssertEqual(latest?.source, .userEdit)
        XCTAssertEqual(latest?.currency, "CNY")
    }

    // MARK: - PH-004 / PH-005

    func test_notesOnlyEdit_doesNotAppendHistory() async throws {
        let sub = try makeSub()
        let edit = draft(from: sub) { $0.notes = "I love this" }
        _ = await SubscriptionDetailView.applyEdits(
            to: sub, draft: edit, context: container.mainContext
        )

        XCTAssertEqual(sub.priceHistory.count, 1,
                       "notes change must not pollute price history")
        XCTAssertEqual(sub.notes, "I love this")
    }

    func test_nameOnlyEdit_doesNotAppendHistory() async throws {
        let sub = try makeSub()
        let edit = draft(from: sub) { $0.name = "Netflix Premium" }
        _ = await SubscriptionDetailView.applyEdits(
            to: sub, draft: edit, context: container.mainContext
        )

        XCTAssertEqual(sub.priceHistory.count, 1)
        XCTAssertEqual(sub.name, "Netflix Premium")
    }

    // MARK: - PH-006

    func test_invalidAmountEdit_doesNotMutateOrAppend() async throws {
        let sub = try makeSub(amount: 10)
        let edit = draft(from: sub) { $0.amountString = "not a number" }
        let err = await SubscriptionDetailView.applyEdits(
            to: sub, draft: edit, context: container.mainContext
        )

        XCTAssertNotNil(err)
        XCTAssertEqual(sub.amount, 10, "validation failure must not mutate amount")
        XCTAssertEqual(sub.priceHistory.count, 1, "no history row on validation failure")
    }

    // MARK: - PH-007

    func test_deleteSubscription_cascadesHistory() async throws {
        let sub = try makeSub()
        let edit = draft(from: sub) { $0.amountString = "20" }
        _ = await SubscriptionDetailView.applyEdits(
            to: sub, draft: edit, context: container.mainContext
        )
        XCTAssertEqual(sub.priceHistory.count, 2)

        try SubscriptionRepository(context: container.mainContext).delete(sub)
        try container.mainContext.save()

        let remaining = try container.mainContext
            .fetch(FetchDescriptor<PriceHistoryEntry>())
        XCTAssertTrue(remaining.isEmpty,
                      "cascade delete must remove the sub's history rows")
    }
}
