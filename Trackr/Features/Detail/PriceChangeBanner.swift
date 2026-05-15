import SwiftUI

/// Inline price-change notification shown at the top of the Detail screen
/// when the displayed subscription has an unseen `PriceChangeAlert`.
struct PriceChangeBanner: View {

    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(TrackrColors.warn).frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                PixelText("PRICE CHANGE",
                          size: TrackrTypography.Scale.sectionLabel,
                          color: TrackrColors.warn,
                          tracking: 2)
                Text(message)
                    .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                    .foregroundStyle(TrackrColors.fg)
            }
            Spacer()
            Button(action: onDismiss) {
                PixelText("✕",
                          size: TrackrTypography.Scale.value,
                          color: TrackrColors.fg2,
                          tracking: 0)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .overlay(Rectangle().stroke(TrackrColors.warn.opacity(0.4), lineWidth: 1))
    }
}
