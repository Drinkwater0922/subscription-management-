import XCTest
@testable import Trackr

final class NotificationIdentifierTests: XCTestCase {

    func test_perSubscription_includesUUIDAndLeadDay() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        XCTAssertEqual(
            NotificationIdentifier.perSubscription(subscriptionID: id, leadDay: 3),
            "trackr.sub.11111111-2222-3333-4444-555555555555.lead.3"
        )
    }

    func test_aggregate_includesDateAndLeadDay() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 UTC
        XCTAssertEqual(
            NotificationIdentifier.aggregate(fireDay: date, leadDay: 1),
            "trackr.aggregate.2023-11-14.lead.1"
        )
    }

    func test_isTrackrIdentifier_prefixCheck() {
        XCTAssertTrue(NotificationIdentifier.isTrackrIdentifier("trackr.sub.abc.lead.7"))
        XCTAssertTrue(NotificationIdentifier.isTrackrIdentifier("trackr.aggregate.2024-01-01.lead.3"))
        XCTAssertFalse(NotificationIdentifier.isTrackrIdentifier("widget.refresh"))
        XCTAssertFalse(NotificationIdentifier.isTrackrIdentifier(""))
    }
}
