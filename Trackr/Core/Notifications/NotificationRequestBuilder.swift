import Foundation
import UserNotifications

/// Pure builder: takes one (subscription, leadDay, notifyHour, calendar) tuple
/// and returns the matching `UNNotificationRequest`. Returns `nil` when the
/// subscription is inactive or the computed fire date already passed.
enum NotificationRequestBuilder {

    /// `now` is injectable for tests; production callers leave it at `.now`.
    static func build(
        subscription: Subscription,
        leadDay: Int,
        notifyHour: Int,
        calendar: Calendar,
        now: Date = .now
    ) -> UNNotificationRequest? {
        guard subscription.isActive else { return nil }

        guard let dayMinusLead = calendar.date(
            byAdding: .day,
            value: -leadDay,
            to: subscription.nextBillingDate
        ) else { return nil }

        var comps = calendar.dateComponents([.year, .month, .day], from: dayMinusLead)
        comps.hour = notifyHour
        comps.minute = 0
        comps.second = 0

        guard let fire = calendar.date(from: comps), fire > now else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "\(subscription.name) renews soon"
        content.body = bodyText(for: subscription, leadDay: leadDay)
        content.userInfo = ["subscriptionID": subscription.id.uuidString]
        content.sound = .default

        let triggerComps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fire
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)

        return UNNotificationRequest(
            identifier: NotificationIdentifier.perSubscription(
                subscriptionID: subscription.id,
                leadDay: leadDay
            ),
            content: content,
            trigger: trigger
        )
    }

    private static func bodyText(for sub: Subscription, leadDay: Int) -> String {
        let amount = AmountFormatter.format(sub.amount, currency: sub.currency)
        let when = leadDay == 1 ? "tomorrow" : "in \(leadDay) days"
        return "\(sub.name) renews \(when) · \(amount)"
    }
}
