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
