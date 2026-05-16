import SwiftUI

/// 3-step instructional sheet that walks the user through:
///   1. Open iOS Subscriptions
///   2. Screenshot the row they want to track
///   3. Return to the app and use IMPORT FROM PHOTO
struct AppleSubscriptionsImportSheet: View {

    let onOpenAppleSubscriptions: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().background(TrackrColors.border)
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        PixelText(LocalizedStringKey("IMPORT YOUR APPLE SUBS"),
                                  size: TrackrTypography.Scale.title,
                                  tracking: 2)
                        Text(LocalizedStringKey("Apple doesn't let apps read your subscription list. Use the three-step trick below — it takes about 30 seconds per sub."))
                            .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                            .foregroundStyle(TrackrColors.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                        step(index: 1,
                             key: LocalizedStringKey("TAP THE BUTTON BELOW. IOS WILL OPEN YOUR SUBSCRIPTIONS LIST."))
                        step(index: 2,
                             key: LocalizedStringKey("TAKE A SCREENSHOT OF EACH SUB YOU WANT TO TRACK (SIDE + VOLUME UP)."))
                        step(index: 3,
                             key: LocalizedStringKey("COME BACK HERE, OPEN ADD SUB, AND TAP IMPORT FROM PHOTO."))
                        TrackrButton(String(localized: "OPEN APPLE SUBSCRIPTIONS"),
                                     action: onOpenAppleSubscriptions)
                    }
                    .padding(20)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(String(localized: "CLOSE"), action: onDismiss)
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.accent)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(20)
    }

    @ViewBuilder
    private func step(index: Int, key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PixelText("\(index).",
                      size: TrackrTypography.Scale.value,
                      color: TrackrColors.accent,
                      tracking: 0)
                .frame(width: 24, alignment: .leading)
            PixelText(key,
                      size: TrackrTypography.Scale.body,
                      tracking: 1.5)
        }
    }
}

#Preview {
    AppleSubscriptionsImportSheet(onOpenAppleSubscriptions: {}, onDismiss: {})
        .preferredColorScheme(.dark)
}
