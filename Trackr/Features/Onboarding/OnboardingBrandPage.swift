import SwiftUI

struct OnboardingBrandPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            HStack(spacing: 10) {
                Rectangle().fill(TrackrColors.accent).frame(width: 16, height: 16)
                PixelText("TRACKR",
                          size: TrackrTypography.Scale.hero,
                          tracking: 4)
            }
            PixelText(LocalizedStringKey("EVERY SUBSCRIPTION,\nNEVER A SURPRISE."),
                      size: TrackrTypography.Scale.title,
                      color: TrackrColors.fg2,
                      tracking: 2)
                .multilineTextAlignment(.leading)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(TrackrColors.bg)
    }
}

#Preview { OnboardingBrandPage().preferredColorScheme(.dark) }
