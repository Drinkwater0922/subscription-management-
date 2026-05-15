import SwiftUI

/// Medium WidgetKit widget showing up to 3 upcoming renewals as a list.
struct MediumRenewalWidgetView: View {

    let renewals: [UpcomingRenewal]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText("UPCOMING RENEWALS",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            if renewals.isEmpty {
                Spacer()
                PixelText("NO UPCOMING RENEWALS",
                          size: TrackrTypography.Scale.body,
                          color: TrackrColors.fg2,
                          tracking: 1.5)
                Spacer()
            } else {
                ForEach(renewals.prefix(3), id: \.id) { renewal in
                    row(renewal)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private func row(_ renewal: UpcomingRenewal) -> some View {
        HStack(spacing: 10) {
            PixelText("\(renewal.daysUntil)D",
                      size: TrackrTypography.Scale.value,
                      color: TrackrColors.accent,
                      tracking: 1)
                .frame(width: 36, alignment: .leading)
            PixelText(renewal.name.uppercased(),
                      size: TrackrTypography.Scale.body,
                      tracking: 1.5)
                .lineLimit(1)
            Spacer()
            PixelText(renewal.displayAmount,
                      size: TrackrTypography.Scale.body,
                      color: TrackrColors.fg2,
                      tracking: 1)
        }
    }
}
