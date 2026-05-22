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
        XCTAssertEqual(catalog.version, "2.3.0",
                       "v1.0.1 removed the ChatGPT presets for China-market compliance")
    }

    func test_loadBundledCatalog_includesChinesePresets() throws {
        let catalog = try PresetBundleLoader.loadBundled()
        let ids = Set(catalog.items.map(\.id))
        XCTAssertTrue(ids.contains("iqiyi.vip"))
        XCTAssertTrue(ids.contains("tencent.video.vip"))
        XCTAssertTrue(ids.contains("bilibili.premium"))
        XCTAssertTrue(ids.contains("netease.music"))
        XCTAssertTrue(ids.contains("apple.developer"))
    }

    func test_loadBundledCatalog_leadsWithAI() throws {
        let catalog = try PresetBundleLoader.loadBundled()
        let aiItems = catalog.items.filter { $0.category == .ai }
        XCTAssertGreaterThanOrEqual(aiItems.count, 10,
                                    "M10 seeds AI as the headline category")
        XCTAssertTrue(aiItems.contains { $0.id == "claude.pro" })
        XCTAssertTrue(aiItems.contains { $0.id == "gemini.advanced" })
        XCTAssertTrue(aiItems.contains { $0.id == "grok.supergrok" })
    }
}
