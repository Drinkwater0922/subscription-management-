import XCTest
import SwiftUI
@testable import Trackr

final class VT323FontTests: XCTestCase {
    func test_VT323_isRegistered() {
        let names = UIFont.fontNames(forFamilyName: "VT323")
        XCTAssertTrue(
            names.contains("VT323-Regular"),
            "VT323-Regular not registered. UIFont sees: \(names)"
        )
    }
}
