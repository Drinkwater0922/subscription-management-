import XCTest
@testable import Trackr

final class FXFallbackTests: XCTestCase {

    // MARK: - Bundle resource integrity

    func test_load_fromMainBundle_succeeds() throws {
        // The bundled fx-fallback.json is shipped in the main bundle and
        // must parse cleanly — if this fails on a clean check-out the app
        // can't bootstrap FX on first launch.
        let bundle = try FXFallbackLoader.load()
        XCTAssertEqual(bundle.baseCurrency, "USD")
        XCTAssertFalse(bundle.rates.isEmpty)
    }

    func test_load_coversCoreCurrencies() throws {
        let bundle = try FXFallbackLoader.load()
        // These are the floor coverage: any of them missing means the
        // v1.1 Home hero will silently skip subscriptions in that
        // currency, which is exactly the bug we're trying to fix.
        for code in ["CNY", "EUR", "JPY", "GBP", "HKD"] {
            XCTAssertNotNil(bundle.rates[code],
                            "fx-fallback.json must include a rate for \(code)")
        }
    }

    func test_load_ratesAreSanePositive() throws {
        let bundle = try FXFallbackLoader.load()
        for (code, value) in bundle.rates {
            XCTAssertGreaterThan(value, 0,
                                  "rate for \(code) must be > 0; saw \(value)")
        }
    }

    func test_load_missingResource_throws() {
        let emptyBundle = Bundle(for: type(of: self))
        // The test bundle has no fx-fallback.json — load() must throw.
        XCTAssertThrowsError(try FXFallbackLoader.load(from: emptyBundle)) { err in
            XCTAssertEqual(err as? FXFallbackLoader.LoadError, .missingResource)
        }
    }
}
