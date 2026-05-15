import Foundation

/// Sums a collection of `Subscription` into a per-month `Decimal` total in one
/// currency. Multi-currency aggregation is deliberately deferred: subscriptions
/// whose `currency` differs from `targetCurrency` are skipped, as are paused or
/// inactive subscriptions. Custom-day cycles are converted via `amount * 30 / days`,
/// which is the closest user-intuitive approximation without introducing a calendar.
enum MonthlyTotalCalculator {

    static func total(of subs: [Subscription], in targetCurrency: String) -> Decimal {
        let target = targetCurrency.uppercased()
        return subs.reduce(into: Decimal(0)) { running, sub in
            guard sub.isActive, sub.currency.uppercased() == target else { return }
            running += monthlyEquivalent(amount: sub.amount, cycle: sub.billingCycle)
        }
    }

    private static func monthlyEquivalent(amount: Decimal, cycle: BillingCycle) -> Decimal {
        switch cycle {
        case .monthly:
            return amount
        case .yearly:
            return amount / 12
        case .weekly:
            return amount * 52 / 12
        case .customDays(let days):
            guard days > 0 else { return 0 }
            return amount * 30 / Decimal(days)
        }
    }
}
