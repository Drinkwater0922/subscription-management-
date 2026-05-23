import SwiftUI

/// Renders a subscription's price-history timeline in the v1.1 Detail
/// page. Reads `PriceHistoryFormatter.Row`s and renders each with a
/// color-coded delta:
///
///   * `.decrease` → lime  (`TrackrColors.accent`)
///   * `.increase` → warn  (`TrackrColors.warn`)
///   * `.unchanged` → muted (`TrackrColors.fg2`)
///   * `.currencyChanged` → muted with "→" instead of ↑/↓
///
/// The caller is responsible for deciding *whether* to render the list
/// (`PriceHistoryFormatter.hasChanges`) — this view assumes its input is
/// meaningful and just lays the rows out.
struct PriceHistoryListView: View {

    let rows: [PriceHistoryFormatter.Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText("PRICE HISTORY",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    rowView(row)
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: PriceHistoryFormatter.Row) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            PixelText(Self.dateFormatter.string(from: row.recordedAt),
                      size: TrackrTypography.Scale.caption,
                      color: TrackrColors.fg2,
                      tracking: 1)
                .frame(width: 90, alignment: .leading)
            arrowAndDelta(row)
                .frame(width: 80, alignment: .leading)
            Spacer()
            PixelText(AmountFormatter.format(row.amount, currency: row.currency),
                      size: TrackrTypography.Scale.value,
                      color: TrackrColors.fg,
                      tracking: 1)
        }
    }

    @ViewBuilder
    private func arrowAndDelta(_ row: PriceHistoryFormatter.Row) -> some View {
        switch row.direction {
        case .increase:
            HStack(spacing: 4) {
                PixelText("↑",
                          size: TrackrTypography.Scale.caption,
                          color: TrackrColors.warn,
                          tracking: 0)
                if let delta = row.delta {
                    PixelText(AmountFormatter.format(abs(delta), currency: row.currency),
                              size: TrackrTypography.Scale.caption,
                              color: TrackrColors.warn,
                              tracking: 1)
                }
            }
        case .decrease:
            HStack(spacing: 4) {
                PixelText("↓",
                          size: TrackrTypography.Scale.caption,
                          color: TrackrColors.accent,
                          tracking: 0)
                if let delta = row.delta {
                    PixelText(AmountFormatter.format(abs(delta), currency: row.currency),
                              size: TrackrTypography.Scale.caption,
                              color: TrackrColors.accent,
                              tracking: 1)
                }
            }
        case .currencyChanged:
            PixelText("→ \(row.currency)",
                      size: TrackrTypography.Scale.caption,
                      color: TrackrColors.fg2,
                      tracking: 1)
        case .unchanged:
            // No arrow on the oldest row — just leaves the slot empty so
            // the amount column stays visually aligned.
            Color.clear.frame(height: 1)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
