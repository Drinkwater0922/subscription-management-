import XCTest
@testable import Trackr

final class AppleSubscriptionsRouteTests: XCTestCase {

    func test_deepLinkString_isStable() {
        XCTAssertEqual(AppleSubscriptionsRoute.deepLinkString,
                       "itms-apps://apps.apple.com/account/subscriptions")
    }

    func test_deepLinkURL_parses() {
        XCTAssertEqual(AppleSubscriptionsRoute.deepLinkURL.absoluteString,
                       AppleSubscriptionsRoute.deepLinkString)
        XCTAssertEqual(AppleSubscriptionsRoute.deepLinkURL.scheme, "itms-apps")
    }
}
