import XCTest
@testable import Trackr

final class PresetItemTests: XCTestCase {

    private let json = #"""
    {
      "id": "netflix.standard",
      "name": "Netflix",
      "defaultPlanName": "Standard",
      "defaultAmount": "15.49",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "streaming",
      "iconRef": "preset:netflix.standard"
    }
    """#

    func test_decode_parsesAllFields() throws {
        let item = try JSONDecoder().decode(PresetItem.self,
                                            from: Data(json.utf8))
        XCTAssertEqual(item.id, "netflix.standard")
        XCTAssertEqual(item.name, "Netflix")
        XCTAssertEqual(item.defaultPlanName, "Standard")
        XCTAssertEqual(item.defaultAmount, Decimal(string: "15.49"))
        XCTAssertEqual(item.defaultCurrency, "USD")
        XCTAssertEqual(item.defaultCycle, .monthly)
        XCTAssertEqual(item.category, .streaming)
        XCTAssertEqual(item.iconRef, "preset:netflix.standard")
    }

    func test_decode_yearly_yearlyCycle() throws {
        let yearlyJSON = json.replacingOccurrences(of: "\"monthly\"", with: "\"yearly\"")
        let item = try JSONDecoder().decode(PresetItem.self, from: Data(yearlyJSON.utf8))
        XCTAssertEqual(item.defaultCycle, .yearly)
    }

    func test_decode_weekly_weeklyCycle() throws {
        let weeklyJSON = json.replacingOccurrences(of: "\"monthly\"", with: "\"weekly\"")
        let item = try JSONDecoder().decode(PresetItem.self, from: Data(weeklyJSON.utf8))
        XCTAssertEqual(item.defaultCycle, .weekly)
    }

    func test_toDraft_populatesAllFields() throws {
        let item = try JSONDecoder().decode(PresetItem.self, from: Data(json.utf8))
        let draft = item.toDraft(defaultStart: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(draft.name, "Netflix")
        XCTAssertEqual(draft.planName, "Standard")
        XCTAssertEqual(draft.amountString, "15.49")
        XCTAssertEqual(draft.currency, "USD")
        XCTAssertEqual(draft.billingCycle, .monthly)
        XCTAssertEqual(draft.category, .streaming)
        XCTAssertEqual(draft.startDate, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func test_toDraft_buildsSubscriptionWithPresetId() throws {
        let item = try JSONDecoder().decode(PresetItem.self, from: Data(json.utf8))
        let draft = item.toDraft(defaultStart: .distantPast)
        let sub = try draft.makeSubscription()
        XCTAssertEqual(sub.name, "Netflix")
        XCTAssertEqual(sub.amount, Decimal(string: "15.49"))
    }
}
