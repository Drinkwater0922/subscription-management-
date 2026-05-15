import XCTest
@testable import Trackr

final class BillingCycleTests: XCTestCase {

    func test_monthly_roundTripsThroughCodable() throws {
        let original: BillingCycle = .monthly
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BillingCycle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_yearly_roundTripsThroughCodable() throws {
        let original: BillingCycle = .yearly
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BillingCycle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_weekly_roundTripsThroughCodable() throws {
        let original: BillingCycle = .weekly
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BillingCycle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_customDays_roundTripsThroughCodable() throws {
        let original: BillingCycle = .customDays(45)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BillingCycle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_customDays_associatedValueIsPreserved() {
        let cycle: BillingCycle = .customDays(15)
        if case .customDays(let days) = cycle {
            XCTAssertEqual(days, 15)
        } else {
            XCTFail("expected .customDays")
        }
    }

    /// Pin the literal JSON shape of `customDays(45)`. The synthesised label `_0`
    /// is an internal Swift detail, not an ABI guarantee — if a future Swift
    /// version changes the synthesis strategy, this test fails loudly and we know
    /// a persistence migration is needed.
    func test_customDays_encodesToExpectedJSON() throws {
        let data = try JSONEncoder().encode(BillingCycle.customDays(45))
        let json = String(data: data, encoding: .utf8)!
        XCTAssertEqual(json, #"{"customDays":{"_0":45}}"#)
    }

    func test_customDays_inequalityForDifferentDays() {
        XCTAssertNotEqual(BillingCycle.customDays(15), BillingCycle.customDays(30))
    }
}
