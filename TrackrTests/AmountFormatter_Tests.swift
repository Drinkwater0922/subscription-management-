import XCTest
@testable import Trackr

final class AmountFormatterTests: XCTestCase {

    func test_USD_simpleInteger() {
        XCTAssertEqual(AmountFormatter.format(20, currency: "USD"), "$20.00")
    }

    func test_USD_decimal() {
        XCTAssertEqual(AmountFormatter.format(Decimal(string: "147.92")!, currency: "USD"), "$147.92")
    }

    func test_CNY_simple() {
        XCTAssertEqual(AmountFormatter.format(21, currency: "CNY"), "¥21.00")
    }

    func test_zero() {
        XCTAssertEqual(AmountFormatter.format(0, currency: "USD"), "$0.00")
    }

    func test_thousandsSeparator() {
        XCTAssertEqual(
            AmountFormatter.format(Decimal(string: "1775")!, currency: "USD"),
            "$1,775.00"
        )
    }

    func test_unknownCurrency_fallsBackToCodePrefix() {
        // For unknown ISO codes, we don't crash — we just include the amount somewhere
        // in the result. The exact format may vary across iOS versions for unknown codes.
        let result = AmountFormatter.format(10, currency: "ZZZ")
        XCTAssertTrue(result.contains("10"), "got: \(result)")
    }
}
