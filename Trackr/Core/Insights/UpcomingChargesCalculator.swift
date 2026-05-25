import Foundation

/// Computes the "NEXT 30 DAYS DUE" hero number for the v1.2 Insights view.
///
/// Sums the **billed amount** (not monthly-equivalent) of every active
/// subscription whose `nextBillingDate` falls within the window. A yearly
/// subscription renewing inside the window contributes its full yearly
/// charge — this is what's actually going to leave the user's account
/// during the window, which is the whole point of the hero.
///
/// Pure function. Conversion is read-time via `FXRateTableRepository`;
/// a sub in a currency the cache can't convert is silently dropped
/// rather than counted at the wrong number.
enum UpcomingChargesCalculator {

    struct Result: Equatable {
        /// Sum of contributing subscriptions' amounts, in `targetCurrency`.
        let total: Decimal
        /// Number of subscriptions contributing to `total`. Drives the
        /// "N CHARGES INCOMING" subtitle on the hero.
        let chargeCount: Int
    }

    /// Default window is 30 days; the parameter exists so tests can pin
    /// the boundary precisely without dealing with calendar arithmetic.
    static func upcoming(_ subs: [Subscription],
                         in targetCurrency: String,
                         rateTable: FXRateTable?,
                         now: Date = .now,
                         windowDays: Int = 30) -> Result {
        let cutoff = now.addingTimeInterval(TimeInterval(windowDays) * 86_400)
        let target = targetCurrency.uppercased()

        var total: Decimal = 0
        var count = 0

        for sub in subs {
            // Active + not currently paused.
            guard sub.isActive else { continue }
            if let pausedUntil = sub.pausedUntil, pausedUntil > now { continue }

            // Inside the window. PRD: `nextBillingDate ∈ [now, now+30d]`,
            // including the endpoint at +30d.
            guard sub.nextBillingDate >= now,
                  sub.nextBillingDate <= cutoff else { continue }

            // Convert the raw billed amount to the display currency.
            let source = sub.currency.uppercased()
            let converted: Decimal?
            if source == target {
                converted = sub.amount
            } else if let table = rateTable {
                converted = FXRateTableRepository.convert(
                    amount: sub.amount, from: source, to: target, using: table
                )
            } else {
                converted = nil
            }

            // Skip subs we cannot price in the target currency. Under-count
            // beats reporting a wrong total.
            guard let amount = converted else { continue }
            total += amount
            count += 1
        }

        return Result(total: total, chargeCount: count)
    }
}
