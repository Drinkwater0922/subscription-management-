import XCTest
@testable import Trackr

final class RenewalCalculatorTests: XCTestCase {

    // MARK: helpers

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)!
    }

    // MARK: monthly happy paths

    func test_monthly_today_isBeforeFirstBilling_returnsStartDate() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-01-01"),
            startingFrom: date("2026-02-15"),
            cycle: .monthly
        )
        XCTAssertEqual(next, date("2026-02-15"))
    }

    func test_monthly_today_isAfterFirstBilling_returnsSecondCycle() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-02-16"),
            startingFrom: date("2026-02-15"),
            cycle: .monthly
        )
        XCTAssertEqual(next, date("2026-03-15"))
    }

    func test_monthly_today_isExactlyOnPreviousBilling_returnsNextCycle() {
        // Convention: if today == startDate, the user is on day 0 of cycle 1.
        // Next billing is one full cycle later.
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-02-15"),
            startingFrom: date("2026-02-15"),
            cycle: .monthly
        )
        XCTAssertEqual(next, date("2026-03-15"))
    }

    // MARK: month-end anchoring (the drift bug)

    func test_monthly_31stStartDate_preservesAnchor_acrossShortMonths() {
        let start = date("2026-01-31")

        XCTAssertEqual(
            RenewalCalculator.nextBillingDate(after: date("2026-01-31"), startingFrom: start, cycle: .monthly),
            date("2026-02-28"),
            "Feb cycle clamps to month-end"
        )
        XCTAssertEqual(
            RenewalCalculator.nextBillingDate(after: date("2026-02-28"), startingFrom: start, cycle: .monthly),
            date("2026-03-31"),
            "March cycle must restore the 31st anchor"
        )
        XCTAssertEqual(
            RenewalCalculator.nextBillingDate(after: date("2026-04-30"), startingFrom: start, cycle: .monthly),
            date("2026-05-31"),
            "May cycle restores 31st after April's 30"
        )
    }

    // MARK: leap years

    func test_yearly_feb29Start_inLeapYear_landsOnFeb28InNonLeap() {
        let start = date("2024-02-29")
        let next = RenewalCalculator.nextBillingDate(
            after: date("2024-12-31"),
            startingFrom: start,
            cycle: .yearly
        )
        XCTAssertEqual(next, date("2025-02-28"))
    }

    func test_yearly_feb29Start_returnsToFeb29InNextLeapYear() {
        let start = date("2024-02-29")
        let next = RenewalCalculator.nextBillingDate(
            after: date("2027-12-31"),
            startingFrom: start,
            cycle: .yearly
        )
        XCTAssertEqual(next, date("2028-02-29"))
    }

    // MARK: weekly

    func test_weekly_today_isBeforeStart_returnsStart() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-02-01"),
            startingFrom: date("2026-02-08"),
            cycle: .weekly
        )
        XCTAssertEqual(next, date("2026-02-08"))
    }

    func test_weekly_today_isMidCycle_returnsNextWeekFromStart() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-02-10"),
            startingFrom: date("2026-02-08"),
            cycle: .weekly
        )
        XCTAssertEqual(next, date("2026-02-15"))
    }

    // MARK: customDays

    func test_customDays_60_today_pastStart() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-04-01"),
            startingFrom: date("2026-01-01"),
            cycle: .customDays(60)
        )
        // cycles: 2026-01-01, 2026-03-02, 2026-05-01
        XCTAssertEqual(next, date("2026-05-01"))
    }
}
