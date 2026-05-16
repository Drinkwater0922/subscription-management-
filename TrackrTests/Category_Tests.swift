import XCTest
@testable import Trackr

final class CategoryTests: XCTestCase {

    func test_allCategoriesHaveDistinctDisplayNames() {
        let names = Category.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count, "displayName collision: \(names)")
    }

    func test_displayName_isStableEnglish() {
        XCTAssertEqual(Category.ai.displayName, "AI")
        XCTAssertEqual(Category.streaming.displayName, "Streaming")
        XCTAssertEqual(Category.music.displayName, "Music")
        XCTAssertEqual(Category.games.displayName, "Games")
        XCTAssertEqual(Category.cloud.displayName, "Cloud")
        XCTAssertEqual(Category.productivity.displayName, "Productivity")
        XCTAssertEqual(Category.dev.displayName, "Developer")
        XCTAssertEqual(Category.news.displayName, "News")
        XCTAssertEqual(Category.fitness.displayName, "Fitness")
        XCTAssertEqual(Category.learning.displayName, "Learning")
        XCTAssertEqual(Category.shopping.displayName, "Shopping")
        XCTAssertEqual(Category.other.displayName, "Other")
    }

    func test_aiIsFirstCase() {
        XCTAssertEqual(Category.allCases.first, .ai,
                       "AI must lead — PresetLibraryView relies on declaration order.")
    }
}
