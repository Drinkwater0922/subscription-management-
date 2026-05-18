import XCTest
@testable import Trackr

/// Tests the FakePhotoImportPipeline -> SubscriptionExtractor flow that
/// powers the "Import from Photo" affordance. Mirrors the production code
/// path without needing the SwiftUI host or PhotosPicker.
final class PhotoImportIntegrationTests: XCTestCase {

    func test_fakePipeline_feedsExtractor_andYieldsHighConfidence() async throws {
        let pipeline = FakePhotoImportPipeline()
        pipeline.stubFromStrings(["Netflix", "$15.49 / month"])

        let lines = try await pipeline.recognizeText(in: Data())
        let presets = try PresetBundleLoader.loadBundled().items
        let result = SubscriptionExtractor.extract(lines: lines.map(\.text),
                                                    presets: presets)

        XCTAssertEqual(pipeline.receivedDataCount, 1)
        XCTAssertEqual(result.matchedPreset?.id, "netflix.standard")
        XCTAssertEqual(result.confidence, 1.0)
    }

    func test_fakePipeline_propagatesError() async {
        let pipeline = FakePhotoImportPipeline()
        pipeline.stubbedError = PhotoImportError.decodeFailed

        do {
            _ = try await pipeline.recognizeText(in: Data())
            XCTFail("expected throw")
        } catch let err as PhotoImportError {
            XCTAssertEqual(err, .decodeFailed)
        } catch {
            XCTFail("expected PhotoImportError, got \(error)")
        }
    }

    // MARK: - bannerMessage formatting

    func test_bannerMessage_fullMatch_namesProduct() throws {
        let presets = try PresetBundleLoader.loadBundled().items
        let result = SubscriptionExtractor.extract(lines: ["Netflix", "$15.49 monthly"],
                                                    presets: presets)
        XCTAssertEqual(AddSubscriptionSheet.bannerMessage(for: result),
                       "Matched Netflix — confirm and save")
    }

    func test_bannerMessage_priceOnly() {
        let result = SubscriptionExtractor.extract(lines: ["Random", "$9.99 monthly"],
                                                    presets: [])
        XCTAssertEqual(AddSubscriptionSheet.bannerMessage(for: result),
                       "Captured price — add a name and save")
    }

    func test_bannerMessage_presetOnly() throws {
        let presets = try PresetBundleLoader.loadBundled().items
        let result = SubscriptionExtractor.extract(lines: ["Netflix"], presets: presets)
        XCTAssertEqual(AddSubscriptionSheet.bannerMessage(for: result),
                       "Found a match — add the price and save")
    }

    func test_bannerMessage_nothing() {
        XCTAssertEqual(AddSubscriptionSheet.bannerMessage(for: .empty),
                       "Couldn't read this one — try a clearer photo")
    }

    // MARK: - Multi-row extraction (M10.5)

    /// Simulates the iOS Subscriptions full-page screenshot the real user
    /// fed in: 3 visually-distinct rows on one screen. extractAll should
    /// produce one candidate per row.
    func test_extractAll_appleSubscriptions_returnsPerRowCandidates() throws {
        let presets = try PresetBundleLoader.loadBundled().items
        // Y bands chosen to mimic three iOS Subscriptions cards stacked
        // top-to-bottom. Within each band the lines are tightly clustered.
        let lines: [RecognizedTextLine] = [
            // Row 1: 腾讯视频 ¥25
            .init(text: "腾讯视频-张艺谋监制大剧", bounds: rect(y: 0.10, h: 0.02)),
            .init(text: "腾讯视频VIP",              bounds: rect(y: 0.13, h: 0.02)),
            .init(text: "¥25.00",                   bounds: rect(y: 0.12, h: 0.02)),
            .init(text: "6月11日续期",              bounds: rect(y: 0.16, h: 0.02)),
            // Row 2: iCloud+ ¥68
            .init(text: "iCloud+",                  bounds: rect(y: 0.32, h: 0.02)),
            .init(text: "iCloud+(含 2 TB 储存空间)", bounds: rect(y: 0.35, h: 0.02)),
            .init(text: "¥68.00",                   bounds: rect(y: 0.34, h: 0.02)),
            .init(text: "6月13日续期",              bounds: rect(y: 0.38, h: 0.02)),
            // Row 3: 即刻App ¥128 yearly
            .init(text: "即刻App",                  bounds: rect(y: 0.54, h: 0.02)),
            .init(text: "Jike Yellow - 年度订阅",   bounds: rect(y: 0.57, h: 0.02)),
            .init(text: "¥128.00",                  bounds: rect(y: 0.56, h: 0.02)),
            .init(text: "12月26日续期",             bounds: rect(y: 0.60, h: 0.02)),
        ]
        let candidates = SubscriptionExtractor.extractAll(textLines: lines,
                                                          presets: presets)
        XCTAssertEqual(candidates.count, 3, "expected one candidate per visual row")
        XCTAssertTrue(candidates.contains { $0.amount == Decimal(string: "25.00") })
        XCTAssertTrue(candidates.contains { $0.amount == Decimal(string: "68.00") })
        XCTAssertTrue(candidates.contains { $0.amount == Decimal(string: "128.00") })
        // All three rows have CNY prices
        XCTAssertTrue(candidates.allSatisfy { $0.currency == "CNY" })
        // 即刻 should match the new preset
        XCTAssertTrue(candidates.contains { $0.matchedPreset?.id == "jike.app" })
    }

    func test_extractAll_emptyInput_returnsEmpty() {
        XCTAssertTrue(SubscriptionExtractor.extractAll(textLines: [], presets: []).isEmpty)
    }

    func test_extractAll_singleRow_returnsSingleCandidate() throws {
        let presets = try PresetBundleLoader.loadBundled().items
        let lines: [RecognizedTextLine] = [
            .init(text: "Netflix",      bounds: rect(y: 0.10, h: 0.02)),
            .init(text: "$15.49 / month", bounds: rect(y: 0.13, h: 0.02)),
        ]
        let candidates = SubscriptionExtractor.extractAll(textLines: lines, presets: presets)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.matchedPreset?.id, "netflix.standard")
    }

    func test_extractAll_dropsRowsWithNoUsefulData() throws {
        let lines: [RecognizedTextLine] = [
            // Row 1: useful price
            .init(text: "Random Service",  bounds: rect(y: 0.10, h: 0.02)),
            .init(text: "¥99.00 / month",  bounds: rect(y: 0.13, h: 0.02)),
            // Row 2: no name, no price — should be filtered out
            .init(text: "Just some text",  bounds: rect(y: 0.50, h: 0.02)),
            .init(text: "More text",       bounds: rect(y: 0.53, h: 0.02)),
        ]
        let candidates = SubscriptionExtractor.extractAll(textLines: lines, presets: [])
        XCTAssertEqual(candidates.count, 1, "row without name/price should be dropped")
        XCTAssertEqual(candidates.first?.amount, Decimal(string: "99.00"))
    }

    func test_extractAll_inferredName_appearsWhenNoPresetMatches() throws {
        let lines: [RecognizedTextLine] = [
            .init(text: "讯飞听见-AI录音转文字实时翻译", bounds: rect(y: 0.10, h: 0.02)),
            .init(text: "录音转写包",                  bounds: rect(y: 0.13, h: 0.02)),
            .init(text: "¥30.00",                      bounds: rect(y: 0.12, h: 0.02)),
            .init(text: "5月25日到期",                 bounds: rect(y: 0.16, h: 0.02)),
        ]
        let candidates = SubscriptionExtractor.extractAll(textLines: lines, presets: [])
        XCTAssertEqual(candidates.count, 1)
        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertNil(candidate.matchedPreset)
        XCTAssertNotNil(candidate.inferredName)
        XCTAssertTrue(candidate.displayName.contains("讯飞"))
        XCTAssertEqual(candidate.amount, Decimal(string: "30.00"))
    }

    // MARK: - Row grouping

    /// Real-world failure mode (M10.6): on the actual iOS Subscriptions
    /// screenshot the user fed in, the cards are stacked tightly —
    /// intra-card gaps (~0.020) and inter-card gaps (~0.015) are too similar
    /// for any pure Y-distance grouping to separate. The date-anchor
    /// algorithm splits cleanly because every card ends with a date line.
    func test_extractAll_tightlyStackedCards_splitsOnDateAnchor() throws {
        let presets = try PresetBundleLoader.loadBundled().items
        let lines: [RecognizedTextLine] = [
            // Card 1: Plaud (date at bottom)
            .init(text: "Plaud",                bounds: rect(y: 0.10, h: 0.015)),
            .init(text: "AI MemberShip",        bounds: rect(y: 0.13, h: 0.015)),
            .init(text: "¥1,099.00",            bounds: rect(y: 0.11, h: 0.015)),
            .init(text: "2027年1月14日续期",    bounds: rect(y: 0.16, h: 0.015)),
            // Card 2: 即刻 (similar Y spacing — under tight layout)
            .init(text: "即刻App",              bounds: rect(y: 0.19, h: 0.015)),
            .init(text: "Jike Yellow - 年度订阅", bounds: rect(y: 0.22, h: 0.015)),
            .init(text: "¥128.00",              bounds: rect(y: 0.20, h: 0.015)),
            .init(text: "12月26日续期",         bounds: rect(y: 0.25, h: 0.015)),
            // Card 3: 脉脉
            .init(text: "脉脉-找人脉找工作求职招聘", bounds: rect(y: 0.28, h: 0.015)),
            .init(text: "会员",                 bounds: rect(y: 0.31, h: 0.015)),
            .init(text: "¥688.00",              bounds: rect(y: 0.29, h: 0.015)),
            .init(text: "2027年4月23日续期",    bounds: rect(y: 0.34, h: 0.015)),
        ]
        let candidates = SubscriptionExtractor.extractAll(textLines: lines,
                                                          presets: presets)
        XCTAssertEqual(candidates.count, 3,
                       "tight-stacked cards should split on date anchors")

        // Each candidate must carry its date — that's what was broken before.
        XCTAssertTrue(candidates.allSatisfy { $0.nextBillingDate != nil },
                      "every card has a date in the OCR; extractor must keep it")

        // Plaud + 脉脉 + 即刻 are all preset-matched now.
        let ids = Set(candidates.compactMap { $0.matchedPreset?.id })
        XCTAssertTrue(ids.contains("plaud.ai"))
        XCTAssertTrue(ids.contains("maimai.member"))
        XCTAssertTrue(ids.contains("jike.app"))

        // Prices: 1099 (not 1.09), 128, 688
        let amounts = candidates.compactMap(\.amount).sorted()
        XCTAssertEqual(amounts, [Decimal(128), Decimal(688), Decimal(1099)])
    }

    func test_groupIntoRows_clustersByYProximity() {
        let lines: [RecognizedTextLine] = [
            .init(text: "A1", bounds: rect(y: 0.10, h: 0.02)),
            .init(text: "A2", bounds: rect(y: 0.12, h: 0.02)),
            .init(text: "B1", bounds: rect(y: 0.30, h: 0.02)),
            .init(text: "B2", bounds: rect(y: 0.32, h: 0.02)),
        ]
        let rows = SubscriptionExtractor.groupIntoRows(lines)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].count, 2)
        XCTAssertEqual(rows[1].count, 2)
    }

    private func rect(y: CGFloat, h: CGFloat) -> CGRect {
        CGRect(x: 0, y: y, width: 1, height: h)
    }
}
