import XCTest
@testable import Trackr

@MainActor
final class UpcomingRenewalsProviderTests: XCTestCase {

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func sub(name: String,
                     daysFromNow: Int,
                     active: Bool = true,
                     amount: Decimal = 10,
                     currency: String = "USD") -> Subscription {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let billing = Self.utc.date(byAdding: .day, value: daysFromNow, to: now)!
        return Subscription(
            name: name,
            amount: amount, currency: currency,
            billingCycle: .monthly,
            nextBillingDate: billing,
            startDate: Date(timeIntervalSince1970: 0),
            category: .other,
            isActive: active
        )
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func test_sortsByNextBillingAscending() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "B", daysFromNow: 10),
                            sub(name: "A", daysFromNow: 3)],
            now: now,
            limit: 5,
            calendar: Self.utc
        )
        XCTAssertEqual(result.map(\.name), ["A", "B"])
    }

    func test_skipsInactiveSubscriptions() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "Paused", daysFromNow: 1, active: false),
                            sub(name: "Live", daysFromNow: 5)],
            now: now,
            limit: 5,
            calendar: Self.utc
        )
        XCTAssertEqual(result.map(\.name), ["Live"])
    }

    func test_skipsRenewalsInThePast() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "Old", daysFromNow: -3),
                            sub(name: "Future", daysFromNow: 7)],
            now: now,
            limit: 5,
            calendar: Self.utc
        )
        XCTAssertEqual(result.map(\.name), ["Future"])
    }

    func test_respectsLimit() {
        let subs = (1...10).map { sub(name: "S\($0)", daysFromNow: $0) }
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: subs,
            now: now,
            limit: 3,
            calendar: Self.utc
        )
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.name), ["S1", "S2", "S3"])
    }

    func test_daysUntil_computedCorrectly() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "X", daysFromNow: 5)],
            now: now,
            limit: 1,
            calendar: Self.utc
        )
        XCTAssertEqual(result.first?.daysUntil, 5)
    }

    func test_displayAmount_isFormatted() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "Netflix", daysFromNow: 3,
                                amount: 15.49, currency: "USD")],
            now: now,
            limit: 1,
            calendar: Self.utc
        )
        XCTAssertEqual(result.first?.displayAmount, "$15.49")
    }
}
