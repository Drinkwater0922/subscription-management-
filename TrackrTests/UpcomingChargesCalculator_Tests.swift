import XCTest
@testable import Trackr

/// Tests for `UpcomingChargesCalculator` — the v1.2 Insights NEXT 30 DAYS
/// DUE hero (Requirement 1 in `docs/PRD/v1.2-insights-redesign.md`).
final class UpcomingChargesCalculatorTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_780_272_000)

    // MARK: - Window inclusion

    func test_subInWindow_counted() {
        let sub = sub(name: "Netflix", amount: 15.49,
                       nextDaysFromNow: 5, currency: "USD")
        let result = UpcomingChargesCalculator.upcoming(
            [sub], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.total, Decimal(string: "15.49"))
        XCTAssertEqual(result.chargeCount, 1)
    }

    func test_subAtExactly30Days_included() {
        // PRD: nextBillingDate at exactly +30d IS included.
        let sub = sub(name: "X", amount: 10, nextDaysFromNow: 30,
                       currency: "USD")
        let result = UpcomingChargesCalculator.upcoming(
            [sub], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.chargeCount, 1)
    }

    func test_subAt31Days_excluded() {
        // PRD: 31 days out is OUT of window.
        let sub = sub(name: "X", amount: 10, nextDaysFromNow: 31,
                       currency: "USD")
        let result = UpcomingChargesCalculator.upcoming(
            [sub], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.chargeCount, 0)
        XCTAssertEqual(result.total, 0)
    }

    func test_subInPast_excluded() {
        let sub = sub(name: "Overdue", amount: 99,
                       nextDaysFromNow: -1, currency: "USD")
        let result = UpcomingChargesCalculator.upcoming(
            [sub], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.chargeCount, 0)
    }

    // MARK: - Active / paused filtering

    func test_inactiveSubs_excluded() {
        let inactive = sub(name: "I", amount: 99, nextDaysFromNow: 5,
                            currency: "USD", isActive: false)
        let active = sub(name: "A", amount: 10, nextDaysFromNow: 5,
                          currency: "USD")
        let result = UpcomingChargesCalculator.upcoming(
            [inactive, active], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.chargeCount, 1)
        XCTAssertEqual(result.total, 10)
    }

    func test_pausedSubs_excludedWhilePauseFuture() {
        let paused = sub(name: "P", amount: 99, nextDaysFromNow: 5,
                          currency: "USD",
                          pausedUntil: now.addingTimeInterval(86_400 * 10))
        let result = UpcomingChargesCalculator.upcoming(
            [paused], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.chargeCount, 0)
    }

    func test_pausedSubs_includedWhenPauseInPast() {
        let oncePaused = sub(name: "OK", amount: 10, nextDaysFromNow: 5,
                              currency: "USD",
                              pausedUntil: now.addingTimeInterval(-86_400))
        let result = UpcomingChargesCalculator.upcoming(
            [oncePaused], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.chargeCount, 1)
    }

    // MARK: - Amount = raw billed amount (not monthly-normalized)

    func test_yearlySubInWindow_addsFullYearlyAmount() {
        // A yearly sub renewing inside the window contributes its full
        // yearly charge — that's what's about to hit the user's account.
        let yearly = sub(name: "Year", amount: 120,
                          nextDaysFromNow: 10, currency: "USD",
                          cycle: .yearly)
        let result = UpcomingChargesCalculator.upcoming(
            [yearly], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.total, 120,
                       "yearly sub in window contributes full amount, not amount/12")
    }

    // MARK: - FX conversion

    func test_foreignSubConvertedViaTable() throws {
        let table = makeUSDTable(rates: ["CNY": Decimal(string: "8.0")!])
        let cnySub = sub(name: "CN", amount: 80, nextDaysFromNow: 5,
                          currency: "CNY")
        let result = UpcomingChargesCalculator.upcoming(
            [cnySub], in: "USD", rateTable: table, now: now
        )
        // 80 CNY at rate 8 = 10 USD
        XCTAssertEqual(result.total, 10)
        XCTAssertEqual(result.chargeCount, 1)
    }

    func test_foreignSubWithMissingRate_silentlyDropped() throws {
        let table = makeUSDTable(rates: ["CNY": 8.0])  // EUR missing
        let eurSub = sub(name: "E", amount: 10, nextDaysFromNow: 5,
                          currency: "EUR")
        let usdSub = sub(name: "U", amount: 5, nextDaysFromNow: 5,
                          currency: "USD")
        let result = UpcomingChargesCalculator.upcoming(
            [eurSub, usdSub], in: "USD", rateTable: table, now: now
        )
        XCTAssertEqual(result.total, 5,
                       "missing-rate sub must be dropped, not counted at 0")
        XCTAssertEqual(result.chargeCount, 1)
    }

    func test_foreignSubWithNoTable_dropped() {
        let cny = sub(name: "C", amount: 80, nextDaysFromNow: 5,
                       currency: "CNY")
        let result = UpcomingChargesCalculator.upcoming(
            [cny], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.chargeCount, 0)
    }

    // MARK: - Empty

    func test_emptyInput_zero() {
        let result = UpcomingChargesCalculator.upcoming(
            [], in: "USD", rateTable: nil, now: now
        )
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.chargeCount, 0)
    }

    // MARK: - Helpers

    private func sub(name: String,
                     amount: Decimal,
                     nextDaysFromNow: Int,
                     currency: String,
                     cycle: BillingCycle = .monthly,
                     isActive: Bool = true,
                     pausedUntil: Date? = nil) -> Subscription {
        let next = now.addingTimeInterval(TimeInterval(nextDaysFromNow) * 86_400)
        return Subscription(
            name: name, amount: amount, currency: currency,
            billingCycle: cycle, nextBillingDate: next, startDate: now,
            category: .other, isActive: isActive, pausedUntil: pausedUntil
        )
    }

    private func makeUSDTable(rates: [String: Decimal]) -> FXRateTable {
        let json = (try? JSONEncoder().encode(rates)) ?? Data()
        return FXRateTable(baseCurrency: "USD", ratesJSON: json, fetchedAt: now)
    }
}
