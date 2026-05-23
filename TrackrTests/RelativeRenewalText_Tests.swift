import XCTest
@testable import Trackr

/// Tests for the pure `RelativeRenewalText` helper that backs the
/// "RENEWS IN N DAYS" / "RENEWS TODAY" / "RENEWS TOMORROW" / "OVERDUE"
/// lines on Home rows and the v1.1 Detail countdown.
final class RelativeRenewalTextTests: XCTestCase {

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s)!
    }

    // MARK: - variant

    func test_today() {
        let v = RelativeRenewalText.variant(nextBillingDate: date("2026-05-23"),
                                            now: date("2026-05-23"),
                                            calendar: utc)
        XCTAssertEqual(v, .today)
    }

    func test_today_isSameCalendarDay_ignoringClockTime() {
        let now = date("2026-05-23")
        let later = now.addingTimeInterval(60 * 60 * 12) // noon vs midnight
        let v = RelativeRenewalText.variant(nextBillingDate: later,
                                            now: now,
                                            calendar: utc)
        XCTAssertEqual(v, .today, "same calendar day must read as TODAY")
    }

    func test_tomorrow() {
        let v = RelativeRenewalText.variant(nextBillingDate: date("2026-05-24"),
                                            now: date("2026-05-23"),
                                            calendar: utc)
        XCTAssertEqual(v, .tomorrow)
    }

    func test_inFutureDays() {
        let v = RelativeRenewalText.variant(nextBillingDate: date("2026-05-26"),
                                            now: date("2026-05-23"),
                                            calendar: utc)
        XCTAssertEqual(v, .inDays(3))
    }

    func test_overdue_yesterday() {
        let v = RelativeRenewalText.variant(nextBillingDate: date("2026-05-22"),
                                            now: date("2026-05-23"),
                                            calendar: utc)
        XCTAssertEqual(v, .overdue)
    }

    func test_overdue_farPast() {
        let v = RelativeRenewalText.variant(nextBillingDate: date("2024-01-01"),
                                            now: date("2026-05-23"),
                                            calendar: utc)
        XCTAssertEqual(v, .overdue,
                       "any past day reads as overdue, no negative-day formatting")
    }

    // MARK: - shortLabel (English)

    func test_shortLabel_today_en() {
        XCTAssertEqual(RelativeRenewalText.shortLabel(for: .today, locale: Locale(identifier: "en")),
                       "RENEWS TODAY")
    }

    func test_shortLabel_tomorrow_en() {
        XCTAssertEqual(RelativeRenewalText.shortLabel(for: .tomorrow, locale: Locale(identifier: "en")),
                       "RENEWS TOMORROW")
    }

    func test_shortLabel_inDays_en_singular() {
        XCTAssertEqual(RelativeRenewalText.shortLabel(for: .inDays(1), locale: Locale(identifier: "en")),
                       "RENEWS IN 1 DAY")
    }

    func test_shortLabel_inDays_en_plural() {
        XCTAssertEqual(RelativeRenewalText.shortLabel(for: .inDays(3), locale: Locale(identifier: "en")),
                       "RENEWS IN 3 DAYS")
    }

    func test_shortLabel_overdue_en() {
        XCTAssertEqual(RelativeRenewalText.shortLabel(for: .overdue, locale: Locale(identifier: "en")),
                       "OVERDUE")
    }

    // MARK: - shortLabel (Chinese)

    func test_shortLabel_today_zh() {
        XCTAssertEqual(RelativeRenewalText.shortLabel(for: .today, locale: Locale(identifier: "zh-Hans")),
                       "今天扣款")
    }

    func test_shortLabel_tomorrow_zh() {
        XCTAssertEqual(RelativeRenewalText.shortLabel(for: .tomorrow, locale: Locale(identifier: "zh-Hans")),
                       "明天扣款")
    }

    func test_shortLabel_inDays_zh() {
        XCTAssertEqual(RelativeRenewalText.shortLabel(for: .inDays(3), locale: Locale(identifier: "zh-Hans")),
                       "3 天后扣款")
    }

    func test_shortLabel_overdue_zh() {
        XCTAssertEqual(RelativeRenewalText.shortLabel(for: .overdue, locale: Locale(identifier: "zh-Hans")),
                       "已逾期")
    }
}
