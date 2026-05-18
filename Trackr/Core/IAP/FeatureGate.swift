import Foundation

/// Static map of features to the tier required to unlock them. No side effects,
/// no StoreKit dependency — every gated call site reads its `ProStatus` from
/// `ProEntitlement` / `UserSettings` and asks here.
enum FeatureGate {

    enum Feature {
        /// Unlimited subscriptions (free is capped at `freeSubscriptionLimit`).
        case unlimitedSubs
        /// Push notification fires whenever a `PriceChangeAlert` is generated.
        /// Free users still see the in-app banner; only Pro gets push.
        case pricePushNotifications
        /// Insights screen — totals + future trend charts.
        case insights
        /// CloudKit sync (M7 will gate the toggle on this).
        case iCloudSync
    }

    /// The hard cap on a free user's subscription count.
    static let freeSubscriptionLimit = 5

    static func isAllowed(_ feature: Feature, given status: ProStatus) -> Bool {
        switch status {
        case .free:
            return false
        case .proLifetime:
            return true
        }
    }

    static func canAddSubscription(currentCount: Int, proStatus: ProStatus) -> Bool {
        if isAllowed(.unlimitedSubs, given: proStatus) { return true }
        return currentCount < freeSubscriptionLimit
    }
}
