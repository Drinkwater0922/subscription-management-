import Foundation
import SwiftData

/// Persisted snapshot of cross-currency FX rates relative to a base
/// currency. There is exactly **one** row of this in the store at any time
/// — `FXRateTableRepository` enforces single-row semantics by overwriting
/// on each refresh.
///
/// Per the v1.1 spec (`docs/design/2026-05-21-home-detail-closed-loop.md`,
/// the "Multi-currency / FX rework" section), FX moves from "pinned at
/// creation" to "converted at display time." This table is the source of
/// truth for that conversion. It's refreshed on app foreground / Home
/// appear (Phase 2 work) and falls back to a bundled static table
/// (`fx-fallback.json`) on first launch / no network.
///
/// Rates are stored as a JSON blob (`ratesJSON`) keyed by quote currency
/// code, value = "1 unit of base = N units of quote". The
/// `decodedRates` accessor parses on demand. Whole-table read/write is
/// atomic; we never query individual rates from SwiftData.
@Model
final class FXRateTable {
    var id: UUID

    /// Currency the rates are quoted against — "1 unit of base = rate
    /// units of quote". USD in practice (Frankfurter defaults to it).
    var baseCurrency: String

    /// JSON-encoded `[quoteCode: Decimal]`. Decoded via `decodedRates`.
    var ratesJSON: Data

    /// When the rates were last fetched (network) or loaded (fallback).
    var fetchedAt: Date

    init(
        id: UUID = UUID(),
        baseCurrency: String,
        ratesJSON: Data,
        fetchedAt: Date = .now
    ) {
        self.id = id
        self.baseCurrency = baseCurrency
        self.ratesJSON = ratesJSON
        self.fetchedAt = fetchedAt
    }

    /// Decoded rate map. Returns `[:]` if the blob is corrupt — callers
    /// must treat an empty map as "no data" and skip conversion rather
    /// than crash.
    var decodedRates: [String: Decimal] {
        (try? JSONDecoder().decode([String: Decimal].self, from: ratesJSON)) ?? [:]
    }
}
