import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionDetailViewPauseTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_togglePause_flipsAndPersists() async throws {
        let sub = Subscription(
            name: "X", amount: 1, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now, category: .other
        )
        let ctx = container.mainContext
        ctx.insert(sub)
        try ctx.save()
        XCTAssertTrue(sub.isActive)

        try await SubscriptionDetailView.togglePause(subscription: sub, context: ctx, coordinator: nil)
        XCTAssertFalse(sub.isActive)
        try await SubscriptionDetailView.togglePause(subscription: sub, context: ctx, coordinator: nil)
        XCTAssertTrue(sub.isActive)

        let refetched = try SubscriptionRepository(context: ctx).fetch(byID: sub.id)
        XCTAssertEqual(refetched?.isActive, true)
    }
}
