import XCTest
import UserNotifications
@testable import Trackr

final class NotificationRequestBuilderTests: XCTestCase {

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func sub(name: String = "Netflix",
                     amount: Decimal = 15.49,
                     currency: String = "USD",
                     nextBilling: Date) -> Subscription {
        Subscription(
            name: name,
            amount: amount,
            currency: currency,
            billingCycle: .monthly,
            nextBillingDate: nextBilling,
            startDate: Date(timeIntervalSince1970: 0),
            category: .streaming
        )
    }

    func test_buildsRequestWithExpectedIdentifierAndUserInfo() throws {
        let sub = sub(nextBilling: Date(timeIntervalSince1970: 1_700_000_000))
        let request = try XCTUnwrap(
            NotificationRequestBuilder.build(
                subscription: sub,
                leadDay: 3,
                notifyHour: 9,
                calendar: Self.utc,
                now: Date(timeIntervalSince1970: 0)
            )
        )
        XCTAssertEqual(
            request.identifier,
            "trackr.sub.\(sub.id.uuidString.lowercased()).lead.3"
        )
        XCTAssertEqual(request.content.userInfo["subscriptionID"] as? String,
                       sub.id.uuidString)
    }

    func test_bodyMentionsAmountAndDaysWord() throws {
        let billing = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13 UTC
        let request = try XCTUnwrap(
            NotificationRequestBuilder.build(
                subscription: sub(name: "Netflix", amount: 15.49, nextBilling: billing),
                leadDay: 3,
                notifyHour: 9,
                calendar: Self.utc,
                now: Date(timeIntervalSince1970: 0)
            )
        )
        XCTAssertEqual(request.content.title, "Netflix renews soon")
        XCTAssertTrue(request.content.body.contains("3 days"),
                      "body: \(request.content.body)")
        XCTAssertTrue(request.content.body.contains("$15.49"),
                      "body: \(request.content.body)")
    }

    func test_leadDay1_usesTomorrowCopy() throws {
        let billing = Date(timeIntervalSince1970: 1_700_000_000)
        let request = try XCTUnwrap(
            NotificationRequestBuilder.build(
                subscription: sub(nextBilling: billing),
                leadDay: 1,
                notifyHour: 9,
                calendar: Self.utc,
                now: Date(timeIntervalSince1970: 0)
            )
        )
        XCTAssertTrue(request.content.body.contains("tomorrow"),
                      "body: \(request.content.body)")
    }

    func test_fireDate_isLeadDaysBeforeBillingAtNotifyHourUTC() throws {
        let billing = Date(timeIntervalSince1970: 1_700_000_000)
        let request = try XCTUnwrap(
            NotificationRequestBuilder.build(
                subscription: sub(nextBilling: billing),
                leadDay: 3,
                notifyHour: 9,
                calendar: Self.utc,
                now: Date(timeIntervalSince1970: 0)
            )
        )
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        var comps = trigger.dateComponents
        comps.calendar = Self.utc
        comps.timeZone = TimeZone(identifier: "UTC")
        let fire = try XCTUnwrap(comps.date)
        let expected = ISO8601DateFormatter().date(from: "2023-11-11T09:00:00Z")!
        XCTAssertEqual(fire, expected)
    }

    func test_fireDateInPast_returnsNil() {
        let billing = Date(timeIntervalSince1970: 1_700_000_000)
        let request = NotificationRequestBuilder.build(
            subscription: sub(nextBilling: billing),
            leadDay: 5_000,
            notifyHour: 9,
            calendar: Self.utc,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertNil(request)
    }

    func test_inactiveSubscription_returnsNil() {
        let s = sub(nextBilling: .distantFuture)
        s.isActive = false
        XCTAssertNil(NotificationRequestBuilder.build(
            subscription: s,
            leadDay: 3,
            notifyHour: 9,
            calendar: Self.utc
        ))
    }
}
