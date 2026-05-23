import XCTest
@testable import Trackr

/// Tests for the pure `PriceHistoryFormatter` that drives the v1.1 Detail
/// price-history list. Exercises the test plan's PHD-001..PHD-005.
final class PriceHistoryFormatterTests: XCTestCase {

    private func entry(_ amount: Decimal,
                       currency: String = "USD",
                       at offsetDays: Double,
                       source: PriceHistorySource = .userEdit) -> PriceHistoryEntry {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
            .addingTimeInterval(60 * 60 * 24 * offsetDays)
        return PriceHistoryEntry(amount: amount,
                                  currency: currency,
                                  recordedAt: date,
                                  source: source)
    }

    // MARK: - PHD-001 — only-initial timeline

    func test_singleEntry_returnsUnchanged() {
        let rows = PriceHistoryFormatter.rows(from: [
            entry(10, at: 0, source: .initial),
        ])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].direction, .unchanged)
        XCTAssertNil(rows[0].delta)
    }

    func test_singleEntry_hasChangesIsFalse() {
        XCTAssertFalse(PriceHistoryFormatter.hasChanges([
            entry(10, at: 0, source: .initial),
        ]))
    }

    // MARK: - PHD-002 / PHD-003 — direction colors

    func test_increase_directionIsIncrease() {
        let rows = PriceHistoryFormatter.rows(from: [
            entry(15, at: 0, source: .initial),
            entry(18, at: 1, source: .userEdit),
        ])
        XCTAssertEqual(rows.map(\.direction), [.increase, .unchanged])
        XCTAssertEqual(rows.first?.delta, 3)
    }

    func test_decrease_directionIsDecrease() {
        let rows = PriceHistoryFormatter.rows(from: [
            entry(18, at: 0, source: .initial),
            entry(15, at: 1, source: .userEdit),
        ])
        XCTAssertEqual(rows.map(\.direction), [.decrease, .unchanged])
        XCTAssertEqual(rows.first?.delta, -3)
    }

    // MARK: - PHD-004 — currency change

    func test_currencyChange_directionIsCurrencyChanged() {
        let rows = PriceHistoryFormatter.rows(from: [
            entry(10, currency: "USD", at: 0, source: .initial),
            entry(70, currency: "CNY", at: 1, source: .userEdit),
        ])
        XCTAssertEqual(rows.first?.direction, .currencyChanged)
        XCTAssertNil(rows.first?.delta,
                     "currency change cannot produce a numeric delta")
    }

    // MARK: - PHD-005 — descending order

    func test_rows_sortedNewestFirst() {
        let rows = PriceHistoryFormatter.rows(from: [
            entry(10, at: 0, source: .initial),
            entry(15, at: 5, source: .userEdit),
            entry(12, at: 2, source: .userEdit),
        ])
        XCTAssertEqual(rows.map(\.amount), [15, 12, 10],
                       "newest entry must sit at the top of the list")
    }

    // MARK: - hasChanges

    func test_hasChanges_trueWhenAnyDelta() {
        XCTAssertTrue(PriceHistoryFormatter.hasChanges([
            entry(10, at: 0, source: .initial),
            entry(12, at: 1, source: .userEdit),
        ]))
    }

    func test_hasChanges_falseWhenAllUnchanged() {
        // Pathological case — two entries with identical amount + currency.
        // PriceHistoryWrite logic prevents this in production but the
        // formatter must still degrade gracefully.
        XCTAssertFalse(PriceHistoryFormatter.hasChanges([
            entry(10, at: 0, source: .initial),
            entry(10, at: 1, source: .userEdit),
        ]))
    }
}
