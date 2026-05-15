import SwiftUI

/// Primary action button. Two visual variants: filled (accent background) and outlined (border only).
struct TrackrButton: View {
    /// Minimum touch-target height per Apple HIG.
    private static let minTouchTarget: CGFloat = 44
    /// Vertical padding inside the touch target. Combined with the label, total height settles at `minTouchTarget`.
    private static let verticalPadding: CGFloat = 12
    /// Tracking (letter spacing) for the pixel-font label.
    private static let labelTracking: CGFloat = 2

    enum Variant {
        case filled
        case outlined
    }

    let label: String
    let variant: Variant
    let action: () -> Void

    init(_ label: String, variant: Variant = .filled, action: @escaping () -> Void) {
        self.label = label
        self.variant = variant
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            PixelText(
                label,
                size: TrackrTypography.Scale.body,
                color: variant == .filled ? TrackrColors.onAccent : TrackrColors.fg,
                tracking: Self.labelTracking
            )
            .frame(maxWidth: .infinity, minHeight: Self.minTouchTarget)
            .padding(.vertical, Self.verticalPadding)
            .background(background)
            .overlay(border)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        if variant == .filled {
            TrackrColors.accent
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var border: some View {
        if variant == .outlined {
            Rectangle().stroke(TrackrColors.border, lineWidth: 1)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TrackrButton("CONTINUE") { }
        TrackrButton("RESTORE PURCHASE", variant: .outlined) { }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(TrackrColors.bg)
}
