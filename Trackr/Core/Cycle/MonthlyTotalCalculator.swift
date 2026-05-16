import Foundation

/// Sums a collection of `Subscription` into a per-month `Decimal` total in the
/// caller-supplied `targetCurrency`.
///
/// **M11 multi-currency rules:**
/// - Subs whose `currency` already matches `targetCurrency` contribute their
///   monthly equivalent directly.
/// - Subs in a *different* currency contribute via the pinned FX rate
///   (`exchangeRateToHome × homeCurrencyAtCreation == targetCurrency`).
/// - Subs in a different currency with no pinned rate are skipped, same as
///   pre-M11 behavior — better to under-count than to invent a rate.
/// - Paused / inactive subs are always skipped.
///
/// Custom-day cycles approximate via `amount * 30 / days`.
enum MonthlyTotalCalculator {

    static func total(of subs: [Subscription], in targetCurrency: String) -> Decimal {
        let target = targetCurrency.uppercased()
        return subs.reduce(into: Decimal(0)) { running, sub in
            guard sub.isActive else { return }
            let monthly = monthlyEquivalent(amount: sub.amount, cycle: sub.billingCycle)
            if sub.currency.uppercased() == target {
                running += monthly
            } else if let rate = sub.exchangeRateToHome,
                      let pinnedHome = sub.homeCurrencyAtCreation?.uppercased(),
                      pinnedHome == target {
                running += monthly * rate
            }
            // else: foreign currency without a rate — skip.
        }
    }

    /// Per-sub helper: the monthly contribution this subscription makes towards
    /// the target currency total. Returns `nil` if the sub can't be converted
    /// (so the caller can show "—" or omit the row).
    static func monthlyContribution(of sub: Subscription, in targetCurrency: String) -> Decimal? {
        guard sub.isActive else { return nil }
        let target = targetCurrency.uppercased()
        let monthly = monthlyEquivalent(amount: sub.amount, cycle: sub.billingCycle)
        if sub.currency.uppercased() == target {
            return monthly
        }
        if let rate = sub.exchangeRateToHome,
           let pinnedHome = sub.homeCurrencyAtCreation?.uppercased(),
           pinnedHome == target {
            return monthly * rate
        }
        return nil
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
