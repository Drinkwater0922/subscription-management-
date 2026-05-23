import XCTest
@testable import Trackr

final class SpendAnchorTests: XCTestCase {

    // MARK: - Catalog sanity

    func test_catalog_hasReasonableCount() {
        XCTAssertGreaterThanOrEqual(SpendAnchorCatalog.all.count, 8)
        XCTAssertLessThanOrEqual(SpendAnchorCatalog.all.count, 12)
    }

    func test_catalog_idsAreUnique() {
        let ids = SpendAnchorCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func test_catalog_pricesAreSanePositive() {
        for anchor in SpendAnchorCatalog.all {
            XCTAssertGreaterThan(anchor.priceUSD, 0, "\(anchor.id) priced \(anchor.priceUSD)")
        }
    }

    func test_catalog_forbidsGuiltLabels() {
        // The design doc is explicit: "≈ X months of groceries" is guilt
        // and is forbidden. Catch any anchor whose label leans that way.
        let banned = ["grocer", "rent", "mortgage", "month of "]
        for anchor in SpendAnchorCatalog.all {
            let blob = [anchor.labelEnSingular, anchor.labelEnPlural, anchor.labelZh]
                .joined(separator: " ")
                .lowercased()
            for term in banned {
                XCTAssertFalse(blob.contains(term),
                               "\(anchor.id) contains forbidden term '\(term)'")
            }
        }
    }

    // MARK: - Selection

    func test_pick_zeroSpend_returnsEmpty() {
        XCTAssertTrue(SpendAnchorCatalog.pick(annualSpendUSD: 0).isEmpty)
    }

    func test_pick_lowSpend_picksCoffee() {
        let picks = SpendAnchorCatalog.pick(annualSpendUSD: 6, limit: 1)
        XCTAssertEqual(picks.first?.id, "coffee",
                       "annual spend $6 should match the coffee anchor closest")
    }

    func test_pick_aroundPS5_picksPS5() {
        let picks = SpendAnchorCatalog.pick(annualSpendUSD: 437, limit: 1)
        XCTAssertEqual(picks.first?.id, "ps5",
                       "$437 ≈ one PS5 (the canonical design-doc example)")
    }

    func test_pick_highSpend_picksLargeAnchor() {
        let picks = SpendAnchorCatalog.pick(annualSpendUSD: 2500, limit: 1)
        XCTAssertEqual(picks.first?.id, "vacation",
                       "$2500 should match the vacation anchor closest")
    }

    func test_pick_limitsResults() {
        let picks = SpendAnchorCatalog.pick(annualSpendUSD: 500, limit: 3)
        XCTAssertEqual(picks.count, 3)
    }

    func test_pick_noDuplicates_acrossRotation() {
        let picks = SpendAnchorCatalog.pick(annualSpendUSD: 500, limit: 4)
        XCTAssertEqual(picks.count, Set(picks.map(\.id)).count,
                       "rotation must not produce duplicates")
    }

    // MARK: - Renderer

    func test_render_aroundOne_usesArticle_en() {
        let ps5 = SpendAnchorCatalog.all.first { $0.id == "ps5" }!
        let s = SpendAnchorRenderer.render(annualSpendUSD: 499, anchor: ps5,
                                            locale: Locale(identifier: "en"))
        XCTAssertEqual(s, "≈ one PlayStation 5")
    }

    func test_render_aroundOne_usesArticle_zh() {
        let ps5 = SpendAnchorCatalog.all.first { $0.id == "ps5" }!
        let s = SpendAnchorRenderer.render(annualSpendUSD: 499, anchor: ps5,
                                            locale: Locale(identifier: "zh-Hans"))
        XCTAssertEqual(s, "≈ 一台 PS5")
    }

    func test_render_doubled_usesPlural_en() {
        let ps5 = SpendAnchorCatalog.all.first { $0.id == "ps5" }!
        let s = SpendAnchorRenderer.render(annualSpendUSD: 998, anchor: ps5,
                                            locale: Locale(identifier: "en"))
        XCTAssertEqual(s, "≈ 2 PlayStation 5s")
    }

    func test_render_doubled_usesCount_zh() {
        let ps5 = SpendAnchorCatalog.all.first { $0.id == "ps5" }!
        let s = SpendAnchorRenderer.render(annualSpendUSD: 998, anchor: ps5,
                                            locale: Locale(identifier: "zh-Hans"))
        XCTAssertEqual(s, "≈ 2 台 PS5")
    }

    func test_render_half_en() {
        let ps5 = SpendAnchorCatalog.all.first { $0.id == "ps5" }!
        let s = SpendAnchorRenderer.render(annualSpendUSD: 200, anchor: ps5,
                                            locale: Locale(identifier: "en"))
        XCTAssertEqual(s, "≈ half a PlayStation 5")
    }

    func test_render_half_zh() {
        let ps5 = SpendAnchorCatalog.all.first { $0.id == "ps5" }!
        let s = SpendAnchorRenderer.render(annualSpendUSD: 200, anchor: ps5,
                                            locale: Locale(identifier: "zh-Hans"))
        XCTAssertEqual(s, "≈ 半台 PS5")
    }
}
