import Foundation
import SwiftData

/// Writes a `.initial` `PriceHistoryEntry` for any pre-existing
/// `Subscription` that has none yet. Runs once on app launch after the
/// container is built, so legacy TestFlight rows pick up a baseline
/// anchor without forcing the user to make an edit first.
///
/// **Idempotent.** Subs that already have at least one history row
/// (which any sub created on v1.1+ already does, courtesy of
/// `SubscriptionRepository.insert`) are skipped on subsequent launches.
///
/// Per the v1.1 spec (`docs/design/2026-05-21-home-detail-closed-loop.md`,
/// "Price-history storage" section), this backfill is the optional
/// migration step that gives legacy rows a starting point on the Detail
/// price-history list.
@MainActor
enum PriceHistoryBackfill {

    /// Runs the backfill against the supplied context. Returns the number
    /// of `.initial` rows actually written — useful for tests and
    /// future telemetry. On failure (SwiftData fetch/save), returns 0 and
    /// silently no-ops; we'd rather under-backfill than crash launch.
    @discardableResult
    static func run(context: ModelContext) -> Int {
        let allSubs: [Subscription]
        do {
            allSubs = try context.fetch(FetchDescriptor<Subscription>())
        } catch {
            return 0
        }

        var written = 0
        for sub in allSubs {
            // SwiftData's relationship array is the authoritative count;
            // skip any sub that already has history (v1.1-created subs
            // always do).
            if !sub.priceHistory.isEmpty { continue }
            let baseline = PriceHistoryEntry(
                subscription: sub,
                amount: sub.amount,
                currency: sub.currency,
                recordedAt: sub.createdAt,
                source: .initial
            )
            context.insert(baseline)
            written += 1
        }

        if written > 0 {
            try? context.save()
        }
        return written
    }
}
