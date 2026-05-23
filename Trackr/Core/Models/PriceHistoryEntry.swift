import Foundation
import SwiftData

/// One row in a subscription's price-history timeline. The Detail screen
/// reads these for that subscription, sorted by `recordedAt` descending, and
/// renders adjacent-pair deltas with color-coded up/down arrows.
///
/// Per the v1.1 spec (`docs/design/2026-05-21-home-detail-closed-loop.md`,
/// OQ2 resolution), price history is **per-subscription, not per-preset** —
/// it hangs off `Subscription` so custom subs (no `presetId`) also get
/// history. The legacy `PriceChangeAlert` is a different concern (alerting,
/// keyed by `presetId`) and stays in place untouched.
@Model
final class PriceHistoryEntry {
    var id: UUID

    /// The owning subscription. Optional per SwiftData inverse-relationship
    /// convention; the inverse is declared on `Subscription.priceHistory`
    /// with cascade-delete so removing a sub cleans up its history.
    var subscription: Subscription?

    /// Snapshot of the subscription's `amount` at the moment this entry was
    /// recorded. Stored in the subscription's `currency` at that time.
    var amount: Decimal

    /// Snapshot of the subscription's `currency` at the moment this entry
    /// was recorded. Captured so a later currency change still leaves the
    /// historical value interpretable in its original currency.
    var currency: String

    /// When this row was written. The Detail list sorts by this descending.
    var recordedAt: Date

    /// Why this entry exists. See `PriceHistorySource`.
    var source: PriceHistorySource

    init(
        id: UUID = UUID(),
        subscription: Subscription? = nil,
        amount: Decimal,
        currency: String,
        recordedAt: Date = .now,
        source: PriceHistorySource = .userEdit
    ) {
        self.id = id
        self.subscription = subscription
        self.amount = amount
        self.currency = currency
        self.recordedAt = recordedAt
        self.source = source
    }
}

/// Why a `PriceHistoryEntry` was written. v1.1 uses `.initial` and
/// `.userEdit`; `.remoteCatalog` is reserved for the eventual remote
/// preset-catalog backend (today `BrandConfig.presetCatalogURL` is a dead
/// URL, so nothing writes `.remoteCatalog` yet).
enum PriceHistorySource: String, Codable, CaseIterable {
    /// Baseline anchor written when the subscription is first inserted.
    /// Without this anchor, a sub with no edits would have no history at
    /// all — the Detail list would have nothing to render.
    case initial

    /// The user edited the subscription's amount or currency. This is the
    /// primary data source per the v1.1 spec.
    case userEdit

    /// The remote preset catalog reported a price change for this
    /// subscription's preset. Reserved — not written by v1.1.
    case remoteCatalog
}
