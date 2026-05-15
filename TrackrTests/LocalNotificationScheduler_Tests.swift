import XCTest
import UserNotifications
@testable import Trackr

@MainActor
final class LocalNotificationSchedulerTests: XCTestCase {

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func sub(name: String, billingDaysFromNow: Int, currency: String = "USD") -> Subscription {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let billing = Self.utc.date(byAdding: .day, value: billingDaysFromNow, to: now)!
        return Subscription(
            name: name, amount: 10, currency: currency,
            billingCycle: .monthly,
            nextBillingDate: billing,
            startDate: Date(timeIntervalSince1970: 0),
            category: .other
        )
    }

    func test_refresh_addsRequestsForEachActiveSubAndLeadDay() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)
        let settings = UserSettings(leadDays: [3, 1], notifyHour: 9)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        try await scheduler.refresh(
            subscriptions: [sub(name: "Netflix", billingDaysFromNow: 10)],
            settings: settings,
            now: now
        )

        XCTAssertEqual(fake.addedRequests.count, 2)
        let ids = Set(fake.addedRequests.map(\.identifier))
        XCTAssertTrue(ids.contains(where: { $0.hasSuffix(".lead.3") }))
        XCTAssertTrue(ids.contains(where: { $0.hasSuffix(".lead.1") }))
    }

    func test_refresh_cancelsTrackrPendingFirst() async throws {
        let fake = FakeNotificationCenter()
        fake.pendingRequests = [
            UNNotificationRequest(identifier: "trackr.sub.OLD.lead.1",
                                  content: UNMutableNotificationContent(),
                                  trigger: nil),
            UNNotificationRequest(identifier: "widget.refresh",
                                  content: UNMutableNotificationContent(),
                                  trigger: nil),
        ]
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)

        try await scheduler.refresh(
            subscriptions: [],
            settings: UserSettings(),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(fake.removedIdentifiers, ["trackr.sub.OLD.lead.1"],
                       "should only remove our own identifiers")
    }

    func test_refresh_skipsInactiveSubscriptions() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)
        let paused = sub(name: "Paused", billingDaysFromNow: 10)
        paused.isActive = false

        try await scheduler.refresh(
            subscriptions: [paused],
            settings: UserSettings(leadDays: [1], notifyHour: 9),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(fake.addedRequests.count, 0)
    }

    func test_refresh_aggregatesSameDayAcrossSubs() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)

        try await scheduler.refresh(
            subscriptions: [
                sub(name: "A", billingDaysFromNow: 5),
                sub(name: "B", billingDaysFromNow: 5),
                sub(name: "C", billingDaysFromNow: 5),
            ],
            settings: UserSettings(leadDays: [1], notifyHour: 9),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(fake.addedRequests.count, 1)
        XCTAssertTrue(fake.addedRequests[0].identifier.hasPrefix("trackr.aggregate."))
    }

    func test_refresh_requestsAuthorizationIfNotYet() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)

        try await scheduler.refresh(
            subscriptions: [],
            settings: UserSettings(),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(fake.requestedOptions, [.alert, .sound, .badge])
    }
}
