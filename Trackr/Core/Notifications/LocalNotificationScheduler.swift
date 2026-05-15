import Foundation
import UserNotifications

/// Owns the "cancel everything we scheduled, then re-add the desired set"
/// loop. Stateless across calls — every `refresh()` is a full replan, which
/// keeps the system honest at the cost of O(n) work on each save.
final class LocalNotificationScheduler {

    private let center: NotificationCenterProtocol
    private let calendar: Calendar

    init(center: NotificationCenterProtocol, calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    func refresh(
        subscriptions: [Subscription],
        settings: UserSettings,
        now: Date = .now
    ) async throws {
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // Cancel our own pending identifiers.
        let pending = await center.pendingNotificationRequests()
        let trackrIds = pending.map(\.identifier).filter(NotificationIdentifier.isTrackrIdentifier)
        if !trackrIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: trackrIds)
        }

        // Build per-(sub, leadDay) requests, aggregate per leadDay, add.
        for leadDay in settings.leadDays {
            let perSub = subscriptions.compactMap { sub in
                NotificationRequestBuilder.build(
                    subscription: sub,
                    leadDay: leadDay,
                    notifyHour: settings.notifyHour,
                    calendar: calendar,
                    now: now
                )
            }
            let final = SameDayAggregator.aggregate(perSub, leadDay: leadDay, calendar: calendar)
            for request in final {
                try await center.add(request)
            }
        }
    }
}
