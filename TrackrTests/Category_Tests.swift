import XCTest
@testable import Trackr

final class CategoryTests: XCTestCase {

    func test_allCategoriesHaveDistinctDisplayNames() {
        let names = Category.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count, "displayName collision: \(names)")
    }

    func test_displayName_isStableEnglish() {
        XCTAssertEqual(Category.ai.displayName, "AI")
        XCTAssertEqual(Category.dev.displayName, "Developer")
        XCTAssertEqual(Category.media.displayName, "Media")
        XCTAssertEqual(Category.cloud.displayName, "Cloud")
        XCTAssertEqual(Category.productivity.displayName, "Productivity")
        XCTAssertEqual(Category.other.displayName, "Other")
    }
}
