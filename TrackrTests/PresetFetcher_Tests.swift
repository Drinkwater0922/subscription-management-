import XCTest
@testable import Trackr

final class PresetFetcherTests: XCTestCase {

    func test_urlSessionFetcher_holdsConfiguredURL() {
        let url = URL(string: "https://example.com/presets.json")!
        let fetcher = URLSessionPresetFetcher(catalogURL: url)
        XCTAssertEqual(fetcher.catalogURL, url)
    }
}
