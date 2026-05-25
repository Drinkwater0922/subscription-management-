import SwiftUI

/// The NEXT 30 DAYS DUE hero card at the top of the v1.2 Insights view.
/// Renders the upcoming-charges total in `displayCurrency` with a
/// "N CHARGES INCOMING" subtitle in accent green.
struct InsightsHero: View {

    let upcoming: UpcomingChargesCalculator.Result
    let displayCurrency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText("NEXT 30 DAYS DUE",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(AmountFormatter.format(upcoming.total,
                                              currency: displayCurrency),
                      size: TrackrTypography.Scale.hero,
                      tracking: 1)
            PixelText(chargesLabel,
                      size: TrackrTypography.Scale.caption,
                      color: chargesColor,
                      tracking: 1.5)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private var chargesLabel: String {
        switch upcoming.chargeCount {
        case 0: return "NO CHARGES IN THE NEXT 30 DAYS"
        case 1: return "1 CHARGE INCOMING"
        default: return "\(upcoming.chargeCount) CHARGES INCOMING"
        }
    }

    private var chargesColor: Color {
        upcoming.chargeCount == 0 ? TrackrColors.fg3 : TrackrColors.accent
    }
}
