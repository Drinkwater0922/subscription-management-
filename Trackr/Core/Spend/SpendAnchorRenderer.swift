import Foundation

/// Renders a `SpendAnchor` into the localized conversion-line string the
/// Home hero displays: "≈ one PlayStation 5", "≈ 2 PlayStation 5s",
/// "≈ 一台 PS5", etc.
///
/// Two layers:
///
///   * `multiplier(annualSpendUSD:anchor:)` — pure ratio, rounded to a
///     readable integer where possible; falls back to one decimal place
///     for sub-1.0 ratios.
///   * `render(multiplier:anchor:locale:)` — turns the ratio into a
///     localized string with measure-word handling.
enum SpendAnchorRenderer {

    /// Rounded multiplier suitable for display.
    /// - `< 0.55`           → `0.5`  (rendered as "half a …")
    /// - `0.55 ..< 1.5`     → `1`
    /// - else               → rounded to nearest integer.
    static func multiplier(annualSpendUSD: Decimal, anchor: SpendAnchor) -> Double {
        guard anchor.priceUSD > 0 else { return 0 }
        let spend = NSDecimalNumber(decimal: annualSpendUSD).doubleValue
        let price = NSDecimalNumber(decimal: anchor.priceUSD).doubleValue
        let raw = spend / price
        if raw < 0.55 { return 0.5 }
        if raw < 1.5 { return 1 }
        return (raw).rounded()
    }

    /// "≈ 2 PlayStation 5s" / "≈ 一台 PS5" / "≈ half a PlayStation 5".
    static func render(annualSpendUSD: Decimal,
                       anchor: SpendAnchor,
                       locale: Locale = .current) -> String {
        let m = multiplier(annualSpendUSD: annualSpendUSD, anchor: anchor)
        let isChinese = locale.language.languageCode?.identifier == "zh"

        if isChinese {
            // Chinese: prefer integer counts. Half-anchor falls back to
            // "≈ 半 + measure-word" — keeps the rendered string short.
            if m == 0.5 {
                return "≈ 半\(anchor.labelZh)"
            }
            let count = Int(m)
            if count <= 1 {
                return "≈ 一\(anchor.labelZh)"
            }
            return "≈ \(count) \(anchor.labelZh)"
        }

        if m == 0.5 {
            // English half-anchor: "half a PS5" / "half a pair of AirPods".
            // The "a" article is grammatically wrong for "a AirPods" but
            // works because our anchor labels are noun phrases starting
            // with a consonant ("PlayStation 5", "pair of …").
            return "≈ half a \(anchor.labelEnSingular)"
        }
        let count = Int(m)
        if count <= 1 {
            // "one" reads warmer than "1" for the singular case.
            return "≈ one \(anchor.labelEnSingular)"
        }
        return "≈ \(count) \(anchor.labelEnPlural)"
    }
}
