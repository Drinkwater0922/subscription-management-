import XCTest
@testable import Trackr

final class PresetBundleLoaderTests: XCTestCase {

    func test_loadBundledCatalog_succeedsAndHasItems() throws {
        let catalog = try PresetBundleLoader.loadBundled()
        XCTAssertFalse(catalog.version.isEmpty)
        XCTAssertGreaterThanOrEqual(catalog.items.count, 30,
                                    "M10 expanded the seed catalog to 40+ items")
    }

    func test_loadBundledCatalog_versionMatchesSeed() throws {
        let catalog = try PresetBundleLoader.loadBundled()
        XCTAssertEqual(catalog.version, "2.0.0",
                       "seed catalog version pinned at M10 (preset expansion); bump deliberately")
    }

    func test_loadBundledCatalog_leadsWithAI() throws {
        let catalog = try PresetBundleLoader.loadBundled()
        let aiItems = catalog.items.filter { $0.category == .ai }
        XCTAssertGreaterThanOrEqual(aiItems.count, 10,
                                    "M10 seeds AI as the headline category")
        XCTAssertTrue(aiItems.contains { $0.id == "chatgpt.plus" })
        XCTAssertTrue(aiItems.contains { $0.id == "claude.pro" })
        XCTAssertTrue(aiItems.contains { $0.id == "gemini.advanced" })
        XCTAssertTrue(aiItems.contains { $0.id == "grok.supergrok" })
    }
}
