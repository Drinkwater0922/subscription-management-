import XCTest
@testable import Trackr

final class InsightsCopyTests: XCTestCase {

    // MARK: - Lang detection

    func test_lang_detectsZh() {
        XCTAssertEqual(InsightsCopy.Lang.from(Locale(identifier: "zh-Hans")), .zh)
        XCTAssertEqual(InsightsCopy.Lang.from(Locale(identifier: "zh-Hant")), .zh)
        XCTAssertEqual(InsightsCopy.Lang.from(Locale(identifier: "zh-CN")), .zh)
    }

    func test_lang_fallsBackToEnForUnknown() {
        XCTAssertEqual(InsightsCopy.Lang.from(Locale(identifier: "fr-FR")), .en)
        XCTAssertEqual(InsightsCopy.Lang.from(Locale(identifier: "de")), .en)
        XCTAssertEqual(InsightsCopy.Lang.from(Locale(identifier: "ja")), .en)
        XCTAssertEqual(InsightsCopy.Lang.from(Locale(identifier: "en-US")), .en)
    }

    // MARK: - Hero

    func test_heroTitle_bothLanguages() {
        XCTAssertEqual(InsightsCopy.heroTitle(lang: .en), "NEXT 30 DAYS DUE")
        XCTAssertEqual(InsightsCopy.heroTitle(lang: .zh), "未来 30 天扣款")
    }

    func test_chargesSubtitle_zero_bothLanguages() {
        XCTAssertEqual(InsightsCopy.chargesSubtitle(count: 0, lang: .en),
                       "NO CHARGES IN THE NEXT 30 DAYS")
        XCTAssertEqual(InsightsCopy.chargesSubtitle(count: 0, lang: .zh),
                       "未来 30 天无扣款")
    }

    func test_chargesSubtitle_one_bothLanguages() {
        XCTAssertEqual(InsightsCopy.chargesSubtitle(count: 1, lang: .en),
                       "1 CHARGE INCOMING")
        XCTAssertEqual(InsightsCopy.chargesSubtitle(count: 1, lang: .zh),
                       "未来 30 天扣 1 次")
    }

    func test_chargesSubtitle_many_bothLanguages() {
        XCTAssertEqual(InsightsCopy.chargesSubtitle(count: 7, lang: .en),
                       "7 CHARGES INCOMING")
        XCTAssertEqual(InsightsCopy.chargesSubtitle(count: 7, lang: .zh),
                       "未来 30 天扣 7 次")
    }

    // MARK: - Section labels

    func test_sectionLabels_topFive() {
        XCTAssertEqual(InsightsCopy.sectionLabel(.topFiveTitle, lang: .en), "TOP 5")
        XCTAssertEqual(InsightsCopy.sectionLabel(.topFiveTitle, lang: .zh), "最该看一眼的 5 笔")
        XCTAssertEqual(InsightsCopy.sectionLabel(.topFiveSubtitle, lang: .en), "BY SUSPECT")
        XCTAssertEqual(InsightsCopy.sectionLabel(.topFiveSubtitle, lang: .zh), "建议优先看")
    }

    func test_sectionLabels_byCategory() {
        XCTAssertEqual(InsightsCopy.sectionLabel(.byCategoryTitle, lang: .en), "BY CATEGORY")
        XCTAssertEqual(InsightsCopy.sectionLabel(.byCategoryTitle, lang: .zh), "按分类")
        XCTAssertEqual(InsightsCopy.sectionLabel(.byCategorySubtitle, lang: .en), "MONTHLY")
        XCTAssertEqual(InsightsCopy.sectionLabel(.byCategorySubtitle, lang: .zh), "月度")
    }

    func test_sectionLabels_byCurrency() {
        XCTAssertEqual(InsightsCopy.sectionLabel(.byCurrencyTitle, lang: .en), "BY CURRENCY")
        XCTAssertEqual(InsightsCopy.sectionLabel(.byCurrencyTitle, lang: .zh), "按币种")
        XCTAssertEqual(InsightsCopy.sectionLabel(.byCurrencySubtitle, lang: .en), "ORIGINAL · MONTHLY")
        XCTAssertEqual(InsightsCopy.sectionLabel(.byCurrencySubtitle, lang: .zh), "原币种 · 月度")
    }

    func test_sectionLabels_stat() {
        XCTAssertEqual(InsightsCopy.sectionLabel(.statThisMonth, lang: .en), "THIS MONTH")
        XCTAssertEqual(InsightsCopy.sectionLabel(.statThisMonth, lang: .zh), "本月")
        XCTAssertEqual(InsightsCopy.sectionLabel(.statThisYear, lang: .en), "THIS YEAR")
        XCTAssertEqual(InsightsCopy.sectionLabel(.statThisYear, lang: .zh), "本年")
        XCTAssertEqual(InsightsCopy.sectionLabel(.statActive, lang: .en), "ACTIVE")
        XCTAssertEqual(InsightsCopy.sectionLabel(.statActive, lang: .zh), "活跃")
    }

    // MARK: - Tags

    func test_tag_expensive_bothLanguages() {
        XCTAssertEqual(InsightsCopy.tag(.expensive, lang: .en), "EXPENSIVE")
        XCTAssertEqual(InsightsCopy.tag(.expensive, lang: .zh), "贵")
    }

    func test_tag_renewsIn_pluralAndSingular() {
        XCTAssertEqual(InsightsCopy.tag(.renewsIn(days: 1), lang: .en),
                       "RENEWS IN 1 DAY")
        XCTAssertEqual(InsightsCopy.tag(.renewsIn(days: 5), lang: .en),
                       "RENEWS IN 5 DAYS")
        XCTAssertEqual(InsightsCopy.tag(.renewsIn(days: 1), lang: .zh),
                       "1 天内续费")
        XCTAssertEqual(InsightsCopy.tag(.renewsIn(days: 5), lang: .zh),
                       "5 天内续费")
    }

    func test_tag_notTouchedIn_pluralAndSingular() {
        XCTAssertEqual(InsightsCopy.tag(.notTouchedIn(days: 1), lang: .en),
                       "NOT TOUCHED IN 1 DAY")
        XCTAssertEqual(InsightsCopy.tag(.notTouchedIn(days: 365), lang: .en),
                       "NOT TOUCHED IN 365 DAYS")
        XCTAssertEqual(InsightsCopy.tag(.notTouchedIn(days: 365), lang: .zh),
                       "365 天没动过")
    }

    // MARK: - Empty state

    func test_emptyRanking_bothLanguages() {
        XCTAssertEqual(InsightsCopy.emptyRanking(lang: .en),
                       "NO ACTIVE SUBSCRIPTIONS TO RANK")
        XCTAssertEqual(InsightsCopy.emptyRanking(lang: .zh),
                       "暂无活跃订阅可排名")
    }
}
