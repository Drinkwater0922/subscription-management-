import Foundation
import SwiftData

/// Orchestrates the preset library lifecycle:
///   1. Seed `PresetCache` from the bundled catalog on first launch.
///   2. Fetch the remote catalog.
///   3. If the remote version differs from the cached version, run
///      `PriceChangeDiffer` over the user's subscriptions, persist the new
///      alerts, and overwrite the cache.
@MainActor
final class PresetSync {

    private let fetcher: PresetFetcher
    private let container: ModelContainer
    private let bundle: Bundle

    init(fetcher: PresetFetcher,
         container: ModelContainer,
         bundle: Bundle = .main) {
        self.fetcher = fetcher
        self.container = container
        self.bundle = bundle
    }

    func run(now: Date = .now) async throws {
        let context = container.mainContext

        // 1. Load / seed the cache.
        let cacheRow = try context.fetch(FetchDescriptor<PresetCache>()).first
        let cachedCatalog: PresetCatalog
        if let cacheRow {
            cachedCatalog = (try? JSONDecoder().decode(PresetCatalog.self, from: cacheRow.data))
                ?? PresetCatalog(version: cacheRow.version, items: [])
        } else {
            cachedCatalog = (try? PresetBundleLoader.loadBundled(bundle: bundle))
                ?? PresetCatalog(version: "0.0.0", items: [])
            let seedPayload = (try? JSONEncoder().encode(cachedCatalog)) ?? Data()
            let seed = PresetCache(version: cachedCatalog.version,
                                   fetchedAt: now,
                                   data: seedPayload)
            context.insert(seed)
            try context.save()
        }

        // 2. Fetch remote.
        let remote = try await fetcher.fetch()

        // 3. Short-circuit on matching version.
        guard remote.version != cachedCatalog.version else { return }

        // 4. Diff against the user's subscriptions and persist new alerts.
        let subs = try context.fetch(FetchDescriptor<Subscription>())
        let alerts = PriceChangeDiffer.diff(old: cachedCatalog,
                                             new: remote,
                                             subscriptions: subs,
                                             now: now)
        let alertRepo = AlertRepository(context: context)
        for alert in alerts { try alertRepo.insert(alert) }

        // 5. Overwrite the cache row with the remote payload.
        let row = try context.fetch(FetchDescriptor<PresetCache>()).first
        let payload = (try? JSONEncoder().encode(remote)) ?? Data()
        if let row {
            row.version = remote.version
            row.fetchedAt = now
            row.data = payload
        } else {
            context.insert(PresetCache(version: remote.version, fetchedAt: now, data: payload))
        }
        try context.save()
    }
}
