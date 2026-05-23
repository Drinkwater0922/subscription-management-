import Foundation

/// Seed-on-first-launch + refresh-when-stale service for the `FXRateTable`.
///
/// **Why this exists.** Per the v1.1 spec (`docs/design/2026-05-21-home-detail-closed-loop.md`,
/// "Multi-currency / FX rework"), the Home hero converts every subscription
/// from `sub.currency` into the user's display currency at *display time*
/// via the persisted `FXRateTable`. That table has to be populated before
/// the first conversion runs — otherwise foreign-currency subs would be
/// silently dropped from the total again, which is exactly the bug v1.1
/// fixes.
///
/// Two responsibilities, each a pure entry point so callers can wire them
/// in different lifecycle hooks:
///
///   * `seedIfNeeded` — first launch / no table yet → write the bundled
///     fallback so we have *some* rates to convert with. Idempotent: if a
///     table already exists it is left untouched (the cached table is
///     always fresher than the bundle).
///   * `refreshIfStale` — periodic check on app foreground / Home appear.
///     If the cached table is older than ~24h and the network is up,
///     overwrite the cache via the supplied `FXLatestRatesClient`. Never
///     blocks the UI; failures are swallowed and the cached table is
///     preserved so the user keeps seeing converted totals.
@MainActor
enum FXRateBootstrap {

    /// 24h staleness window. Matches the v1.1 spec.
    static let staleInterval: TimeInterval = 24 * 60 * 60

    /// Write the bundled fallback rates into the repository if no table
    /// is persisted yet. No-op when a table already exists.
    static func seedIfNeeded(repository: FXRateTableRepository,
                             fallback: FXFallbackLoader.Bundle) {
        do {
            if try repository.current() != nil { return }
            try repository.replace(baseCurrency: fallback.baseCurrency,
                                   rates: fallback.rates,
                                   fetchedAt: fallback.fetchedAt)
        } catch {
            // Bootstrap is best-effort; a SwiftData failure here would
            // surface as "empty totals" downstream, which is preferable
            // to a launch-time crash.
        }
    }

    /// Best-effort: read the bundle off disk and seed from it. Convenience
    /// wrapper used by call sites that don't want to handle the
    /// `FXFallbackLoader.load()` error themselves.
    static func seedIfNeeded(repository: FXRateTableRepository,
                             from bundle: Foundation.Bundle = .main) {
        guard let loaded = try? FXFallbackLoader.load(from: bundle) else { return }
        seedIfNeeded(repository: repository, fallback: loaded)
    }

    /// Refresh the persisted table if it is older than `staleInterval`.
    /// Returns `true` iff a refresh actually wrote new rates.
    ///
    /// Failure modes — all return `false` and leave the cached table
    /// untouched:
    ///   * No table persisted yet (the caller should `seedIfNeeded` first).
    ///   * Cached table is still fresh (no network call made).
    ///   * Network call throws (offline, server error).
    ///   * Network call returns an empty rate dictionary (treated as a
    ///     soft failure rather than wiping the cache).
    @discardableResult
    static func refreshIfStale(repository: FXRateTableRepository,
                               client: FXLatestRatesClient,
                               now: Date = .now) async -> Bool {
        guard let table = try? repository.current() else { return false }
        if now.timeIntervalSince(table.fetchedAt) < staleInterval {
            return false
        }

        let base = table.baseCurrency
        let rates: [String: Decimal]
        do {
            rates = try await client.latestRates(base: base)
        } catch {
            return false
        }
        guard !rates.isEmpty else { return false }

        do {
            try repository.replace(baseCurrency: base, rates: rates, fetchedAt: now)
            return true
        } catch {
            return false
        }
    }
}
