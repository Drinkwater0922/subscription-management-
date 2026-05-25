import Foundation

/// Groups active subscriptions by `Category` and reports the per-category
/// monthly spend + share of total. Drives the "BY CATEGORY" horizontal
/// fill-bar section on the v1.2 Insights view.
///
/// Pure function. View layer decides whether to render based on
/// `result.count >= 2` (single-category users get this block hidden per
/// the v1.2 PRD).
enum CategoryBreakdown {

    struct Row: Equatable {
        let category: Category
        /// Per-category monthly spend, in display currency.
        let monthlyAmount: Decimal
        /// Share of the total active monthly spend, in percent (0–100).
        let percentage: Double
    }

    static func breakdown(_ subs: [Subscription],
                          in displayCurrency: String,
                          rateTable: FXRateTable?) -> [Row] {
        // Sum per-category monthly contribution (already FX-converted to
        // the display currency by MonthlyTotalCalculator).
        var sums: [Category: Decimal] = [:]
        for sub in subs {
            guard let monthly = MonthlyTotalCalculator.monthlyContribution(
                of: sub, in: displayCurrency, rateTable: rateTable
            ) else { continue }
            sums[sub.category, default: 0] += monthly
        }

        let total = sums.values.reduce(0, +)
        guard total > 0 else { return [] }

        return sums.map { category, sum -> Row in
            let pct = (NSDecimalNumber(decimal: sum).doubleValue
                       / NSDecimalNumber(decimal: total).doubleValue) * 100
            return Row(category: category,
                       monthlyAmount: sum,
                       percentage: pct)
        }
        .sorted {
            if $0.monthlyAmount != $1.monthlyAmount {
                return $0.monthlyAmount > $1.monthlyAmount
            }
            // Stable secondary order: alphabetical by raw value, so two
            // categories with identical sums render in a deterministic
            // order across runs.
            return $0.category.rawValue < $1.category.rawValue
        }
    }
}
