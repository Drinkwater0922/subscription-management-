import XCTest
import UserNotifications
@testable import Trackr

@MainActor
final class PriceChangePushPublisherTests: XCTestCase {

    private func alert(presetId: String = "a") -> PriceChangeAlert {
        PriceChangeAlert(
            presetId: presetId, planKey: "Standard",
            oldAmount: 10, newAmount: 12,
            currency: "USD",
            effectiveDate: .now,
            messageEn: "Service A raised its Standard price from $10.00 to $12.00.",
            messageZh: "Service A Standard 价格已上调，由 $10.00 变为 $12.00。",
            seenAt: nil
        )
    }

    func test_pro_schedulesOneNotificationPerAlert() async throws {
        let fake = FakeNotificationCenter()
        let pub = PriceChangePushPublisher(center: fake)
        try await pub.publish(alerts: [alert(presetId: "a"), alert(presetId: "b")],
                              proStatus: .proLifetime)
        XCTAssertEqual(fake.addedRequests.count, 2)
        XCTAssertTrue(fake.addedRequests[0].content.body.contains("Service A"))
    }

    func test_free_schedulesNothing() async throws {
        let fake = FakeNotificationCenter()
        let pub = PriceChangePushPublisher(center: fake)
        try await pub.publish(alerts: [alert()], proStatus: .free)
        XCTAssertEqual(fake.addedRequests.count, 0)
    }

}
