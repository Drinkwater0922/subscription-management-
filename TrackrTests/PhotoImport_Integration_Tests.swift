import XCTest
@testable import Trackr

/// Tests the FakePhotoImportPipeline -> SubscriptionExtractor flow that
/// powers the "Import from Photo" affordance. Mirrors the production code
/// path without needing the SwiftUI host or PhotosPicker.
final class PhotoImportIntegrationTests: XCTestCase {

    func test_fakePipeline_feedsExtractor_andYieldsHighConfidence() async throws {
        let pipeline = FakePhotoImportPipeline()
        pipeline.stubbedLines = ["Netflix", "$15.49 / month"]

        let lines = try await pipeline.recognizeText(in: Data())
        let presets = try PresetBundleLoader.loadBundled().items
        let result = SubscriptionExtractor.extract(lines: lines, presets: presets)

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
}
