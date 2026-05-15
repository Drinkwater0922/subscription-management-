import Foundation
import SwiftData

/// Single seam features call after a write to keep notifications in sync.
/// Fetches the latest subscription list + user settings, then asks the
/// scheduler to refresh.
@MainActor
final class NotificationCoordinator {

    private let scheduler: LocalNotificationScheduler
    private let container: ModelContainer

    init(scheduler: LocalNotificationScheduler, container: ModelContainer) {
        self.scheduler = scheduler
        self.container = container
    }

    func refresh(now: Date = .now) async throws {
        let context = container.mainContext
        let subs = try context.fetch(FetchDescriptor<Subscription>())
        let settings = try SettingsRepository(context: context).currentSettings()
        try await scheduler.refresh(subscriptions: subs, settings: settings, now: now)
    }
}
