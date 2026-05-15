import XCTest
@testable import Trackr

@MainActor
final class AppDeepLinkRouterTests: XCTestCase {

    func test_initialState_noPendingTarget() {
        let router = AppDeepLinkRouter()
        XCTAssertNil(router.pendingSubscriptionID)
    }

    func test_request_setsPendingID() {
        let router = AppDeepLinkRouter()
        let id = UUID()
        router.requestOpen(subscriptionID: id)
        XCTAssertEqual(router.pendingSubscriptionID, id)
    }

    func test_consume_clearsAndReturnsID() {
        let router = AppDeepLinkRouter()
        let id = UUID()
        router.requestOpen(subscriptionID: id)
        XCTAssertEqual(router.consume(), id)
        XCTAssertNil(router.pendingSubscriptionID)
    }

    func test_consume_whenEmpty_returnsNil() {
        let router = AppDeepLinkRouter()
        XCTAssertNil(router.consume())
    }
}
