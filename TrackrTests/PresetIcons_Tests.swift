import XCTest
@testable import Trackr

final class PresetIconsTests: XCTestCase {

    func test_glyph_forKnownPreset_returnsMappedEmoji() throws {
        let items = try PresetBundleLoader.loadBundled().items
        let claude = try XCTUnwrap(items.first { $0.id == "claude.pro" })
        XCTAssertEqual(PresetIcons.glyph(for: claude), "🤖")
    }

    func test_glyph_forUnknownPreset_fallsBackToCategory() {
        // Build a fake preset with a category but an id that's not in the map.
        let item = PresetItem(unmappedId: "totally.new.thing", category: .ai)
        XCTAssertEqual(PresetIcons.glyph(for: item), "🤖",
                       "unmapped AI preset should fall back to the AI category emoji")
    }

    func test_glyph_forSubscription_prefersPresetIdOverCategory() {
        let sub = Subscription(
            name: "Netflix",
            amount: 15.49,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .now,
            startDate: .now,
            category: .streaming,
            presetId: "netflix.standard"
        )
        XCTAssertEqual(PresetIcons.glyph(for: sub), "🎬")
    }

    func test_glyph_forCustomEmojiSubscription() {
        let sub = Subscription(
            name: "Mystery",
            amount: 5,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .now,
            startDate: .now,
            category: .other,
            iconRef: "custom:emoji:🦄"
        )
        XCTAssertEqual(PresetIcons.glyph(for: sub), "🦄")
    }

    func test_glyph_forDefaultQuestionMark_fallsBackToCategory() {
        // The seed `Subscription.iconRef` default is `"custom:emoji:❓"`. That
        // placeholder shouldn't bleed into the UI — we should use the category
        // emoji instead.
        let sub = Subscription(
            name: "Mystery",
            amount: 5,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .now,
            startDate: .now,
            category: .games
        )
        XCTAssertEqual(sub.iconRef, "custom:emoji:❓")
        XCTAssertEqual(PresetIcons.glyph(for: sub), "🎮")
    }

    func test_categoryEmoji_coversEveryCategory() {
        for cat in Category.allCases {
            XCTAssertNotNil(PresetIcons.glyphByCategory[cat],
                            "missing category fallback emoji for \(cat)")
        }
    }
}

// MARK: - Test helpers

private extension PresetItem {
    /// Quick constructor for unmapped-id tests — uses JSON round-trip so we
    /// don't have to expose a memberwise init on the production type.
    init(unmappedId: String, category: Trackr.Category) {
        let json = """
        {
          "id": "\(unmappedId)",
          "name": "Test",
          "defaultPlanName": "Plan",
          "defaultAmount": "1.00",
          "defaultCurrency": "USD",
          "defaultCycle": "monthly",
          "category": "\(category.rawValue)",
          "iconRef": "preset:\(unmappedId)"
        }
        """.data(using: .utf8)!
        self = try! JSONDecoder().decode(PresetItem.self, from: json)
    }
}
