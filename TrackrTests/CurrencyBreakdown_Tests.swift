import XCTest
@testable import Trackr

final class CurrencyBreakdownTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_780_272_000)

    func test_emptySubs_returnsEmpty() {
        let result = CurrencyBreakdown.breakdown([], in: "USD", rateTable: nil, now: now)
        XCTAssertTrue(result.isEmpty)
    }

    func test_singleCurrencyUser_returnsOneRow() {
        let subs = [
            sub(amount: 10, currency: "USD"),
            sub(amount: 5,  currency: "USD"),
        ]
        let result = CurrencyBreakdown.breakdown(subs, in: "USD", rateTable: nil, now: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.currency, "USD")
        XCTAssertEqual(result.first?.monthlyAmount, 15)
    }

    func test_multipleCurrencies_keepsOriginalAmounts() throws {
        let table = makeUSDTable(rates: ["CNY": 8.0])
        let subs = [
            sub(amount: 10, currency: "USD"),
            sub(amount: 80, currency: "CNY"),
        ]
        let result = CurrencyBreakdown.breakdown(subs, in: "USD",
                                                  rateTable: table, now: now)
        XCTAssertEqual(result.count, 2)
        let byCur = Dictionary(uniqueKeysWithValues: result.map { ($0.currency, $0) })
        XCTAssertEqual(byCur["USD"]?.monthlyAmount, 10,
                       "USD row keeps its raw USD total — no FX")
        XCTAssertEqual(byCur["CNY"]?.monthlyAmount, 80,
                       "CNY row keeps its raw CNY total — no FX on main amount")
    }

    func test_annualInDisplayCurrency_isMonthlyTimesTwelveFXConverted() throws {
        let table = makeUSDTable(rates: ["CNY": 8.0])
        let subs = [
            sub(amount: 80, currency: "CNY"),  // 80/mo CNY → 960/yr CNY → 120 USD/yr
        ]
        let result = CurrencyBreakdown.breakdown(subs, in: "USD",
                                                  rateTable: table, now: now)
        XCTAssertEqual(result.first?.annualInDisplayCurrency, 120)
    }

    func test_annualInDisplayCurrency_sameCurrencyJustTwelve() {
        let subs = [sub(amount: 10, currency: "USD")]
        let result = CurrencyBreakdown.breakdown(subs, in: "USD",
                                                  rateTable: nil, now: now)
        XCTAssertEqual(result.first?.annualInDisplayCurrency, 120)
    }

    func test_annualInDisplayCurrency_nilWhenRateMissing() throws {
        let table = makeUSDTable(rates: ["CNY": 8.0])  // EUR missing
        let subs = [sub(amount: 50, currency: "EUR")]
        let result = CurrencyBreakdown.breakdown(subs, in: "USD",
                                                  rateTable: table, now: now)
        XCTAssertNil(result.first?.annualInDisplayCurrency,
                     "missing rate → nil; view will render em-dash")
        XCTAssertEqual(result.first?.monthlyAmount, 50,
                       "main amount still reported in original currency")
    }

    func test_sortedDescendingByDisplayCurrencyEquivalent() throws {
        let table = makeUSDTable(rates: ["CNY": 8.0])
        let subs = [
            sub(amount: 10, currency: "USD"),   // 120 USD/yr equivalent
            sub(amount: 8,  currency: "CNY"),   // 12 CNY/yr → 1.5 USD/yr equiv
        ]
        let result = CurrencyBreakdown.breakdown(subs, in: "USD",
                                                  rateTable: table, now: now)
        XCTAssertEqual(result.map(\.currency), ["USD", "CNY"])
    }

    func test_unconvertibleCurrencies_sinkToBottom() throws {
        let table = makeUSDTable(rates: ["CNY": 8.0])  // EUR missing
        let subs = [
            sub(amount: 1, currency: "USD"),
            sub(amount: 999, currency: "EUR"),
        ]
        let result = CurrencyBreakdown.breakdown(subs, in: "USD",
                                                  rateTable: table, now: now)
        XCTAssertEqual(result.map(\.currency), ["USD", "EUR"],
                       "EUR has no convertible value → sorts last by tie-break key 0")
    }

    func test_inactiveAndPausedSubs_excluded() {
        let subs = [
            sub(amount: 10, currency: "USD"),
            sub(amount: 99, currency: "CNY", isActive: false),
            sub(amount: 99, currency: "EUR",
                pausedUntil: now.addingTimeInterval(86_400 * 30)),
        ]
        let result = CurrencyBreakdown.breakdown(subs, in: "USD",
                                                  rateTable: nil, now: now)
        XCTAssertEqual(result.map(\.currency), ["USD"])
    }

    // MARK: - Helpers

    private func sub(amount: Decimal,
                     currency: String,
                     isActive: Bool = true,
                     pausedUntil: Date? = nil) -> Subscription {
        Subscription(
            name: "Sub_\(currency)_\(amount)", amount: amount,
            currency: currency, billingCycle: .monthly,
            nextBillingDate: now.addingTimeInterval(86_400 * 10),
            startDate: now, category: .other,
            isActive: isActive, pausedUntil: pausedUntil
        )
    }

    private func makeUSDTable(rates: [String: Decimal]) -> FXRateTable {
        let json = (try? JSONEncoder().encode(rates)) ?? Data()
        return FXRateTable(baseCurrency: "USD", ratesJSON: json, fetchedAt: now)
    }
}
