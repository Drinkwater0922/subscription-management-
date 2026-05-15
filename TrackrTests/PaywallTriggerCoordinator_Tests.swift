import XCTest
@testable import Trackr

@MainActor
final class PaywallTriggerCoordinatorTests: XCTestCase {

    func test_initialState_notShowing() {
        let coordinator = PaywallTriggerCoordinator()
        XCTAssertFalse(coordinator.isShowing)
        XCTAssertNil(coordinator.reason)
    }

    func test_present_setsFlagAndReason() {
        let coordinator = PaywallTriggerCoordinator()
        coordinator.present(reason: .subscriptionLimit)
        XCTAssertTrue(coordinator.isShowing)
        XCTAssertEqual(coordinator.reason, .subscriptionLimit)
    }

    func test_dismiss_clearsState() {
        let coordinator = PaywallTriggerCoordinator()
        coordinator.present(reason: .insightsLocked)
        coordinator.dismiss()
        XCTAssertFalse(coordinator.isShowing)
        XCTAssertNil(coordinator.reason)
    }
}
