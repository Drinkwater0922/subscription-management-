import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class FXRateTableTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - Model

    func test_decodedRates_roundTripsThroughJSONBlob() throws {
        // Use string-init Decimals: literal `7.18` is a Double first, which
        // loses precision before we ever encode. Real call sites
        // (FrankfurterLatestRatesClient, FXFallbackLoader) decode straight
        // into Decimal from JSON text, preserving the original digits.
        let rates: [String: Decimal] = [
            "CNY": Decimal(string: "7.18")!,
            "EUR": Decimal(string: "0.92")!,
        ]
        let data = try JSONEncoder().encode(rates)
        let table = FXRateTable(baseCurrency: "USD", ratesJSON: data)
        XCTAssertEqual(table.decodedRates["CNY"], Decimal(string: "7.18"))
        XCTAssertEqual(table.decodedRates["EUR"], Decimal(string: "0.92"))
    }

    func test_decodedRates_corruptBlob_returnsEmpty() {
        let table = FXRateTable(baseCurrency: "USD",
                                 ratesJSON: Data("not json".utf8))
        XCTAssertTrue(table.decodedRates.isEmpty,
                      "corrupt blob must degrade to empty, not crash")
    }

    // MARK: - Repository: single-row semantics

    func test_current_initially_nil() throws {
        let repo = FXRateTableRepository(context: context)
        XCTAssertNil(try repo.current())
    }

    func test_replace_inserts_thenOverwrites() throws {
        let repo = FXRateTableRepository(context: context)
        try repo.replace(baseCurrency: "USD", rates: ["CNY": 7.0])
        XCTAssertEqual(try context.fetch(FetchDescriptor<FXRateTable>()).count, 1)

        try repo.replace(baseCurrency: "USD", rates: ["CNY": 7.5, "EUR": 0.92])
        let rows = try context.fetch(FetchDescriptor<FXRateTable>())
        XCTAssertEqual(rows.count, 1, "replace must keep the table single-row")
        XCTAssertEqual(rows.first?.decodedRates["CNY"], Decimal(string: "7.5"))
        XCTAssertEqual(rows.first?.decodedRates.count, 2)
    }

    func test_replace_uppercasesBaseCurrency() throws {
        let repo = FXRateTableRepository(context: context)
        try repo.replace(baseCurrency: "usd", rates: ["CNY": 7.0])
        XCTAssertEqual(try repo.current()?.baseCurrency, "USD")
    }

    // MARK: - Conversion math

    func test_convert_sameCurrency_returnsInput() throws {
        let repo = FXRateTableRepository(context: context)
        try repo.replace(baseCurrency: "USD", rates: ["CNY": 7.0])
        XCTAssertEqual(try repo.convert(amount: 100, from: "USD", to: "USD"), 100)
    }

    func test_convert_baseToQuote_directLookup() throws {
        let repo = FXRateTableRepository(context: context)
        try repo.replace(baseCurrency: "USD", rates: ["CNY": 7.20])
        let cny = try XCTUnwrap(try repo.convert(amount: 10, from: "USD", to: "CNY"))
        XCTAssertEqual(cny, Decimal(string: "72.00"))
    }

    func test_convert_quoteToBase_inverseLookup() throws {
        let repo = FXRateTableRepository(context: context)
        try repo.replace(baseCurrency: "USD", rates: ["CNY": 8.0])
        // 80 CNY at rate 8 = 10 USD
        let usd = try XCTUnwrap(try repo.convert(amount: 80, from: "CNY", to: "USD"))
        XCTAssertEqual(usd, 10)
    }

    func test_convert_crossRate_throughBase() throws {
        let repo = FXRateTableRepository(context: context)
        try repo.replace(baseCurrency: "USD", rates: ["CNY": 8.0, "EUR": 1.0])
        // CNY → USD → EUR: 80 CNY → 10 USD → 10 EUR
        let eur = try XCTUnwrap(try repo.convert(amount: 80, from: "CNY", to: "EUR"))
        XCTAssertEqual(eur, 10)
    }

    func test_convert_caseInsensitive() throws {
        let repo = FXRateTableRepository(context: context)
        try repo.replace(baseCurrency: "USD", rates: ["CNY": 8.0])
        XCTAssertEqual(try repo.convert(amount: 80, from: "cny", to: "usd"), 10)
    }

    func test_convert_missingTable_returnsNil() throws {
        let repo = FXRateTableRepository(context: context)
        // CNY != USD so the early return doesn't kick in; with no table,
        // we should get nil (caller skips this row).
        XCTAssertNil(try repo.convert(amount: 1, from: "CNY", to: "USD"))
    }

    func test_convert_missingRate_returnsNil() throws {
        let repo = FXRateTableRepository(context: context)
        try repo.replace(baseCurrency: "USD", rates: ["CNY": 8.0])
        XCTAssertNil(try repo.convert(amount: 1, from: "USD", to: "ZZZ"))
        XCTAssertNil(try repo.convert(amount: 1, from: "ZZZ", to: "USD"))
    }
}
