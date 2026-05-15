import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionDetailViewDeleteTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_performDelete_removesRowAndDismisses() throws {
        let sub = Subscription(
            name: "GoneSoon", amount: 1, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now, category: .other
        )
        let ctx = container.mainContext
        ctx.insert(sub)
        try ctx.save()

        var dismissed = false
        try SubscriptionDetailView.performDelete(subscription: sub,
                                                 context: ctx,
                                                 onDismiss: { dismissed = true })

        XCTAssertTrue(dismissed)
        let count = try SubscriptionRepository(context: ctx).count()
        XCTAssertEqual(count, 0)
    }
}
