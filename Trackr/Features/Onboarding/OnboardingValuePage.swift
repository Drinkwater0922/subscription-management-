import SwiftUI

struct OnboardingValuePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            PixelText(LocalizedStringKey("WHY TRACKR"),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(LocalizedStringKey("ONE PLACE\nFOR ALL YOUR SUBS"),
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            VStack(alignment: .leading, spacing: 16) {
                bullet(LocalizedStringKey("SEE YOUR MONTHLY TOTAL AT A GLANCE"))
                bullet(LocalizedStringKey("GET NOTIFIED BEFORE EVERY RENEWAL"))
                bullet(LocalizedStringKey("CATCH PRICE CHANGES THE MOMENT THEY HAPPEN"))
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(TrackrColors.bg)
    }

    private func bullet(_ key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PixelText("◆",
                      size: TrackrTypography.Scale.body,
                      color: TrackrColors.accent,
                      tracking: 0)
            PixelText(key,
                      size: TrackrTypography.Scale.body,
                      tracking: 1.5)
        }
    }
}

#Preview { OnboardingValuePage().preferredColorScheme(.dark) }
