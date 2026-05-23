import Foundation

/// Pure helper that turns a subscription's `PriceHistoryEntry` rows into
/// the renderable list the v1.1 Detail screen shows.
///
/// Two responsibilities:
///   * Sort entries by `recordedAt` descending so the newest sits on top.
///   * For each pair of adjacent entries (newer / older), compute the
///     price delta and which direction it points. Color comes from the
///     `Direction` case; the view layer maps it to lime / warn-red.
///
/// Adjacent entries in *different currencies* don't get a meaningful
/// delta (10 USD → 70 CNY isn't "+60"), so their direction reads as
/// `.currencyChanged` and the view can render "→" instead of an arrow.
enum PriceHistoryFormatter {

    enum Direction: Equatable {
        case decrease     // newer < older → lime
        case increase     // newer > older → warn-red
        case unchanged    // newer == older → muted
        case currencyChanged  // currency differs — no numeric delta
    }

    struct Row: Equatable {
        let recordedAt: Date
        let amount: Decimal
        let currency: String
        let source: PriceHistorySource
        /// Difference vs the *older* entry directly below this one in the
        /// sorted list. `nil` when this is the oldest entry (no neighbor
        /// to compare against) or when the currencies differ.
        let delta: Decimal?
        let direction: Direction
    }

    /// Render the timeline. Empty input → empty output. A single entry
    /// returns one row with `direction = .unchanged` and `delta = nil` —
    /// the view treats single-entry timelines as "no price changes yet"
    /// and may choose to hide the section entirely.
    static func rows(from entries: [PriceHistoryEntry]) -> [Row] {
        let sorted = entries.sorted { $0.recordedAt > $1.recordedAt }
        var result: [Row] = []
        for (index, entry) in sorted.enumerated() {
            let older = index + 1 < sorted.count ? sorted[index + 1] : nil
            let direction: Direction
            let delta: Decimal?
            if let older {
                if older.currency.uppercased() != entry.currency.uppercased() {
                    direction = .currencyChanged
                    delta = nil
                } else {
                    let diff = entry.amount - older.amount
                    delta = diff
                    if diff > 0 { direction = .increase }
                    else if diff < 0 { direction = .decrease }
                    else { direction = .unchanged }
                }
            } else {
                direction = .unchanged
                delta = nil
            }
            result.append(Row(recordedAt: entry.recordedAt,
                              amount: entry.amount,
                              currency: entry.currency,
                              source: entry.source,
                              delta: delta,
                              direction: direction))
        }
        return result
    }

    /// True when the timeline has no actual change events — i.e. only the
    /// .initial baseline, or every adjacent pair is unchanged. The Detail
    /// view uses this to decide whether to render the history block or
    /// show the "no price changes yet" placeholder.
    static func hasChanges(_ entries: [PriceHistoryEntry]) -> Bool {
        let rows = rows(from: entries)
        return rows.contains { row in
            switch row.direction {
            case .increase, .decrease, .currencyChanged: return true
            case .unchanged: return false
            }
        }
    }
}
