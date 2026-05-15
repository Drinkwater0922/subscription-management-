import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class AddSubscriptionSheetFreeTierLimitTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    private func seed(_ n: Int) throws {
        for i in 0..<n {
            let sub = Subscription(
                name: "Sub\(i)", amount: 1, currency: "USD",
                billingCycle: .monthly,
                nextBillingDate: .distantFuture, startDate: .now,
                category: .other
            )
            container.mainContext.insert(sub)
        }
        try container.mainContext.save()
    }

    func test_free_under5_allowsInsert() async throws {
        try seed(4)
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Fifth"
        draft.amountString = "1"

        var limitTripped = false
        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: nil,
            proStatus: .free,
            context: container.mainContext,
            coordinator: nil,
            onLimitExceeded: { limitTripped = true },
            onDismiss: {}
        )
        XCTAssertNil(result)
        XCTAssertFalse(limitTripped)
        XCTAssertEqual(try SubscriptionRepository(context: container.mainContext).count(), 5)
    }

    func test_free_at5_blocksAndCallsLimitHook() async throws {
        try seed(5)
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Sixth"
        draft.amountString = "1"

        var limitTripped = false
        var dismissed = false
        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: nil,
            proStatus: .free,
            context: container.mainContext,
            coordinator: nil,
            onLimitExceeded: { limitTripped = true },
            onDismiss: { dismissed = true }
        )
        XCTAssertNotNil(result, "should return user-facing message")
        XCTAssertTrue(limitTripped)
        XCTAssertFalse(dismissed)
        XCTAssertEqual(try SubscriptionRepository(context: container.mainContext).count(), 5,
                       "no sub was added")
    }

    func test_pro_at5_stillAllowed() async throws {
        try seed(5)
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Sixth"
        draft.amountString = "1"

        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: nil,
            proStatus: .proLifetime,
            context: container.mainContext,
            coordinator: nil,
            onLimitExceeded: {},
            onDismiss: {}
        )
        XCTAssertNil(result)
        XCTAssertEqual(try SubscriptionRepository(context: container.mainContext).count(), 6)
    }
}
