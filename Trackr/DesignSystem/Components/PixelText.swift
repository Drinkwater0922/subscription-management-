import SwiftUI

/// Renders text in the VT323 pixel font with a default 1.5pt tracking.
/// Use for all-caps labels, numeric values, and section headers.
struct PixelText: View {
    let text: String
    let size: CGFloat
    let color: Color
    let tracking: CGFloat

    init(
        _ text: String,
        size: CGFloat = TrackrTypography.Scale.body,
        color: Color = TrackrColors.fg,
        tracking: CGFloat = 1.5
    ) {
        self.text = text
        self.size = size
        self.color = color
        self.tracking = tracking
    }

    var body: some View {
        Text(text)
            .font(TrackrTypography.pixel(size: size))
            .foregroundStyle(color)
            .tracking(tracking)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        PixelText("TRACKR", size: TrackrTypography.Scale.title, tracking: 3)
        PixelText("MONTHLY · USD", size: TrackrTypography.Scale.sectionLabel, color: TrackrColors.fg2, tracking: 2)
        PixelText("$147.92", size: TrackrTypography.Scale.hero, tracking: 1)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(TrackrColors.bg)
}
