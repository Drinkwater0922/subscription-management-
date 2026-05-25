import SwiftUI

/// "BY CURRENCY" block on the v1.2 Insights view. Each row's main amount
/// stays in the subscription's ORIGINAL currency (so users with foreign
/// subs see real exposure); the right column shows an annual
/// approximation in the user's display currency, or em-dash when the
/// FX cache can't convert.
///
/// Caller is responsible for the `rows.count >= 2` threshold per PRD.
struct CurrencyBreakdownSection: View {

    let rows: [CurrencyBreakdown.Row]
    let displayCurrency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            VStack(spacing: 0) {
                ForEach(rows, id: \.currency) { row in
                    currencyRow(row)
                }
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            PixelText(InsightsCopy.sectionLabel(.byCurrencyTitle),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            Spacer()
            PixelText(InsightsCopy.sectionLabel(.byCurrencySubtitle),
                      size: TrackrTypography.Scale.caption,
                      color: TrackrColors.fg3,
                      tracking: 1.5)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private func currencyRow(_ row: CurrencyBreakdown.Row) -> some View {
        HStack(spacing: 12) {
            PixelText(row.currency,
                      size: TrackrTypography.Scale.value,
                      tracking: 2)
                .frame(minWidth: 48, alignment: .leading)
            PixelText(monthlyText(row),
                      size: TrackrTypography.Scale.caption,
                      color: TrackrColors.fg2,
                      tracking: 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
            PixelText(annualText(row),
                      size: TrackrTypography.Scale.caption,
                      color: TrackrColors.fg3,
                      tracking: 1)
                .frame(minWidth: 110, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
    }

    private func monthlyText(_ row: CurrencyBreakdown.Row) -> String {
        // Main amount stays in the row's own currency.
        let amt = AmountFormatter.format(row.monthlyAmount,
                                          currency: row.currency)
        return "\(amt)/MO"
    }

    private func annualText(_ row: CurrencyBreakdown.Row) -> String {
        guard let annual = row.annualInDisplayCurrency else { return "—" }
        return "≈ \(AmountFormatter.format(annual, currency: displayCurrency))/YR"
    }
}
