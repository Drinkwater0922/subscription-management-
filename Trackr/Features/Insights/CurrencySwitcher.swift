import SwiftUI

/// Three-pill display-currency switcher on the v1.2 Insights view.
/// Persists to `UserSettings.defaultCurrency` (Open Question 5 resolved).
struct CurrencySwitcher: View {

    let current: String
    let onSelect: (String) -> Void

    private let options: [(code: String, symbol: String)] = [
        ("USD", "$"), ("CNY", "¥"), ("EUR", "€"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.code) { option in
                pill(code: option.code, symbol: option.symbol)
            }
        }
        .padding(.horizontal, 20)
    }

    private func pill(code: String, symbol: String) -> some View {
        let isActive = current.uppercased() == code
        let color = isActive ? TrackrColors.accent : TrackrColors.fg2
        let border = isActive ? TrackrColors.accent : TrackrColors.border
        return Button { onSelect(code) } label: {
            PixelText("\(code) \(symbol)",
                      size: TrackrTypography.Scale.body,
                      color: color,
                      tracking: 2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    isActive
                        ? TrackrColors.accent.opacity(0.06)
                        : Color.clear
                )
                .overlay(Rectangle().stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
