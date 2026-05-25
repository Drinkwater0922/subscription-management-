import Foundation

/// Ranks subscriptions by how "suspect" they are — i.e. how strongly they
/// suggest "you should probably cancel this." Implements the scoring spec
/// from `docs/PRD/v1.2-insights-redesign.md` Requirement 3.
///
/// Pure function. Deterministic given the same inputs (subscriptions,
/// display currency, FX table, and `now`). No side effects, no I/O.
///
/// **Scoring (40 / 30 / 30, total 0–100):**
/// ```
/// priceWeight       = (monthlyContribution_in_displayCurrency / max_monthly) * 40
/// imminenceWeight   = max(0, 1 - daysUntilNextBilling / 30) * 30
/// stagnationWeight  = min(daysSinceUpdatedAt / 180, 1) * 30
/// ```
///
/// **Candidate set:** active, not paused, `nextBillingDate >= now`, and the
/// FX conversion succeeds. Trial subscriptions are included with their
/// post-trial `amount` (the `Subscription.amount` field is already that
/// value; trials don't have a separate trial-price field).
///
/// **Sort:** score desc → monthlyContribution desc → name asc (stable).
enum SuspectRanker {

    /// One row in the ranked list, ready for the Insights view to render.
    /// Not `Equatable` because `Subscription` is a SwiftData `@Model` class
    /// without value equality. Tests compare individual fields instead.
    struct Ranked {
        /// 1-based rank in the returned list (1 = most suspect).
        let rank: Int
        /// The underlying subscription. The view reads its `name`,
        /// `currency`, etc. directly.
        let subscription: Subscription
        /// Monthly contribution in the caller's display currency. The view
        /// shows this as `/mo` and divides by 30 for `/day`.
        let monthlyContribution: Decimal
        /// Total suspect score (0–100). Useful for tests + diagnostics;
        /// the view doesn't render this directly.
        let score: Double
        /// Tags to show under the row. Ordered for display: expensive →
        /// renewsIn → notTouchedIn. At most 2 entries, chosen by which
        /// component weight contributed most.
        let tags: [Tag]
    }

    /// Context label shown under each ranked row.
    enum Tag: Equatable {
        /// Sub's monthly cost is meaningfully high relative to the user's
        /// other subscriptions. Emitted when `priceWeight > 25`.
        case expensive
        /// Next billing is close. Emitted when `imminenceWeight > 15`.
        /// `days` is the actual whole-days-until-billing, for the label.
        case renewsIn(days: Int)
        /// User hasn't touched (edited) this subscription in a long time.
        /// Emitted when `stagnationWeight > 15`. `days` is the actual
        /// days-since-`updatedAt`, capped only for the score (the label
        /// always reports the true number).
        case notTouchedIn(days: Int)
    }

    /// Main entry point. Returns up to `topN` ranked rows, descending by
    /// suspect score. Empty array if no candidates qualify.
    static func rank(_ subs: [Subscription],
                     in displayCurrency: String,
                     rateTable: FXRateTable?,
                     now: Date = .now,
                     topN: Int = 5) -> [Ranked] {

        // 1. Filter to viable candidates and capture their monthly cost in
        //    the display currency. A sub gets dropped here when:
        //      • inactive, or
        //      • paused with pausedUntil > now, or
        //      • already-overdue (nextBillingDate < now), or
        //      • foreign currency we can't convert (rare).
        let candidates: [(sub: Subscription, monthly: Decimal)] = subs.compactMap { sub in
            guard sub.isActive else { return nil }
            if let pausedUntil = sub.pausedUntil, pausedUntil > now { return nil }
            guard sub.nextBillingDate >= now else { return nil }
            guard let monthly = MonthlyTotalCalculator.monthlyContribution(
                of: sub, in: displayCurrency, rateTable: rateTable
            ) else { return nil }
            return (sub, monthly)
        }

        guard !candidates.isEmpty else { return [] }

        let maxMonthly = candidates.map(\.monthly).max() ?? 0
        let calendar = Calendar.current

        // 2. Score each candidate.
        let scored = candidates.map { item -> Scored in
            let monthly = item.monthly

            // priceWeight (0–40)
            let priceWeight: Double
            if maxMonthly == 0 {
                priceWeight = 0
            } else {
                let m = NSDecimalNumber(decimal: monthly).doubleValue
                let mMax = NSDecimalNumber(decimal: maxMonthly).doubleValue
                priceWeight = (m / mMax) * 40
            }

            // imminenceWeight (0–30)
            let daysUntilNextBilling = max(0, calendar.dateComponents(
                [.day], from: now, to: item.sub.nextBillingDate
            ).day ?? 0)
            let imminenceWeight = max(0.0, 1.0 - Double(daysUntilNextBilling) / 30.0) * 30

            // stagnationWeight (0–30). Cap at 180 days for the score itself;
            // the tag label still reports the real days-since-edit.
            let daysSinceUpdated = max(0, calendar.dateComponents(
                [.day], from: item.sub.updatedAt, to: now
            ).day ?? 0)
            let stagnationWeight = min(Double(daysSinceUpdated) / 180.0, 1.0) * 30

            return Scored(
                sub: item.sub,
                monthly: monthly,
                priceWeight: priceWeight,
                imminenceWeight: imminenceWeight,
                stagnationWeight: stagnationWeight,
                daysUntilNextBilling: daysUntilNextBilling,
                daysSinceUpdated: daysSinceUpdated
            )
        }

        // 3. Sort: score desc → monthly desc → name asc (stable).
        let sorted = scored.sorted { a, b in
            if a.totalScore != b.totalScore { return a.totalScore > b.totalScore }
            if a.monthly != b.monthly { return a.monthly > b.monthly }
            return a.sub.name < b.sub.name
        }

        // 4. Take top N, assign ranks, compute display tags.
        return sorted.prefix(topN).enumerated().map { idx, s in
            Ranked(
                rank: idx + 1,
                subscription: s.sub,
                monthlyContribution: s.monthly,
                score: s.totalScore,
                tags: tagsFor(s)
            )
        }
    }

    // MARK: - Internals

    /// Per-candidate workpad. Not exposed.
    private struct Scored {
        let sub: Subscription
        let monthly: Decimal
        let priceWeight: Double
        let imminenceWeight: Double
        let stagnationWeight: Double
        let daysUntilNextBilling: Int
        let daysSinceUpdated: Int
        var totalScore: Double { priceWeight + imminenceWeight + stagnationWeight }
    }

    /// Pick up to two tags by individual weight, then re-order for display
    /// (expensive → renewsIn → notTouchedIn). Thresholds per PRD:
    ///   • EXPENSIVE         when priceWeight    > 25
    ///   • RENEWS IN X DAYS  when imminenceWeight > 15
    ///   • NOT TOUCHED IN X  when stagnationWeight > 15
    private static func tagsFor(_ s: Scored) -> [Tag] {
        var candidates: [(tag: Tag, weight: Double)] = []
        if s.priceWeight > 25 {
            candidates.append((.expensive, s.priceWeight))
        }
        if s.imminenceWeight > 15 {
            candidates.append((.renewsIn(days: s.daysUntilNextBilling),
                                s.imminenceWeight))
        }
        if s.stagnationWeight > 15 {
            candidates.append((.notTouchedIn(days: s.daysSinceUpdated),
                                s.stagnationWeight))
        }
        // Top 2 by weight, then re-sort by display priority.
        let topTwo = candidates.sorted { $0.weight > $1.weight }.prefix(2)
        return topTwo
            .sorted { displayOrder(of: $0.tag) < displayOrder(of: $1.tag) }
            .map(\.tag)
    }

    private static func displayOrder(of tag: Tag) -> Int {
        switch tag {
        case .expensive: return 0
        case .renewsIn: return 1
        case .notTouchedIn: return 2
        }
    }
}
