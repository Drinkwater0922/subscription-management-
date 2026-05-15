import SwiftUI

/// 56×56 accent-colored FAB with a "+" glyph in the pixel font.
/// Anchored bottom-trailing on screens that allow adding.
struct FloatingActionButton: View {
    /// Side length of the square button in points.
    private static let side: CGFloat = 56
    /// Glyph font size — sized to read clearly inside the 56pt square.
    private static let glyphSize: CGFloat = 32
    /// Shadow radius and offset of the accent glow.
    private static let shadowRadius: CGFloat = 12
    private static let shadowYOffset: CGFloat = 4
    /// Opacity of the accent-colored glow under the FAB.
    private static let shadowOpacity: Double = 0.4

    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            PixelText("+", size: Self.glyphSize, color: TrackrColors.onAccent, tracking: 0)
                .frame(width: Self.side, height: Self.side)
                .background(TrackrColors.accent)
                .shadow(color: TrackrColors.accent.opacity(Self.shadowOpacity),
                        radius: Self.shadowRadius,
                        y: Self.shadowYOffset)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        TrackrColors.bg.ignoresSafeArea()
        FloatingActionButton(action: { })
            .padding(24)
    }
}
