import Foundation

/// Groups active subscriptions by their **original** billing currency and
/// reports the monthly spend per currency plus an annual approximation in
/// the display currency. Drives the "BY CURRENCY" section of the v1.2
/// Insights view.
///
/// Pure function. The original currency is preserved on the main amount
/// (so a user with foreign-currency subs sees their real currency
/// exposure); the FX-converted annual is provided as a side channel for
/// the "≈ /yr" approximation column.
///
/// View layer hides this section when fewer than two distinct currencies
/// are represented (single-currency users get no breakdown).
enum CurrencyBreakdown {

    struct Row: Equatable {
        /// Original currency code (uppercased), e.g. "USD" or "CNY".
        let currency: String
        /// Per-currency monthly spend, **in that currency** (no FX).
        let monthlyAmount: Decimal
        /// `monthlyAmount * 12`, converted to the display currency via
        /// the cached `FXRateTable`. `nil` when the currency is missing
        /// from the cache (the view shows an em-dash in that case).
        let annualInDisplayCurrency: Decimal?
    }

    static func breakdown(_ subs: [Subscription],
                          in displayCurrency: String,
                          rateTable: FXRateTable?,
                          now: Date = .now) -> [Row] {
        // Sum monthly contribution per original currency. Skip paused /
        // inactive subs — the section reports the live spend exposure.
        var sums: [String: Decimal] = [:]
        for sub in subs {
            guard sub.isActive else { continue }
            if let pausedUntil = sub.pausedUntil, pausedUntil > now { continue }
            let monthly = MonthlyTotalCalculator.monthlyEquivalent(
                amount: sub.amount, cycle: sub.billingCycle
            )
            sums[sub.currency.uppercased(), default: 0] += monthly
        }
        guard !sums.isEmpty else { return [] }

        let target = displayCurrency.uppercased()
        let rowsWithSortKey: [(row: Row, sortKey: Decimal)] = sums.map { code, monthly in
            let annual = monthly * 12
            let annualInDisplay: Decimal?
            if code == target {
                annualInDisplay = annual
            } else if let table = rateTable {
                annualInDisplay = FXRateTableRepository.convert(
                    amount: annual, from: code, to: target, using: table
                )
            } else {
                annualInDisplay = nil
            }
            // PRD: "Sort by monthly contribution descending, where
            // comparison is done via the display-currency equivalent."
            // Use 0 for unconvertible currencies so they sink to the
            // bottom rather than randomly intercalating.
            return (Row(currency: code,
                        monthlyAmount: monthly,
                        annualInDisplayCurrency: annualInDisplay),
                    annualInDisplay ?? 0)
        }

        return rowsWithSortKey
            .sorted {
                if $0.sortKey != $1.sortKey { return $0.sortKey > $1.sortKey }
                return $0.row.currency < $1.row.currency
            }
            .map(\.row)
    }
}
