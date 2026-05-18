import XCTest
@testable import Trackr

final class FeatureGateTests: XCTestCase {

    func test_unlimitedSubs_requiresPro() {
        XCTAssertFalse(FeatureGate.isAllowed(.unlimitedSubs, given: .free))
        XCTAssertTrue(FeatureGate.isAllowed(.unlimitedSubs, given: .proLifetime))
    }

    func test_pricePush_requiresPro() {
        XCTAssertFalse(FeatureGate.isAllowed(.pricePushNotifications, given: .free))
        XCTAssertTrue(FeatureGate.isAllowed(.pricePushNotifications, given: .proLifetime))
    }

    func test_insights_requiresPro() {
        XCTAssertFalse(FeatureGate.isAllowed(.insights, given: .free))
        XCTAssertTrue(FeatureGate.isAllowed(.insights, given: .proLifetime))
    }

    func test_canAddSubscription_freeUnder5_allowed() {
        XCTAssertTrue(FeatureGate.canAddSubscription(currentCount: 0, proStatus: .free))
        XCTAssertTrue(FeatureGate.canAddSubscription(currentCount: 4, proStatus: .free))
    }

    func test_canAddSubscription_freeAt5_blocked() {
        XCTAssertFalse(FeatureGate.canAddSubscription(currentCount: 5, proStatus: .free))
        XCTAssertFalse(FeatureGate.canAddSubscription(currentCount: 99, proStatus: .free))
    }

    func test_canAddSubscription_proAlwaysAllowed() {
        XCTAssertTrue(FeatureGate.canAddSubscription(currentCount: 100, proStatus: .proLifetime))
    }
}
