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
}
