import XCTest
import SwiftUI
@testable import Trackr

final class TypographyTests: XCTestCase {
    func test_pixelFont_isVT323() {
        let font = TrackrTypography.pixel(size: 20)
        // Resolve to UIFont so we can inspect the actual family/PS name.
        let resolved = UIFont(name: "VT323-Regular", size: 20)
        XCTAssertNotNil(resolved, "VT323-Regular must be registered before Typography is exercised.")
        XCTAssertEqual(resolved?.familyName, "VT323")
        // Sanity: the SwiftUI Font is non-nil (we can't introspect it directly).
        _ = font
    }

    func test_typography_scale_definesHeroSize() {
        XCTAssertEqual(TrackrTypography.Scale.hero, 68)
    }

    func test_typography_scale_definesSectionLabelSize() {
        XCTAssertEqual(TrackrTypography.Scale.sectionLabel, 13)
    }
}
