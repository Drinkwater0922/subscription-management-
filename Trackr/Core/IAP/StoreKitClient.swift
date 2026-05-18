import Foundation

/// Product display info pulled from the App Store (or local `.storekit` config).
/// `priceDisplay` is the already-formatted localized price string ("$7.99",
/// "¥58.00"); we never re-format it.
struct ProProductDisplay: Equatable {
    let productID: String
    let priceDisplay: String
}

/// Narrow seam over StoreKit 2. The whole IAP stack only touches the methods
/// declared here, so tests can inject `FakeStoreKitClient` and production
/// wires `SystemStoreKitClient`.
protocol StoreKitClient: AnyObject {

    /// Resolves the user's current Pro tier from their active entitlements.
    /// Returns `.free` when nothing is active.
    func currentEntitlement() async -> ProStatus

    /// Initiates a purchase. On success the resolved tier is returned. The
    /// caller is responsible for updating UI state and `UserSettings.proStatus`.
    func purchase(productID: String) async throws -> ProStatus

    /// Long-running stream of `ProStatus` values, one emitted for every
    /// `Transaction.updates` event. Used by `ProEntitlement` for live updates.
    func transactionUpdates() -> AsyncStream<ProStatus>

    /// Display info for the Pro product. Reads from the App Store / local
    /// `.storekit` config. Returns an empty array if the product can't be loaded.
    func availableProducts() async -> [ProProductDisplay]
}

/// Product ID for the single Pro tier — kept here so `FeatureGate`, `PaywallView`,
/// and the StoreKit config all share one source of truth.
enum ProProductID {
    static let lifetime = "com.jingxue.pennyloop.pro.lifetime"
}
