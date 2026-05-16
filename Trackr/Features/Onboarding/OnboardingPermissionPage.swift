import SwiftUI

struct OnboardingPermissionPage: View {
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            PixelText(LocalizedStringKey("ONE MORE THING"),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(LocalizedStringKey("TURN ON NOTIFICATIONS\nSO PENNYLOOP CAN REMIND YOU"),
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            Text("We'll only ping you a few days before each renewal — never spam.")
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            VStack(spacing: 12) {
                TrackrButton(String(localized: "ENABLE NOTIFICATIONS"), action: onEnable)
                TrackrButton(String(localized: "MAYBE LATER"), variant: .outlined, action: onSkip)
            }
            Spacer().frame(height: 20)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(TrackrColors.bg)
    }
}

#Preview {
    OnboardingPermissionPage(onEnable: {}, onSkip: {})
        .preferredColorScheme(.dark)
}
