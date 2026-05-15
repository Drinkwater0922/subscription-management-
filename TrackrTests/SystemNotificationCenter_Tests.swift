import XCTest
import UserNotifications
@testable import Trackr

@MainActor
final class SystemNotificationCenterTests: XCTestCase {

    func test_wrapsUNUserNotificationCenterCurrent() {
        let wrapper = SystemNotificationCenter()
        XCTAssertNotNil(wrapper.underlying)
    }
}
