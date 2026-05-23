import Foundation

/// Sums a collection of `Subscription` into a per-month `Decimal` total in the
/// caller-supplied `targetCurrency`.
///
/// **v1.1 multi-currency rules (replaces the M11 "pinned at creation" model):**
/// - Subs whose `currency` already matches `targetCurrency` contribute their
///   monthly equivalent directly.
/// - Subs in a *different* currency are converted via the supplied
///   `FXRateTable`. If no table is supplied, or the table is missing one of
///   the currencies, the sub is skipped (under-count beats invent-a-rate).
/// - Paused / inactive subs are always skipped.
///
/// Custom-day cycles approximate via `amount * 30 / days`.
///
/// **Migration from M11.** The legacy `Subscription.exchangeRateToHome` /
/// `homeCurrencyAtCreation` fields stay on the model but no longer drive
/// aggregation. The whole-table FX rework is the v1.1 fix for the bug
/// where switching display currency silently dropped foreign-currency subs.
enum MonthlyTotalCalculator {

    static func total(of subs: [Subscription],
                      in targetCurrency: String,
                      rateTable: FXRateTable? = nil) -> Decimal {
        subs.reduce(into: Decimal(0)) { running, sub in
            if let contribution = monthlyContribution(of: sub,
                                                       in: targetCurrency,
                                                       rateTable: rateTable) {
                running += contribution
            }
        }
    }

    /// Per-sub helper: the monthly contribution this subscription makes
    /// towards the target currency total. Returns `nil` when the sub is
    /// inactive, or when it's in a foreign currency we cannot convert.
    static func monthlyContribution(of sub: Subscription,
                                    in targetCurrency: String,
                                    rateTable: FXRateTable? = nil) -> Decimal? {
        guard sub.isActive else { return nil }
        let target = targetCurrency.uppercased()
        let monthly = monthlyEquivalent(amount: sub.amount, cycle: sub.billingCycle)
        let source = sub.currency.uppercased()
        if source == target {
            return monthly
        }
        guard let table = rateTable else { return nil }
        return FXRateTableRepository.convert(amount: monthly,
                                             from: source,
                                             to: target,
                                             using: table)
    }

    /// Pure conversion of a single (amount, cycle) into its per-month value
    /// in the same currency. Used by `total` and by `AnnualSpendCalculator`.
    static func monthlyEquivalent(amount: Decimal, cycle: BillingCycle) -> Decimal {
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
