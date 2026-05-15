import WidgetKit
import SwiftUI

@main
struct TrackrWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpcomingRenewalsWidget()
    }
}

/// Placeholder until Task 8 fleshes out the timeline provider + body.
struct UpcomingRenewalsWidget: Widget {
    let kind: String = "UpcomingRenewalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            Text("Trackr")
        }
        .configurationDisplayName("Upcoming Renewals")
        .description("See your next subscription renewals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Placeholder until Task 8.
struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now)
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: .now)], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}
