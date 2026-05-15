import Foundation
import SwiftData
import WidgetKit

/// One snapshot the WidgetKit timeline machinery hands to the view.
struct RenewalEntry: TimelineEntry {
    let date: Date
    let renewals: [UpcomingRenewal]
}

/// Reads the shared SwiftData store, computes the upcoming renewals, and emits
/// one entry per hour for the next 24 hours. The widget refresh budget on iOS
/// is tight; hourly updates are well within it.
struct RenewalTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> RenewalEntry {
        RenewalEntry(date: .now, renewals: Self.previewRenewals)
    }

    func getSnapshot(in context: Context, completion: @escaping (RenewalEntry) -> Void) {
        if context.isPreview {
            completion(RenewalEntry(date: .now, renewals: Self.previewRenewals))
        } else {
            completion(RenewalEntry(date: .now, renewals: loadRenewals(now: .now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RenewalEntry>) -> Void) {
        var entries: [RenewalEntry] = []
        let calendar = Calendar.current
        let now = Date.now
        for hour in 0..<24 {
            let date = calendar.date(byAdding: .hour, value: hour, to: now) ?? now
            entries.append(RenewalEntry(date: date, renewals: loadRenewals(now: date)))
        }
        let nextRefresh = calendar.date(byAdding: .hour, value: 24, to: now) ?? .distantFuture
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    // MARK: - private

    private func loadRenewals(now: Date) -> [UpcomingRenewal] {
        guard let container = try? ModelContainerConfig.makeAppContainer(syncMode: .localOnly) else {
            return []
        }
        let context = ModelContext(container)
        let subs = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        return UpcomingRenewalsProvider.upcoming(
            subscriptions: subs,
            now: now,
            limit: 3
        )
    }

    private static let previewRenewals: [UpcomingRenewal] = [
        UpcomingRenewal(id: UUID(), name: "Netflix",
                        displayAmount: "$15.49", daysUntil: 3,
                        nextBillingDate: .distantFuture),
        UpcomingRenewal(id: UUID(), name: "Spotify",
                        displayAmount: "$10.99", daysUntil: 7,
                        nextBillingDate: .distantFuture),
        UpcomingRenewal(id: UUID(), name: "iCloud",
                        displayAmount: "$0.99",  daysUntil: 12,
                        nextBillingDate: .distantFuture),
    ]
}
