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

    // MARK: - v1.1: FXRateTable-driven cross-currency conversion

    private func makeTable(base: String = "USD",
                           rates: [String: Decimal]) -> FXRateTable {
        let data = try! JSONEncoder().encode(rates)
        return FXRateTable(baseCurrency: base, ratesJSON: data)
    }

    func test_foreignCurrency_isConverted_viaRateTable() {
        let table = makeTable(rates: ["CNY": 8.0])
        // 80 CNY/month with USD-base table where 1 USD = 8 CNY → 10 USD
        let list = [sub(80, currency: "CNY")]
        XCTAssertEqual(
            MonthlyTotalCalculator.total(of: list, in: "USD", rateTable: table),
            10
        )
    }

    func test_displayCurrencySwitch_includesEveryActiveSub() {
        // Reproduces the v1.1 spec bug: switching display currency from USD
        // to CNY used to silently drop USD subs because no rate was pinned.
        // With the new table-driven model, both subs contribute.
        let table = makeTable(rates: ["CNY": 8.0])
        let list = [
            sub(10, currency: "USD"),   // 10 USD = 80 CNY
            sub(80, currency: "CNY"),   // 80 CNY = 80 CNY
        ]
        XCTAssertEqual(
            MonthlyTotalCalculator.total(of: list, in: "CNY", rateTable: table),
            160
        )
    }

    func test_foreignCurrency_withoutTable_isSkipped() {
        // No table supplied → behaves the same as legacy code: skip
        // foreign-currency subs rather than invent a rate.
        let list = [sub(10, currency: "USD"), sub(99, currency: "CNY")]
        XCTAssertEqual(
            MonthlyTotalCalculator.total(of: list, in: "USD"),
            10
        )
    }

    func test_foreignCurrency_missingFromTable_isSkipped() {
        // Table exists but lacks the sub's currency — skip that sub.
        let table = makeTable(rates: ["EUR": 0.9])
        let list = [sub(10, currency: "USD"), sub(99, currency: "CNY")]
        XCTAssertEqual(
            MonthlyTotalCalculator.total(of: list, in: "USD", rateTable: table),
            10
        )
    }

    func test_pinnedRateFields_areIgnored_inV11Mode() {
        // Legacy TestFlight rows kept their `exchangeRateToHome` /
        // `homeCurrencyAtCreation` fields after migration. The new
        // calculator must NOT consult those fields; conversion is only via
        // the supplied rate table. With no table, the legacy CNY sub is
        // skipped even though it carries a pinned rate.
        let legacy = sub(10, currency: "CNY")
        legacy.exchangeRateToHome = Decimal(string: "0.15")!
        legacy.homeCurrencyAtCreation = "USD"
        XCTAssertEqual(
            MonthlyTotalCalculator.total(of: [legacy], in: "USD"),
            0,
            "pinned-rate fields must not contribute when no rate table is supplied"
        )
    }

    // MARK: - AnnualSpendCalculator

    func test_annualSpend_isTwelveTimesMonthly() {
        let list = [sub(20), sub(120, cycle: .yearly)]
        XCTAssertEqual(AnnualSpendCalculator.total(of: list, in: "USD"),
                       (20 + 10) * 12)
    }

    func test_annualSpend_withTable_convertsForeign() {
        let table = makeTable(rates: ["CNY": 8.0])
        let list = [sub(8, currency: "CNY")]
        // 8 CNY/month = 1 USD/month → 12 USD/year
        XCTAssertEqual(
            AnnualSpendCalculator.total(of: list, in: "USD", rateTable: table),
            12
        )
    }
}
