import XCTest
import UserNotifications
@testable import Trackr

final class SameDayAggregatorTests: XCTestCase {

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func req(id: String, fire: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "x"
        content.body = "y"
        let comps = Self.utc.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    func test_singleRequest_passesThrough() {
        let r = req(id: "trackr.sub.A.lead.3",
                    fire: Date(timeIntervalSince1970: 1_700_000_000))
        let out = SameDayAggregator.aggregate([r], leadDay: 3, calendar: Self.utc)
        XCTAssertEqual(out.map(\.identifier), ["trackr.sub.A.lead.3"])
    }

    func test_twoRequestsSameDayAndHour_collapseIntoAggregate() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let a = req(id: "trackr.sub.A.lead.1", fire: day)
        let b = req(id: "trackr.sub.B.lead.1", fire: day)
        let out = SameDayAggregator.aggregate([a, b], leadDay: 1, calendar: Self.utc)
        XCTAssertEqual(out.count, 1)
        let agg = out[0]
        XCTAssertTrue(agg.identifier.hasPrefix("trackr.aggregate."))
        XCTAssertTrue(agg.content.body.contains("2"),
                      "expected count in body: \(agg.content.body)")
    }

    func test_twoRequestsDifferentDays_remainSeparate() {
        let dayA = Date(timeIntervalSince1970: 1_700_000_000)
        let dayB = Date(timeIntervalSince1970: 1_700_000_000 + 86_400 * 2)
        let a = req(id: "trackr.sub.A.lead.3", fire: dayA)
        let b = req(id: "trackr.sub.B.lead.3", fire: dayB)
        let out = SameDayAggregator.aggregate([a, b], leadDay: 3, calendar: Self.utc)
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(Set(out.map(\.identifier)),
                       ["trackr.sub.A.lead.3", "trackr.sub.B.lead.3"])
    }

    func test_aggregateTitleAndBody() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let reqs = [req(id: "trackr.sub.A.lead.7", fire: day),
                    req(id: "trackr.sub.B.lead.7", fire: day),
                    req(id: "trackr.sub.C.lead.7", fire: day)]
        let out = SameDayAggregator.aggregate(reqs, leadDay: 7, calendar: Self.utc)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].content.title, "3 subscriptions renew soon")
        XCTAssertTrue(out[0].content.body.contains("in 7 days"),
                      "body: \(out[0].content.body)")
    }
}
