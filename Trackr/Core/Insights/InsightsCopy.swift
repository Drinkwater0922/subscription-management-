import Foundation

/// Bilingual copy helper for the v1.2 Insights view. Mirrors the
/// hand-rolled localization pattern of `RelativeRenewalText` — keeps the
/// strings pure-function and unit-testable without spinning up a locale
/// bundle, and avoids fighting Localizable.xcstrings for design-token
/// strings (pixel uppercase in English, natural Chinese in zh-Hans).
///
/// Falls back to English for any locale outside `zh-Hans` / `zh-Hant`.
enum InsightsCopy {

    /// Tiny locale enum so callers can pass a deterministic value in
    /// tests without constructing `Foundation.Locale`.
    enum Lang: Equatable {
        case en
        case zh

        static func from(_ locale: Foundation.Locale) -> Lang {
            locale.language.languageCode?.identifier == "zh" ? .zh : .en
        }
    }

    // MARK: - Hero

    /// "NEXT 30 DAYS DUE" / "未来 30 天扣款"
    static func heroTitle(lang: Lang = .from(.current)) -> String {
        switch lang {
        case .en: return "NEXT 30 DAYS DUE"
        case .zh: return "未来 30 天扣款"
        }
    }

    /// "NO CHARGES IN THE NEXT 30 DAYS" / "1 CHARGE INCOMING" / "N CHARGES INCOMING"
    /// Chinese: "未来 30 天无扣款" / "未来 30 天扣 1 次" / "未来 30 天扣 N 次"
    static func chargesSubtitle(count: Int, lang: Lang = .from(.current)) -> String {
        switch lang {
        case .en:
            switch count {
            case 0: return "NO CHARGES IN THE NEXT 30 DAYS"
            case 1: return "1 CHARGE INCOMING"
            default: return "\(count) CHARGES INCOMING"
            }
        case .zh:
            switch count {
            case 0: return "未来 30 天无扣款"
            default: return "未来 30 天扣 \(count) 次"
            }
        }
    }

    // MARK: - Sections

    enum Section: Equatable {
        case topFiveTitle
        case topFiveSubtitle
        case byCategoryTitle
        case byCategorySubtitle
        case byCurrencyTitle
        case byCurrencySubtitle
        case statThisMonth
        case statThisYear
        case statActive
    }

    static func sectionLabel(_ section: Section,
                              lang: Lang = .from(.current)) -> String {
        switch (section, lang) {
        case (.topFiveTitle, .en):        return "TOP 5"
        case (.topFiveTitle, .zh):        return "最该看一眼的 5 笔"
        case (.topFiveSubtitle, .en):     return "BY SUSPECT"
        case (.topFiveSubtitle, .zh):     return "建议优先看"
        case (.byCategoryTitle, .en):     return "BY CATEGORY"
        case (.byCategoryTitle, .zh):     return "按分类"
        case (.byCategorySubtitle, .en):  return "MONTHLY"
        case (.byCategorySubtitle, .zh):  return "月度"
        case (.byCurrencyTitle, .en):     return "BY CURRENCY"
        case (.byCurrencyTitle, .zh):     return "按币种"
        case (.byCurrencySubtitle, .en):  return "ORIGINAL · MONTHLY"
        case (.byCurrencySubtitle, .zh):  return "原币种 · 月度"
        case (.statThisMonth, .en):       return "THIS MONTH"
        case (.statThisMonth, .zh):       return "本月"
        case (.statThisYear, .en):        return "THIS YEAR"
        case (.statThisYear, .zh):        return "本年"
        case (.statActive, .en):          return "ACTIVE"
        case (.statActive, .zh):          return "活跃"
        }
    }

    // MARK: - Suspect tags

    /// "EXPENSIVE" / "贵"
    /// "RENEWS IN N DAYS" / "N 天内续费"
    /// "NOT TOUCHED IN N DAYS" / "N 天没动过"
    static func tag(_ tag: SuspectRanker.Tag,
                    lang: Lang = .from(.current)) -> String {
        switch (tag, lang) {
        case (.expensive, .en):
            return "EXPENSIVE"
        case (.expensive, .zh):
            return "贵"
        case (.renewsIn(let days), .en):
            return "RENEWS IN \(days) \(days == 1 ? "DAY" : "DAYS")"
        case (.renewsIn(let days), .zh):
            return "\(days) 天内续费"
        case (.notTouchedIn(let days), .en):
            return "NOT TOUCHED IN \(days) \(days == 1 ? "DAY" : "DAYS")"
        case (.notTouchedIn(let days), .zh):
            return "\(days) 天没动过"
        }
    }

    // MARK: - Empty state

    /// Empty-ranking message when no active subscriptions qualify.
    static func emptyRanking(lang: Lang = .from(.current)) -> String {
        switch lang {
        case .en: return "NO ACTIVE SUBSCRIPTIONS TO RANK"
        case .zh: return "暂无活跃订阅可排名"
        }
    }
}
