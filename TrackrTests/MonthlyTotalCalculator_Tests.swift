import XCTest
@testable import Trackr

final class MonthlyTotalCalculatorTests: XCTestCase {

    private func sub(
        _ amount: Decimal,
        currency: String = "USD",
        cycle: BillingCycle = .monthly,
        active: Bool = true
    ) -> Subscription {
        Subscription(
            name: "X",
            amount: amount,
            currency: currency,
            billingCycle: cycle,
            nextBillingDate: .distantFuture,
            startDate: .distantPast,
            category: .other,
            isActive: active
        )
    }

    func test_empty_returnsZero() {
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [], in: "USD"), 0)
    }

    func test_singleMonthly_returnsAmount() {
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(20)], in: "USD"), 20)
    }

    func test_yearly_dividesByTwelve() {
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(120, cycle: .yearly)], in: "USD"), 10)
    }

    func test_weekly_multipliesBy52over12() {
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(12, cycle: .weekly)], in: "USD"), 52)
    }

    func test_customDays60_isHalfPerMonth() {
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(100, cycle: .customDays(60))], in: "USD"), 50)
    }

    func test_customDays_zeroOrNegative_isIgnored() {
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(100, cycle: .customDays(0))], in: "USD"), 0)
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(100, cycle: .customDays(-7))], in: "USD"), 0)
    }

    func test_differentCurrency_isExcluded() {
        let list = [sub(10, currency: "USD"), sub(99, currency: "CNY")]
        XCTAssertEqual(MonthlyTotalCalculator.total(of: list, in: "USD"), 10)
    }

    func test_inactive_isExcluded() {
        XCTAssertEqual(
            MonthlyTotalCalculator.total(of: [sub(10, active: false)], in: "USD"),
            0
        )
    }

    func test_mixedCycles_areSummed() {
        let list = [
            sub(20),
            sub(120, cycle: .yearly),
            sub(12, cycle: .weekly),
        ]
        XCTAssertEqual(MonthlyTotalCalculator.total(of: list, in: "USD"), 82)
    }
}
