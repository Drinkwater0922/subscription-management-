import WidgetKit
import SwiftUI

@main
struct TrackrWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpcomingRenewalsWidget()
    }
}

struct UpcomingRenewalsWidget: Widget {
    let kind: String = "UpcomingRenewalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RenewalTimelineProvider()) { entry in
            UpcomingRenewalsWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming Renewals")
        .description("See your next subscription renewals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UpcomingRenewalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RenewalEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallRenewalWidgetView(renewal: entry.renewals.first)
        case .systemMedium:
            MediumRenewalWidgetView(renewals: entry.renewals)
        default:
            SmallRenewalWidgetView(renewal: entry.renewals.first)
        }
    }
}
