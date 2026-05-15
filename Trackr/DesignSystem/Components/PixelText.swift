import SwiftUI

/// Renders text in the VT323 pixel font with a default 1.5pt tracking.
/// Use for all-caps labels, numeric values, and section headers.
struct PixelText: View {
    private enum Source {
        case raw(String)
        case localized(LocalizedStringKey)
    }
    private let source: Source
    let size: CGFloat
    let color: Color
    let tracking: CGFloat

    init(
        _ text: String,
        size: CGFloat = TrackrTypography.Scale.body,
        color: Color = TrackrColors.fg,
        tracking: CGFloat = 1.5
    ) {
        self.source = .raw(text)
        self.size = size
        self.color = color
        self.tracking = tracking
    }

    init(
        _ key: LocalizedStringKey,
        size: CGFloat = TrackrTypography.Scale.body,
        color: Color = TrackrColors.fg,
        tracking: CGFloat = 1.5
    ) {
        self.source = .localized(key)
        self.size = size
        self.color = color
        self.tracking = tracking
    }

    var body: some View {
        textView
            .font(TrackrTypography.pixel(size: size))
            .foregroundStyle(color)
            .tracking(tracking)
    }

    @ViewBuilder
    private var textView: some View {
        switch source {
        case .raw(let s):
            Text(verbatim: s)
        case .localized(let key):
            Text(key)
        }
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
