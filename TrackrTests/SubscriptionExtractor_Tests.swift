import XCTest
@testable import Trackr

final class SubscriptionExtractorTests: XCTestCase {

    // MARK: - Fixtures

    private func presets() throws -> [PresetItem] {
        try PresetBundleLoader.loadBundled().items
    }

    // MARK: - Top-level extract

    func test_extract_emptyLines_returnsEmpty() {
        XCTAssertEqual(SubscriptionExtractor.extract(lines: [], presets: []), .empty)
    }

    func test_extract_whitespaceOnly_returnsEmpty() {
        let result = SubscriptionExtractor.extract(lines: ["   ", "\n"], presets: [])
        XCTAssertEqual(result, .empty)
    }

    func test_extract_netflixUsd_matchesPresetAndPriceAndCycle() throws {
        let lines = ["Netflix", "$15.49 / month"]
        let result = SubscriptionExtractor.extract(lines: lines, presets: try presets())
        XCTAssertEqual(result.matchedPreset?.id, "netflix.standard")
        XCTAssertEqual(result.amount, Decimal(string: "15.49"))
        XCTAssertEqual(result.currency, "USD")
        XCTAssertEqual(result.billingCycle, .monthly)
        XCTAssertEqual(result.confidence, 1.0)
    }

    func test_extract_codeTrailingPrice_matchesPresetAndCycle() throws {
        // "USD 20.00" (currency-code-trailing form) + a keyword cycle, combined
        // with a preset name match. The longest-name match rule itself is
        // covered by `test_matchPreset_longestNameWins`.
        let lines = ["Notion", "USD 20.00", "monthly"]
        let result = SubscriptionExtractor.extract(lines: lines, presets: try presets())
        XCTAssertEqual(result.matchedPreset?.id, "notion.plus")
        XCTAssertEqual(result.amount, Decimal(string: "20.00"))
        XCTAssertEqual(result.currency, "USD")
        XCTAssertEqual(result.billingCycle, .monthly)
    }

    func test_extract_chineseSpotify_monthlyCNY() throws {
        let lines = ["Spotify", "¥17.99/月"]
        let result = SubscriptionExtractor.extract(lines: lines, presets: try presets())
        XCTAssertEqual(result.matchedPreset?.id, "spotify.premium")
        XCTAssertEqual(result.amount, Decimal(string: "17.99"))
        XCTAssertEqual(result.currency, "CNY")
        XCTAssertEqual(result.billingCycle, .monthly)
    }

    func test_extract_priceOnly_noPresetMatch_confidenceHalf() {
        let lines = ["Random Service", "$9.99 monthly"]
        let result = SubscriptionExtractor.extract(lines: lines, presets: [])
        XCTAssertNil(result.matchedPreset)
        XCTAssertEqual(result.amount, Decimal(string: "9.99"))
        XCTAssertEqual(result.currency, "USD")
        XCTAssertEqual(result.billingCycle, .monthly)
        XCTAssertEqual(result.confidence, 0.5)
    }

    func test_extract_presetOnly_noPrice_confidenceHalf() throws {
        let lines = ["Netflix"]
        let result = SubscriptionExtractor.extract(lines: lines, presets: try presets())
        XCTAssertEqual(result.matchedPreset?.id, "netflix.standard")
        XCTAssertEqual(result.confidence, 0.5)
        // Falls back to preset defaults when no price was extracted.
        XCTAssertEqual(result.amount, Decimal(string: "15.49"))
        XCTAssertEqual(result.currency, "USD")
    }

    func test_extract_garbage_returnsEmpty() {
        let result = SubscriptionExtractor.extract(lines: ["asdfqwer", "lorem ipsum"],
                                                    presets: [])
        XCTAssertNil(result.amount)
        XCTAssertNil(result.matchedPreset)
        XCTAssertEqual(result.confidence, 0.0)
    }

    // MARK: - Price regex coverage

    func test_extractPrice_dollarSymbol() {
        let hit = SubscriptionExtractor.extractPrice(in: "Netflix $15.49 monthly")
        XCTAssertEqual(hit?.amount, Decimal(string: "15.49"))
        XCTAssertEqual(hit?.currency, "USD")
    }

    func test_extractPrice_codeTrailing() {
        let hit = SubscriptionExtractor.extractPrice(in: "Total: 20.00 USD per month")
        XCTAssertEqual(hit?.amount, Decimal(string: "20.00"))
        XCTAssertEqual(hit?.currency, "USD")
    }

    func test_extractPrice_codeLeading() {
        let hit = SubscriptionExtractor.extractPrice(in: "USD 100 per year")
        XCTAssertEqual(hit?.amount, Decimal(string: "100"))
        XCTAssertEqual(hit?.currency, "USD")
    }

    func test_extractPrice_yen() {
        let hit = SubscriptionExtractor.extractPrice(in: "Spotify ¥144 每月")
        XCTAssertEqual(hit?.amount, Decimal(string: "144"))
        XCTAssertEqual(hit?.currency, "CNY")
    }

    func test_extractPrice_pound() {
        let hit = SubscriptionExtractor.extractPrice(in: "£9.99 monthly")
        XCTAssertEqual(hit?.amount, Decimal(string: "9.99"))
        XCTAssertEqual(hit?.currency, "GBP")
    }

    func test_extractPrice_euro() {
        let hit = SubscriptionExtractor.extractPrice(in: "€8,99 / month")
        XCTAssertEqual(hit?.amount, Decimal(string: "8.99"),
                       "comma decimal separator should normalise to dot")
        XCTAssertEqual(hit?.currency, "EUR")
    }

    func test_extractPrice_noDigits_returnsNil() {
        XCTAssertNil(SubscriptionExtractor.extractPrice(in: "no money here"))
    }

    // MARK: - Cycle regex coverage

    func test_extractCycle_monthlyKeyword() {
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "billed monthly"), .monthly)
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "$9.99/mo"), .monthly)
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "per month"), .monthly)
    }

    func test_extractCycle_yearlyKeyword() {
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "annual subscription"), .yearly)
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "$99/year"), .yearly)
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "billed yearly"), .yearly)
    }

    func test_extractCycle_weeklyKeyword() {
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "$5 / week"), .weekly)
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "weekly"), .weekly)
    }

    func test_extractCycle_chineseKeywords() {
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "¥17.99/月"), .monthly)
        XCTAssertEqual(SubscriptionExtractor.extractCycle(in: "每年 168 元"), .yearly)
    }

    func test_extractCycle_nothing_returnsNil() {
        XCTAssertNil(SubscriptionExtractor.extractCycle(in: "Netflix $15.49"))
    }

    // MARK: - Price regex regressions (M10.6)

    func test_extractPrice_thousandsSeparator_usFormat() {
        // The Plaud bug — `¥1,099.00` used to capture only "1,09" → 1.09.
        let hit = SubscriptionExtractor.extractPrice(in: "Plaud AI MemberShip ¥1,099.00")
        XCTAssertEqual(hit?.amount, Decimal(string: "1099.00"))
        XCTAssertEqual(hit?.currency, "CNY")
    }

    func test_extractPrice_thousandsSeparator_largeNumber() {
        let hit = SubscriptionExtractor.extractPrice(in: "¥659.00 即梦AI")
        XCTAssertEqual(hit?.amount, Decimal(string: "659.00"))
        let hit2 = SubscriptionExtractor.extractPrice(in: "$12,345.67 monthly")
        XCTAssertEqual(hit2?.amount, Decimal(string: "12345.67"))
    }

    func test_extractPrice_europeanDecimal_stillWorks() {
        // `15,49 €` should still parse as 15.49.
        let hit = SubscriptionExtractor.extractPrice(in: "€15,49 monthly")
        XCTAssertEqual(hit?.amount, Decimal(string: "15.49"))
    }

    // MARK: - Date extraction (M10.6)

    func test_extractDate_chineseFullDate() {
        let result = SubscriptionExtractor.extractDate(in: "将于2027年1月4日到期")
        XCTAssertNotNil(result)
        let cal = Calendar(identifier: .gregorian)
        XCTAssertEqual(cal.component(.year,  from: result!), 2027)
        XCTAssertEqual(cal.component(.month, from: result!), 1)
        XCTAssertEqual(cal.component(.day,   from: result!), 4)
    }

    func test_extractDate_chineseMonthDay_resolvesToNextOccurrence() {
        // "today" pinned to May 17 2026.
        let cal = Calendar(identifier: .gregorian)
        let today = cal.date(from: DateComponents(year: 2026, month: 5, day: 17))!

        // "6月11日续期" — same year, later month → June 11 2026.
        let june = SubscriptionExtractor.extractDate(in: "6月11日续期", now: today)
        XCTAssertEqual(cal.component(.year,  from: june!), 2026)
        XCTAssertEqual(cal.component(.month, from: june!), 6)

        // "3月5日到期" — already passed in 2026 → 2027.
        let march = SubscriptionExtractor.extractDate(in: "3月5日到期", now: today)
        XCTAssertEqual(cal.component(.year, from: march!), 2027)
    }

    func test_extractDate_noMatch_returnsNil() {
        XCTAssertNil(SubscriptionExtractor.extractDate(in: "just some words"))
    }

    func test_extract_appliesDateToSubscription_anchorsCycleStart() throws {
        // 即刻App is a YEARLY preset; the screenshot date "12月26日续期" is the
        // *next* renewal. apply(to:) should:
        //   - set draft.nextBillingDate to the parsed date
        //   - set draft.startDate one year before (= current cycle start)
        let presets = try PresetBundleLoader.loadBundled().items
        let result = SubscriptionExtractor.extract(
            lines: ["即刻App", "Jike Yellow", "¥128.00", "12月26日续期"],
            presets: presets
        )
        XCTAssertNotNil(result.nextBillingDate)
        XCTAssertEqual(result.matchedPreset?.id, "jike.app")

        var draft = SubscriptionDraft.empty(defaultCurrency: "CNY")
        result.apply(to: &draft)
        XCTAssertEqual(draft.nextBillingDate, result.nextBillingDate)

        let cal = Calendar(identifier: .gregorian)
        let expectedStart = cal.date(byAdding: .year, value: -1,
                                      to: result.nextBillingDate!)
        XCTAssertEqual(draft.startDate, expectedStart,
                       "yearly sub: startDate must be one year before next bill")

        // And the eventual Subscription carries both dates correctly.
        let sub = try draft.makeSubscription()
        XCTAssertEqual(sub.startDate, expectedStart)
        XCTAssertEqual(sub.nextBillingDate, result.nextBillingDate)
    }

    func test_apply_monthlyCycle_anchorsStartOneMonthBack() throws {
        // Monthly sub renewing on June 11, 2026 should anchor at May 11, 2026.
        var draft = SubscriptionDraft.empty(defaultCurrency: "CNY")
        draft.billingCycle = .monthly
        let cal = Calendar(identifier: .gregorian)
        let nextBill = cal.date(from: DateComponents(year: 2026, month: 6, day: 11))!
        let result = ExtractedSubscription(
            amount: 25, currency: "CNY", billingCycle: .monthly,
            matchedPreset: nil, inferredName: nil,
            nextBillingDate: nextBill, confidence: 0.5
        )
        result.apply(to: &draft)
        let expectedStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 11))!
        XCTAssertEqual(draft.startDate, expectedStart)
        XCTAssertEqual(draft.nextBillingDate, nextBill)
    }

    func test_apply_noExtractedDate_leavesDatesAlone() throws {
        // When OCR found no date, draft's startDate stays at .now and
        // nextBillingDate stays nil (which makes makeSubscription fall back
        // to "next bill = start" — fine for manually-typed subs).
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        let originalStart = draft.startDate
        let result = ExtractedSubscription(
            amount: 9.99, currency: "USD", billingCycle: .monthly,
            matchedPreset: nil, inferredName: nil,
            nextBillingDate: nil, confidence: 0.5
        )
        result.apply(to: &draft)
        XCTAssertEqual(draft.startDate, originalStart)
        XCTAssertNil(draft.nextBillingDate)
    }

    // MARK: - matchPreset

    func test_matchPreset_caseInsensitive() throws {
        let p = try presets()
        XCTAssertEqual(SubscriptionExtractor.matchPreset(in: ["NETFLIX"], presets: p)?.id,
                       "netflix.standard")
        XCTAssertEqual(SubscriptionExtractor.matchPreset(in: ["netflix"], presets: p)?.id,
                       "netflix.standard")
    }

    func test_matchPreset_longestNameWins() throws {
        // "Apple Music" must beat "Apple TV+" beat anything that just says "Apple".
        let p = try presets()
        XCTAssertEqual(SubscriptionExtractor.matchPreset(in: ["Apple Music Individual"],
                                                         presets: p)?.id,
                       "apple.music")
    }

    func test_matchPreset_noHit_returnsNil() throws {
        let p = try presets()
        XCTAssertNil(SubscriptionExtractor.matchPreset(in: ["Nothing here"], presets: p))
    }

    // MARK: - apply(to:)

    func test_apply_seedsDraftFromPreset() throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        let result = SubscriptionExtractor.extract(lines: ["Netflix", "$15.49 monthly"],
                                                    presets: try presets())
        result.apply(to: &draft)
        XCTAssertEqual(draft.name, "Netflix")
        XCTAssertEqual(draft.amountString, "15.49")
        XCTAssertEqual(draft.currency, "USD")
        XCTAssertEqual(draft.billingCycle, .monthly)
        XCTAssertEqual(draft.category, .streaming)
    }

    func test_apply_priceOverridesPresetDefault() throws {
        // The user's screenshot shows $20.00 even though our seed Netflix is
        // $15.49 — we trust what the OCR saw. Compare numerically; trailing
        // zeros aren't preserved through `Decimal`.
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        let result = SubscriptionExtractor.extract(lines: ["Netflix", "$20.00 monthly"],
                                                    presets: try presets())
        result.apply(to: &draft)
        XCTAssertEqual(Decimal(string: draft.amountString), Decimal(string: "20.00"))
    }

    func test_apply_leavesUntouchedFieldsAlone() {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Pre-typed name"
        let result = ExtractedSubscription.empty
        result.apply(to: &draft)
        XCTAssertEqual(draft.name, "Pre-typed name")
    }
}
