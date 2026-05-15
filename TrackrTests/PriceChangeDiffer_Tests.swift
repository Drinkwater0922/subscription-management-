import XCTest
@testable import Trackr

@MainActor
final class PriceChangeDifferTests: XCTestCase {

    private func item(id: String, amount: String, plan: String = "Standard") -> PresetItem {
        let json = #"""
        {
          "id": "\#(id)",
          "name": "\#(id)",
          "defaultPlanName": "\#(plan)",
          "defaultAmount": "\#(amount)",
          "defaultCurrency": "USD",
          "defaultCycle": "monthly",
          "category": "media",
          "iconRef": "preset:\#(id)"
        }
        """#
        return try! JSONDecoder().decode(PresetItem.self, from: Data(json.utf8))
    }

    private func sub(presetId: String?) -> Subscription {
        Subscription(
            name: presetId ?? "X",
            amount: 0,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture,
            startDate: .now,
            category: .media,
            presetId: presetId
        )
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func test_noChange_returnsEmpty() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "10")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result.count, 0)
    }

    func test_amountChange_emitsOneAlertPerSubscription() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "12")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a"),
                                                            sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.oldAmount, 10)
        XCTAssertEqual(result.first?.newAmount, 12)
        XCTAssertEqual(result.first?.presetId, "a")
    }

    func test_newPresetAdded_noAlert() {
        let old = PresetCatalog(version: "1", items: [])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "10")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result.count, 0)
    }

    func test_presetRemoved_noAlert() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result.count, 0)
    }

    func test_subscriptionWithoutPresetId_isIgnored() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "12")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: nil)],
                                            now: now)
        XCTAssertEqual(result.count, 0)
    }

    func test_alertCarriesEnglishAndChineseMessages() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "12")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].messageEn.contains("10"),
                      "en message: \(result[0].messageEn)")
        XCTAssertTrue(result[0].messageEn.contains("12"),
                      "en message: \(result[0].messageEn)")
        XCTAssertFalse(result[0].messageZh.isEmpty)
    }
}
