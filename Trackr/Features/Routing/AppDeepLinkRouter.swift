import Foundation
import Observation

/// One-shot mailbox for "open this subscription's Detail screen". The notification
/// delegate writes the target UUID here; `HomeView` reads it and presents Detail.
@Observable
@MainActor
final class AppDeepLinkRouter {
    private(set) var pendingSubscriptionID: UUID?

    func requestOpen(subscriptionID: UUID) {
        pendingSubscriptionID = subscriptionID
    }

    /// Returns and clears the pending target. Call site is responsible for
    /// actually opening the screen.
    func consume() -> UUID? {
        defer { pendingSubscriptionID = nil }
        return pendingSubscriptionID
    }
}

import SwiftUI

private struct NotificationCoordinatorKey: EnvironmentKey {
    static let defaultValue: NotificationCoordinator? = nil
}

extension EnvironmentValues {
    var notificationCoordinator: NotificationCoordinator? {
        get { self[NotificationCoordinatorKey.self] }
        set { self[NotificationCoordinatorKey.self] = newValue }
    }
}

private struct PresetSyncKey: EnvironmentKey {
    static let defaultValue: PresetSync? = nil
}

extension EnvironmentValues {
    var presetSync: PresetSync? {
        get { self[PresetSyncKey.self] }
        set { self[PresetSyncKey.self] = newValue }
    }
}

private struct ProEntitlementKey: EnvironmentKey {
    static let defaultValue: ProEntitlement? = nil
}

extension EnvironmentValues {
    var proEntitlement: ProEntitlement? {
        get { self[ProEntitlementKey.self] }
        set { self[ProEntitlementKey.self] = newValue }
    }
}

private struct PaywallTriggerCoordinatorKey: EnvironmentKey {
    static let defaultValue: PaywallTriggerCoordinator? = nil
}

extension EnvironmentValues {
    var paywallTrigger: PaywallTriggerCoordinator? {
        get { self[PaywallTriggerCoordinatorKey.self] }
        set { self[PaywallTriggerCoordinatorKey.self] = newValue }
    }
}

private struct HapticsKey: EnvironmentKey {
    static let defaultValue: Haptics? = nil
}

extension EnvironmentValues {
    var haptics: Haptics? {
        get { self[HapticsKey.self] }
        set { self[HapticsKey.self] = newValue }
    }
}
