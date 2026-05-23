import Foundation

/// One "≈ a PlayStation 5" anchor used by the v1.1 Home hero conversion
/// line. The hero translates the user's annual subscription spend into
/// one of these to give the abstract dollar figure emotional weight.
///
/// Anchors are bundled (no remote catalog yet — design doc says that can
/// come later), playful in tone, and explicitly NOT guilt-y. "≈ a PS5 /
/// a trip" is fine; "≈ X months of groceries" is forbidden.
struct SpendAnchor: Equatable, Hashable {
    /// Stable identifier — useful for keying rotation state in SwiftUI.
    let id: String

    /// Rough sticker price in USD. The hero converts the user's annual
    /// spend into USD via the FX cache, then matches against this.
    let priceUSD: Decimal

    /// English singular label (e.g. "PlayStation 5"). Used when the
    /// multiplier is one or less than one.
    let labelEnSingular: String

    /// English plural label (e.g. "PlayStation 5s").
    let labelEnPlural: String

    /// Simplified-Chinese measure-word phrase. Includes the appropriate
    /// classifier so the rendered string reads naturally ("一台 PS5",
    /// "一趟周末旅行").
    let labelZh: String
}

/// Curated bundled list of anchors + selection logic for the Home hero.
///
/// Selection rule: rank by `abs(log(annualSpend / priceUSD))` and take up
/// to 4 closest. That favors anchors the user roughly equals or doubles —
/// "≈ 1 PS5" or "≈ 2 PS5s" both read; "≈ 0.001 of a vacation" does not.
/// If the user has zero spend (empty state), selection returns empty.
enum SpendAnchorCatalog {

    /// The bundled set. Spans ~$5 → ~$3000 so any plausible annual spend
    /// lands inside the useful range. Order is irrelevant — selection
    /// re-sorts.
    static let all: [SpendAnchor] = [
        SpendAnchor(id: "coffee",
                    priceUSD: 5,
                    labelEnSingular: "coffee",
                    labelEnPlural: "coffees",
                    labelZh: "杯咖啡"),
        SpendAnchor(id: "pizza",
                    priceUSD: 20,
                    labelEnSingular: "pizza",
                    labelEnPlural: "pizzas",
                    labelZh: "份披萨"),
        SpendAnchor(id: "book",
                    priceUSD: 30,
                    labelEnSingular: "new book",
                    labelEnPlural: "new books",
                    labelZh: "本新书"),
        SpendAnchor(id: "dinner",
                    priceUSD: 80,
                    labelEnSingular: "nice dinner",
                    labelEnPlural: "nice dinners",
                    labelZh: "顿大餐"),
        SpendAnchor(id: "sneakers",
                    priceUSD: 120,
                    labelEnSingular: "pair of sneakers",
                    labelEnPlural: "pairs of sneakers",
                    labelZh: "双跑鞋"),
        SpendAnchor(id: "airpods",
                    priceUSD: 250,
                    labelEnSingular: "pair of AirPods",
                    labelEnPlural: "pairs of AirPods",
                    labelZh: "副 AirPods"),
        SpendAnchor(id: "ps5",
                    priceUSD: 499,
                    labelEnSingular: "PlayStation 5",
                    labelEnPlural: "PlayStation 5s",
                    labelZh: "台 PS5"),
        SpendAnchor(id: "weekend_trip",
                    priceUSD: 800,
                    labelEnSingular: "weekend trip",
                    labelEnPlural: "weekend trips",
                    labelZh: "趟周末旅行"),
        SpendAnchor(id: "iphone",
                    priceUSD: 1199,
                    labelEnSingular: "new iPhone",
                    labelEnPlural: "new iPhones",
                    labelZh: "部新 iPhone"),
        SpendAnchor(id: "vacation",
                    priceUSD: 3000,
                    labelEnSingular: "two-week vacation",
                    labelEnPlural: "two-week vacations",
                    labelZh: "趟长假"),
    ]

    /// Up to `limit` anchors closest to `annualSpendUSD` by log-distance.
    /// Returns `[]` when spend is non-positive (empty / zero state).
    static func pick(annualSpendUSD: Decimal,
                     limit: Int = 4,
                     catalog: [SpendAnchor] = all) -> [SpendAnchor] {
        guard annualSpendUSD > 0, limit > 0 else { return [] }
        let spend = NSDecimalNumber(decimal: annualSpendUSD).doubleValue
        let ranked = catalog
            .map { anchor -> (SpendAnchor, Double) in
                let price = NSDecimalNumber(decimal: anchor.priceUSD).doubleValue
                let distance = abs(log(spend / price))
                return (anchor, distance)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { $0.0 }
        return Array(ranked)
    }
}
