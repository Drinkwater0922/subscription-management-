import Foundation
import Observation
import SwiftData

/// Runtime entitlement state. `current` is observable; SwiftUI views can
/// subscribe via `@Environment(ProEntitlement.self)`. Writes through to
/// `UserSettings.proStatus` on every change so widgets / cold-launch checks
/// have a cached value to read.
@Observable
@MainActor
final class ProEntitlement {

    private(set) var current: ProStatus = .free

    private let client: StoreKitClient
    private let container: ModelContainer
    // nonisolated(unsafe) lets deinit cancel the task without crossing actor boundaries.
    nonisolated(unsafe) private var listenerTask: Task<Void, Never>?

    init(client: StoreKitClient, container: ModelContainer) {
        self.client = client
        self.container = container
    }

    /// Resolves the initial entitlement and starts listening for updates.
    /// Idempotent — calling twice is a no-op.
    func start() async {
        if listenerTask != nil { return }
        let initial = await client.currentEntitlement()
        await update(to: initial)

        // Call transactionUpdates() here (on the main actor, before the task
        // starts) so that the fake's `updatesContinuation` is populated and
        // ready before any test code tries to yield into it.
        let updates = client.transactionUpdates()

        listenerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await status in updates {
                await self.update(to: status)
            }
        }
    }

    func purchase(productID: String) async throws {
        let resolved = try await client.purchase(productID: productID)
        await update(to: resolved)
    }

    func availableProducts() async -> [ProProductDisplay] {
        await client.availableProducts()
    }

    /// Force a re-read of the current entitlement. Used by "Restore purchases".
    func refresh() async {
        let resolved = await client.currentEntitlement()
        await update(to: resolved)
    }

    // TODO(M11-launch): remove this debug helper before final App Store submission.
    /// Local-only reset of the UI-facing entitlement to `.free`. Does NOT refund
    /// or void the underlying StoreKit transaction — used during pre-launch
    /// paywall QA in TestFlight so we can re-trigger the paywall after a sandbox
    /// purchase. The next `start()` (cold launch) will resolve back to whatever
    /// `currentEntitlements` reports.
    func debugResetToFree() async {
        await update(to: .free)
    }

    deinit {
        listenerTask?.cancel()
    }

    // MARK: - private

    private func update(to status: ProStatus) async {
        current = status
        do {
            let settings = try SettingsRepository(context: container.mainContext)
                .currentSettings()
            settings.proStatus = status
            try container.mainContext.save()
        } catch {
            // Persisting the cache is best-effort; the in-memory `current`
            // is the authoritative source for the running session.
        }
    }
}
