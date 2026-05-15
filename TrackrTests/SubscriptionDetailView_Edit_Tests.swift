import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionDetailViewEditTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_applyEdits_updatesFieldsAndSaves() throws {
        let sub = Subscription(
            name: "Old", planName: nil, amount: 5, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now, category: .other
        )
        let ctx = container.mainContext
        ctx.insert(sub)
        try ctx.save()

        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "New Name"
        draft.amountString = "12.50"
        draft.planName = "Pro"
        draft.notes = "moved up a tier"

        let error = SubscriptionDetailView.applyEdits(to: sub, draft: draft, context: ctx)
        XCTAssertNil(error)
        XCTAssertEqual(sub.name, "New Name")
        XCTAssertEqual(sub.amount, Decimal(string: "12.50"))
        XCTAssertEqual(sub.planName, "Pro")
        XCTAssertEqual(sub.notes, "moved up a tier")

        let refetched = try SubscriptionRepository(context: ctx).fetch(byID: sub.id)
        XCTAssertEqual(refetched?.name, "New Name")
    }

    func test_applyEdits_invalidAmount_doesNotMutate() throws {
        let sub = Subscription(
            name: "Keep", amount: 5, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now, category: .other
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()

        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Keep"
        draft.amountString = "not-a-number"

        let error = SubscriptionDetailView.applyEdits(to: sub, draft: draft, context: container.mainContext)
        XCTAssertNotNil(error)
        XCTAssertEqual(sub.amount, 5)
    }
}
