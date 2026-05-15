import SwiftUI

/// Horizontal 1pt dashed separator. Primary section divider per the design system.
struct DashedDivider: View {
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
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
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
