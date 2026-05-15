import SwiftUI

/// Horizontal 1pt dashed separator. Primary section divider per the design system.
struct DashedDivider: View {
    /// Dash and gap length in points. Equal values produce a 50% duty-cycle pattern.
    private static let dashPattern: [CGFloat] = [4, 4]

    let color: Color

    init(color: Color = TrackrColors.border) {
        self.color = color
    }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 1)
            .overlay(
                GeometryReader { geo in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0.5))
                        path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
                    }
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 1, dash: Self.dashPattern)
                    )
                }
            )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        PixelText("ABOVE", size: TrackrTypography.Scale.sectionLabel, color: TrackrColors.fg2)
        DashedDivider()
        PixelText("BELOW", size: TrackrTypography.Scale.sectionLabel, color: TrackrColors.fg2)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(TrackrColors.bg)
}
