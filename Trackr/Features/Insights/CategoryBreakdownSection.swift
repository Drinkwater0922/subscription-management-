import SwiftUI

/// "BY CATEGORY" horizontal-fill-bar block on the v1.2 Insights view.
/// Caller is responsible for the `rows.count >= 2` threshold (per PRD,
/// single-category users get no breakdown).
struct CategoryBreakdownSection: View {

    let rows: [CategoryBreakdown.Row]
    let displayCurrency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            VStack(spacing: 10) {
                ForEach(rows, id: \.category) { row in
                    categoryRow(row)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var sectionHeader: some View {
        HStack {
            PixelText(InsightsCopy.sectionLabel(.byCategoryTitle),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            Spacer()
            PixelText(InsightsCopy.sectionLabel(.byCategorySubtitle),
                      size: TrackrTypography.Scale.caption,
                      color: TrackrColors.fg3,
                      tracking: 1.5)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func categoryRow(_ row: CategoryBreakdown.Row) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                PixelText(row.category.displayName.uppercased(),
                          size: TrackrTypography.Scale.body,
                          tracking: 1.5)
                Spacer()
                PixelText(rowSummary(row),
                          size: TrackrTypography.Scale.caption,
                          color: TrackrColors.fg2,
                          tracking: 1)
            }
            fillBar(percentage: row.percentage)
        }
    }

    private func rowSummary(_ row: CategoryBreakdown.Row) -> String {
        let amt = AmountFormatter.format(row.monthlyAmount,
                                          currency: displayCurrency)
        let pct = Int(row.percentage.rounded())
        return "\(amt) · \(pct)%"
    }

    /// 6-px-tall track + accent fill. Width-clamped to [0, container].
    private func fillBar(percentage: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(TrackrColors.bg3)
                Rectangle().fill(TrackrColors.accent)
                    .frame(width: max(0, min(geo.size.width,
                                              geo.size.width * percentage / 100)))
            }
        }
        .frame(height: 6)
    }
}
