import Foundation
import Observation

/// One-shot mailbox for "show the paywall". Gated call sites call `present(reason:)`;
/// `HomeView` watches `isShowing` and presents `PaywallView`.
@Observable
@MainActor
final class PaywallTriggerCoordinator {

    enum Reason: Equatable {
        case subscriptionLimit
        case insightsLocked
        case pushNotificationsLocked
        case iCloudSyncLocked
        case manual    // user tapped "Upgrade" without a gate trip
    }

    private(set) var isShowing = false
    private(set) var reason: Reason?

    func present(reason: Reason) {
        self.reason = reason
        self.isShowing = true
    }

    func dismiss() {
        isShowing = false
        reason = nil
    }
}
