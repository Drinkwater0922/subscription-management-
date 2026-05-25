import SwiftUI

/// The "TOP 5 BY SUSPECT" block on the redesigned Insights view (v1.2).
///
/// Hands every row tap to `onSelect`. The Insights container is itself a
/// sheet from `HomeView`, so navigating to Detail goes through the shared
/// `AppDeepLinkRouter` (request open → dismiss Insights → HomeView's
/// `.sheet(item:)` opens Detail) rather than stacking a second sheet.
struct SuspectRankingSection: View {

    let ranked: [SuspectRanker.Ranked]
    let displayCurrency: String
    let onSelect: (Subscription) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if ranked.isEmpty {
                PixelText("NO ACTIVE SUBSCRIPTIONS TO RANK",
                          size: TrackrTypography.Scale.body,
                          color: TrackrColors.fg3,
                          tracking: 1.5)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(ranked.enumerated()), id: \.offset) { idx, row in
                    Button { onSelect(row.subscription) } label: {
                        rowContent(row)
                    }
                    .buttonStyle(.plain)
                    if idx < ranked.count - 1 {
                        rowDivider
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var sectionHeader: some View {
        HStack {
            PixelText("TOP 5",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            Spacer()
            PixelText("BY SUSPECT",
                      size: TrackrTypography.Scale.caption,
                      color: TrackrColors.fg3,
                      tracking: 1.5)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(TrackrColors.border)
            .frame(height: 1)
            .padding(.horizontal, 20)
            .opacity(0.55)
    }

    private func rowContent(_ row: SuspectRanker.Ranked) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PixelText("\(row.rank)",
                      size: TrackrTypography.Scale.title,
                      color: TrackrColors.accent,
                      tracking: 1)
                .frame(minWidth: 22, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                PixelText(row.subscription.name.uppercased(),
                          size: TrackrTypography.Scale.value,
                          tracking: 1.5)

                PixelText(costLine(row),
                          size: TrackrTypography.Scale.caption,
                          color: TrackrColors.fg2,
                          tracking: 1.5)

                if !row.tags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(row.tags.enumerated()), id: \.offset) { _, tag in
                            tagChip(tag)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func costLine(_ row: SuspectRanker.Ranked) -> String {
        let monthly = AmountFormatter.format(row.monthlyContribution,
                                              currency: displayCurrency)
        let perDay = AmountFormatter.format(row.monthlyContribution / 30,
                                             currency: displayCurrency)
        return "\(monthly)/MO · \(perDay)/DAY"
    }

    @ViewBuilder
    private func tagChip(_ tag: SuspectRanker.Tag) -> some View {
        let (text, color) = tagStyle(tag)
        PixelText(text,
                  size: TrackrTypography.Scale.caption,
                  color: color,
                  tracking: 1.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Rectangle().stroke(color, lineWidth: 1))
    }

    private func tagStyle(_ tag: SuspectRanker.Tag) -> (text: String, color: Color) {
        switch tag {
        case .expensive:
            return ("EXPENSIVE", TrackrColors.accent)
        case .renewsIn(let days):
            return ("RENEWS IN \(days) DAYS", TrackrColors.warn)
        case .notTouchedIn(let days):
            return ("NOT TOUCHED IN \(days) DAYS", TrackrColors.fg2)
        }
    }
}
