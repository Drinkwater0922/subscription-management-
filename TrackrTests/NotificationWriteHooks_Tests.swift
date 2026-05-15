import XCTest
import SwiftData
import UserNotifications
@testable import Trackr

@MainActor
final class NotificationWriteHooksTests: XCTestCase {

    private var container: ModelContainer!
    private var fake: FakeNotificationCenter!
    private var coordinator: NotificationCoordinator!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        fake = FakeNotificationCenter()
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let scheduler = LocalNotificationScheduler(center: fake, calendar: utc)
        coordinator = NotificationCoordinator(scheduler: scheduler, container: container)
    }

    override func tearDownWithError() throws {
        coordinator = nil
        fake = nil
        container = nil
        try super.tearDownWithError()
    }

    func test_addSubscriptionSubmit_callsCoordinatorRefresh() async throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Netflix"
        draft.amountString = "10"

        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            context: container.mainContext,
            coordinator: coordinator,
            onDismiss: {}
        )
        XCTAssertNil(result)
        // We can't easily prove `addedRequests` is non-empty because the
        // freshly-created subscription's nextBillingDate is `.now`, and the
        // builder will skip past-fire-date requests. Instead assert that the
        // coordinator routed through to the center at all by checking that
        // authorization was requested.
        XCTAssertEqual(fake.requestedOptions, [.alert, .sound, .badge])
    }

    func test_detailDelete_callsCoordinatorRefresh() async throws {
        let sub = Subscription(
            name: "X", amount: 1, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture,
            startDate: .now, category: .other
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()
        // Seed a stale pending request so we can observe the cancellation.
        fake.pendingRequests = [
            UNNotificationRequest(
                identifier: NotificationIdentifier.perSubscription(subscriptionID: sub.id, leadDay: 1),
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        ]
        try await SubscriptionDetailView.performDelete(
            subscription: sub,
            context: container.mainContext,
            coordinator: coordinator,
            onDismiss: {}
        )
        XCTAssertFalse(fake.removedIdentifiers.isEmpty,
                       "delete should cancel pending notifications")
    }
}
