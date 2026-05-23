import Foundation

/// Pure helper for the "RENEWS IN N DAYS" line that v1.1 adds beside every
/// Home row and to the prominent Detail countdown.
///
/// Two layers so callers can compose:
///
///   * `variant(nextBillingDate:now:calendar:)` — calendar math only.
///     Reads like one of `.today / .tomorrow / .inDays(N) / .overdue`.
///   * `shortLabel(for:locale:)` — renders a variant as the localized
///     uppercase pixel-art label. Hand-rolled localization (rather than
///     `Localizable.xcstrings`) so the pure helper stays usable from
///     unit tests without spinning up a locale bundle.
enum RelativeRenewalText {

    enum Variant: Equatable {
        case today
        case tomorrow
        case inDays(Int)
        case overdue
    }

    /// Compute the variant for an upcoming billing date relative to `now`.
    /// Compares whole calendar days in the supplied `calendar`, so a
    /// renewal at any time today reads as `.today` regardless of clock
    /// time. Any past day reads as `.overdue` — we never surface a
    /// negative-day count.
    static func variant(nextBillingDate: Date,
                        now: Date = .now,
                        calendar: Calendar = .current) -> Variant {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfNext = calendar.startOfDay(for: nextBillingDate)
        let days = calendar.dateComponents([.day],
                                            from: startOfToday,
                                            to: startOfNext).day ?? 0
        if days < 0 { return .overdue }
        if days == 0 { return .today }
        if days == 1 { return .tomorrow }
        return .inDays(days)
    }

    /// Localized uppercase pixel-art label for the variant. Falls back to
    /// English for any locale outside `zh-Hans` / `zh-Hant`.
    static func shortLabel(for variant: Variant,
                           locale: Locale = .current) -> String {
        let isChinese = locale.language.languageCode?.identifier == "zh"
        switch variant {
        case .today:
            return isChinese ? "今天扣款" : "RENEWS TODAY"
        case .tomorrow:
            return isChinese ? "明天扣款" : "RENEWS TOMORROW"
        case .inDays(let n):
            if isChinese { return "\(n) 天后扣款" }
            let unit = n == 1 ? "DAY" : "DAYS"
            return "RENEWS IN \(n) \(unit)"
        case .overdue:
            return isChinese ? "已逾期" : "OVERDUE"
        }
    }

    /// Convenience for callers that have a `Subscription` in hand.
    static func shortLabel(for subscription: Subscription,
                           now: Date = .now,
                           calendar: Calendar = .current,
                           locale: Locale = .current) -> String {
        shortLabel(for: variant(nextBillingDate: subscription.nextBillingDate,
                                now: now,
                                calendar: calendar),
                   locale: locale)
    }
}
