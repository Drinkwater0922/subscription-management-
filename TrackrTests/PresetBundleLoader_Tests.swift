import XCTest
@testable import Trackr

final class PresetBundleLoaderTests: XCTestCase {

    func test_loadBundledCatalog_succeedsAndHasItems() throws {
        let catalog = try PresetBundleLoader.loadBundled()
        XCTAssertFalse(catalog.version.isEmpty)
        XCTAssertGreaterThanOrEqual(catalog.items.count, 5,
                                    "bundled catalog should ship at least the M5 seed list")
    }

    func test_loadBundledCatalog_versionMatchesSeed() throws {
        let catalog = try PresetBundleLoader.loadBundled()
        XCTAssertEqual(catalog.version, "1.0.0",
                       "seed catalog version is pinned in M5; bump deliberately")
    }
}
