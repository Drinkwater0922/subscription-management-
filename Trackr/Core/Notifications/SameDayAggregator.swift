import Foundation
import UserNotifications

/// Collapses multiple per-subscription requests that fire on the same calendar
/// day + hour into a single aggregate request. Single-item groups pass through
/// unchanged.
enum SameDayAggregator {

    static func aggregate(
        _ requests: [UNNotificationRequest],
        leadDay: Int,
        calendar: Calendar
    ) -> [UNNotificationRequest] {

        let buckets = Dictionary(grouping: requests, by: dayHourKey)

        return buckets.flatMap { (_, group) -> [UNNotificationRequest] in
            guard group.count >= 2 else { return group }
            return [collapse(group, leadDay: leadDay, calendar: calendar)]
        }
    }

    // MARK: - private

    private static func dayHourKey(for request: UNNotificationRequest) -> String {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return request.identifier
        }
        let c = trigger.dateComponents
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)T\(c.hour ?? 0)"
    }

    private static func collapse(
        _ group: [UNNotificationRequest],
        leadDay: Int,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let trigger = group[0].trigger as! UNCalendarNotificationTrigger
        let dayString = dayString(from: trigger)

        let content = UNMutableNotificationContent()
        content.title = "\(group.count) subscriptions renew soon"
        let when = leadDay == 1 ? "tomorrow" : "in \(leadDay) days"
        content.body = "\(group.count) subscriptions renew \(when)"
        content.userInfo = ["aggregateDay": dayString,
                            "leadDay": leadDay]
        content.sound = .default

        let newTrigger = UNCalendarNotificationTrigger(
            dateMatching: trigger.dateComponents,
            repeats: false
        )

        var comps = trigger.dateComponents
        comps.timeZone = calendar.timeZone
        let anchor = calendar.date(from: comps) ?? .distantFuture

        return UNNotificationRequest(
            identifier: NotificationIdentifier.aggregate(fireDay: anchor, leadDay: leadDay),
            content: content,
            trigger: newTrigger
        )
    }

    private static func dayString(from trigger: UNCalendarNotificationTrigger) -> String {
        let c = trigger.dateComponents
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
