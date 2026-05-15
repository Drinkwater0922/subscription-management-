import Foundation

/// Computes the next billing date for a subscription. All calculations are anchored
/// to `startDate` rather than chained off the previous billing, which prevents the
/// classic month-end drift bug ("subscribed Jan 31, stuck on the 28th forever").
enum RenewalCalculator {

    /// Returns the next billing date strictly after `today`, given `startDate` as the
    /// anchor and `cycle` as the recurrence.
    static func nextBillingDate(
        after today: Date,
        startingFrom startDate: Date,
        cycle: BillingCycle
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // If we haven't reached the first billing yet, that's the answer.
        if today < startDate {
            return startDate
        }

        switch cycle {
        case .monthly:
            return nthDate(after: today, startDate: startDate, unit: .month, in: calendar)
        case .yearly:
            return nthDate(after: today, startDate: startDate, unit: .year, in: calendar)
        case .weekly:
            return nthDate(after: today, startDate: startDate, unit: .day, in: calendar, step: 7)
        case .customDays(let days):
            return nthDate(after: today, startDate: startDate, unit: .day, in: calendar, step: days)
        }
    }

    /// Finds the smallest N ≥ 1 such that `startDate + N×step` of `unit` is strictly
    /// after `today`. By computing every candidate from `startDate` we avoid drift.
    private static func nthDate(
        after today: Date,
        startDate: Date,
        unit: Calendar.Component,
        in calendar: Calendar,
        step: Int = 1
    ) -> Date {
        let elapsed = max(0, calendar.dateComponents([unit], from: startDate, to: today).value(for: unit) ?? 0)
        let cyclesElapsed = elapsed / step
        var n = cyclesElapsed + 1

        var candidate = calendar.date(byAdding: unit, value: n * step, to: startDate) ?? today
        while candidate <= today {
            n += 1
            candidate = calendar.date(byAdding: unit, value: n * step, to: startDate) ?? today
        }
        return candidate
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
