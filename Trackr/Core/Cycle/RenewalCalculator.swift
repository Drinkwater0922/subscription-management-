import Foundation

/// Computes the next billing date for a subscription. All calculations are anchored
/// to `startDate` rather than chained off the previous billing, which prevents the
/// classic month-end drift bug ("subscribed Jan 31, stuck on the 28th forever").
enum RenewalCalculator {

    /// Shared Gregorian/UTC calendar. UTC removes local-DST drift; the Gregorian
    /// identifier is the only one Apple guarantees consistent month arithmetic for.
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return cal
    }()

    /// Returns the next billing date strictly after `today`, given `startDate` as the
    /// anchor and `cycle` as the recurrence.
    ///
    /// Defensive behavior: `customDays(N)` with N ≤ 0 is an invalid cycle and returns
    /// `Date.distantFuture` so the broken subscription never surfaces as "due soon"
    /// in the UI. The repository/form layer should validate `N > 0` upstream; this
    /// is the last-line safety net.
    static func nextBillingDate(
        after today: Date,
        startingFrom startDate: Date,
        cycle: BillingCycle
    ) -> Date {
        // First billing hasn't happened yet.
        if today < startDate {
            return startDate
        }

        switch cycle {
        case .monthly:
            return nthDate(after: today, startDate: startDate, unit: .month, step: 1)
        case .yearly:
            return nthDate(after: today, startDate: startDate, unit: .year, step: 1)
        case .weekly:
            return nthDate(after: today, startDate: startDate, unit: .day, step: 7)
        case .customDays(let days):
            guard days > 0 else { return .distantFuture }
            return nthDate(after: today, startDate: startDate, unit: .day, step: days)
        }
    }

    /// Finds the smallest N ≥ 1 such that `startDate + N×step` of `unit` is strictly
    /// after `today`. By computing every candidate from `startDate` we avoid drift.
    private static func nthDate(
        after today: Date,
        startDate: Date,
        unit: Calendar.Component,
        step: Int
    ) -> Date {
        let elapsed = max(0, calendar.dateComponents([unit], from: startDate, to: today).value(for: unit) ?? 0)
        let cyclesElapsed = elapsed / step
        var n = cyclesElapsed + 1

        // Bounded iteration: if the Calendar refuses to produce a candidate (overflow,
        // representability), break rather than loop forever.
        while true {
            guard let candidate = calendar.date(byAdding: unit, value: n * step, to: startDate) else {
                // Calendar can't represent this date — return a sentinel rather than crash.
                return .distantFuture
            }
            if candidate > today {
                return candidate
            }
            n += 1
        }
    }
}

private extension DateComponents {
    func value(for unit: Calendar.Component) -> Int? {
        switch unit {
        case .month:       return month
        case .year:        return year
        case .day:         return day
        case .weekOfYear:  return weekOfYear
        default:           return nil
        }
    }
}
