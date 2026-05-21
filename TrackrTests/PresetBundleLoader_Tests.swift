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
        XCTAssertEqual(catalog.version, "2.2.0",
                       "M10.6 added Plaud / 脉脉 / 讯飞听见 + date extraction fixes")
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
        let blockedTerm = ["chat", "g", "pt"].joined()
        XCTAssertGreaterThanOrEqual(aiItems.count, 8,
                                    "M10 seeds AI subscriptions while excluding China-blocked references")
        XCTAssertFalse(aiItems.contains { $0.id.localizedCaseInsensitiveContains(blockedTerm) })
        XCTAssertFalse(aiItems.contains { $0.name.localizedCaseInsensitiveContains(blockedTerm) })
        XCTAssertTrue(aiItems.contains { $0.id == "claude.pro" })
        XCTAssertTrue(aiItems.contains { $0.id == "gemini.advanced" })
        XCTAssertTrue(aiItems.contains { $0.id == "grok.supergrok" })
    }
}
