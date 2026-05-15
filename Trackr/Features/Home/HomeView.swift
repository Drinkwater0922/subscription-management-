import SwiftUI

/// Home screen. M1: placeholder shell that renders the design-system pieces.
/// Real subscription data binding lands in M3.
struct HomeView: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TrackrColors.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer().frame(height: 24)
                heroAmount
                Spacer().frame(height: 20)
                DashedDivider()
                Spacer().frame(height: 14)
                emptyState
                Spacer()
            }
            .padding(.horizontal, 20)

            FloatingActionButton(action: { /* M3 wires this up */ })
                .padding(24)
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(TrackrColors.accent)
                    .frame(width: 8, height: 8)
                PixelText("TRACKR", size: TrackrTypography.Scale.title, tracking: 3)
            }
            Spacer()
            HStack(spacing: 14) {
                Color.clear
                    .frame(width: 32, height: 32)
                    .overlay(PixelText("≡", size: 14, color: TrackrColors.fg2, tracking: 0))
                    .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
                Color.clear
                    .frame(width: 32, height: 32)
                    .overlay(PixelText("⚙", size: 14, color: TrackrColors.fg2, tracking: 0))
                    .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
            }
        }
    }

    private var heroAmount: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText("MONTHLY · USD",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                PixelText("$",
                          size: TrackrTypography.Scale.largeNumber,
                          color: TrackrColors.fg2,
                          tracking: 1)
                PixelText("0",
                          size: TrackrTypography.Scale.hero,
                          color: TrackrColors.fg,
                          tracking: 1)
                PixelText(".00",
                          size: TrackrTypography.Scale.largeNumber,
                          color: TrackrColors.fg2,
                          tracking: 1)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            PixelText("NO SUBS\nTRACKED",
                      size: TrackrTypography.Scale.title,
                      color: TrackrColors.fg3,
                      tracking: 3)
                .multilineTextAlignment(.center)
            Text("Tap + to add your first subscription")
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.caption))
                .foregroundStyle(TrackrColors.fg3)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview { HomeView() }
