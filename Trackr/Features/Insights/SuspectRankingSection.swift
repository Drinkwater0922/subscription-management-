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
                PixelText(InsightsCopy.emptyRanking(),
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(row))
                    .accessibilityAddTraits(.isButton)
                    if idx < ranked.count - 1 {
                        rowDivider
                    }
                }
            }
        }
    }

    /// Build a single, well-formed VoiceOver label that announces the
    /// rank, name, cost-per-month, and every visible tag. Per-element a11y
    /// is collapsed via `.ignore` above so the row reads as one chunk.
    private func accessibilityLabel(_ row: SuspectRanker.Ranked) -> String {
        var parts: [String] = []
        parts.append("Rank \(row.rank)")
        parts.append(row.subscription.name)
        let monthly = AmountFormatter.format(row.monthlyContribution,
                                              currency: displayCurrency)
        parts.append("\(monthly) per month")
        for tag in row.tags {
            parts.append(InsightsCopy.tag(tag, lang: .en))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Subviews

    private var sectionHeader: some View {
        HStack {
            PixelText(InsightsCopy.sectionLabel(.topFiveTitle),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            Spacer()
            PixelText(InsightsCopy.sectionLabel(.topFiveSubtitle),
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
        let text = InsightsCopy.tag(tag)
        switch tag {
        case .expensive:        return (text, TrackrColors.accent)
        case .renewsIn:         return (text, TrackrColors.warn)
        case .notTouchedIn:     return (text, TrackrColors.fg2)
        }
    }
}
