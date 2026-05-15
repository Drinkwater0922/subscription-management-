import Foundation

/// Value-type snapshot of one upcoming renewal, with the strings pre-formatted
/// for widget rendering. Keeping the widget view layer free of formatters
/// keeps it deterministic across timeline snapshots.
struct UpcomingRenewal: Equatable {
    let id: UUID
    let name: String
    let displayAmount: String
    let daysUntil: Int
    let nextBillingDate: Date
}

/// Pure function for widget timeline construction. Returns the soonest `limit`
/// renewals strictly after `now` from the supplied subscriptions, skipping
/// inactive rows.
enum UpcomingRenewalsProvider {
    static func upcoming(
        subscriptions: [Subscription],
        now: Date,
        limit: Int,
        calendar: Calendar = .current
    ) -> [UpcomingRenewal] {
        subscriptions
            .filter { $0.isActive && $0.nextBillingDate > now }
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
            .prefix(limit)
            .map { sub in
                UpcomingRenewal(
                    id: sub.id,
                    name: sub.name,
                    displayAmount: AmountFormatter.format(sub.amount, currency: sub.currency),
                    daysUntil: daysBetween(now: now, then: sub.nextBillingDate, calendar: calendar),
                    nextBillingDate: sub.nextBillingDate
                )
            }
    }

    private static func daysBetween(now: Date, then: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.day], from: now, to: then)
        return comps.day ?? 0
    }
}
