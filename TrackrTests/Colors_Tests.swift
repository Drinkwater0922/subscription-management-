import XCTest
import SwiftUI
@testable import Trackr

final class ColorsTests: XCTestCase {
    func test_bg_isPureBlack() {
        let (r, g, b, a) = TrackrColors.bg.rgba
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
        XCTAssertEqual(b, 0.0, accuracy: 0.01)
        XCTAssertEqual(a, 1.0, accuracy: 0.01)
    }

    func test_accent_isLimeGreen() {
        let (r, g, b, _) = TrackrColors.accent.rgba
        // #C7F284 -> (199, 242, 132) / 255
        XCTAssertEqual(r, 199.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(g, 242.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(b, 132.0 / 255.0, accuracy: 0.01)
    }

    func test_warn_isDimRed() {
        let (r, g, b, _) = TrackrColors.warn.rgba
        // #A8453D
        XCTAssertEqual(r, 168.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(g, 69.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(b, 61.0 / 255.0, accuracy: 0.01)
    }
}

// Test helper: read back rgba from a SwiftUI Color.
extension Color {
    var rgba: (CGFloat, CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}
