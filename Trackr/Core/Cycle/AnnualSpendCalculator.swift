import Foundation

/// Sums a collection of `Subscription` into a per-year `Decimal` total in the
/// caller-supplied `targetCurrency`. Drives the v1.1 Home hero "Subscriptions
/// · this year $437" headline.
///
/// Same conversion rules as `MonthlyTotalCalculator` — same-currency subs
/// contribute directly, foreign-currency subs need a supplied `FXRateTable`
/// or they are skipped (under-count beats invent-a-rate).
///
/// Implemented as `monthly * 12` rather than a parallel cycle-multiplier
/// table so the two calculators can never drift apart.
enum AnnualSpendCalculator {

    static func total(of subs: [Subscription],
                      in targetCurrency: String,
                      rateTable: FXRateTable? = nil) -> Decimal {
        MonthlyTotalCalculator.total(of: subs,
                                     in: targetCurrency,
                                     rateTable: rateTable) * 12
    }
}
