import SwiftUI

/// Small WidgetKit widget showing the next upcoming renewal — name, days
/// countdown, amount. Pure rendering; the timeline provider supplies the data.
struct SmallRenewalWidgetView: View {

    let renewal: UpcomingRenewal?

    var body: some View {
        if let renewal {
            populated(renewal)
        } else {
            empty
        }
    }

    private func populated(_ renewal: UpcomingRenewal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText("NEXT",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(renewal.name.uppercased(),
                      size: TrackrTypography.Scale.title,
                      tracking: 1.5)
                .lineLimit(1)
            Spacer()
            PixelText("\(renewal.daysUntil) DAY\(renewal.daysUntil == 1 ? "" : "S")",
                      size: TrackrTypography.Scale.largeNumber,
                      color: TrackrColors.accent,
                      tracking: 1)
            PixelText(renewal.displayAmount,
                      size: TrackrTypography.Scale.value,
                      color: TrackrColors.fg2,
                      tracking: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            PixelText("TRACKR",
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            Spacer()
            PixelText("NO UPCOMING",
                      size: TrackrTypography.Scale.body,
                      color: TrackrColors.fg2, tracking: 1.5)
            PixelText("RENEWALS",
                      size: TrackrTypography.Scale.body,
                      color: TrackrColors.fg2, tracking: 1.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }
}
