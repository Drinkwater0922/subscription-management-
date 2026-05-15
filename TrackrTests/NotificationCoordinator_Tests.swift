import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class NotificationCoordinatorTests: XCTestCase {

    private var container: ModelContainer!
    private var fake: FakeNotificationCenter!
    private var coordinator: NotificationCoordinator!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: utc)
        coordinator = NotificationCoordinator(scheduler: scheduler, container: container)
    }

    override func tearDownWithError() throws {
        coordinator = nil
        fake = nil
        container = nil
        try super.tearDownWithError()
    }

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func seed(active: Bool, billingDaysAhead: Int) throws {
        let billing = utc.date(byAdding: .day, value: billingDaysAhead, to: Date(timeIntervalSince1970: 1_700_000_000))!
        let sub = Subscription(
            name: "Netflix", amount: 10, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: billing,
            startDate: Date(timeIntervalSince1970: 0),
            category: .other,
            isActive: active
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()
    }

    func test_refresh_addsRequestsForActiveSub() async throws {
        try seed(active: true, billingDaysAhead: 10)
        try await coordinator.refresh(now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertFalse(fake.addedRequests.isEmpty,
                       "expected scheduler to be called via coordinator")
    }

    func test_refresh_skipsInactive() async throws {
        try seed(active: false, billingDaysAhead: 10)
        try await coordinator.refresh(now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(fake.addedRequests.isEmpty)
    }
}
