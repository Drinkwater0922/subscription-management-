import XCTest
@testable import Trackr

final class CategoryBreakdownTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_780_272_000)

    func test_emptySubs_returnsEmpty() {
        let result = CategoryBreakdown.breakdown([], in: "USD", rateTable: nil)
        XCTAssertTrue(result.isEmpty)
    }

    func test_groupsByCategory_sumsMonthly() {
        let subs = [
            sub(name: "Netflix",  amount: 20, currency: "USD", category: .streaming),
            sub(name: "Disney",   amount: 10, currency: "USD", category: .streaming),
            sub(name: "ClaudePro",amount: 20, currency: "USD", category: .ai),
        ]
        let result = CategoryBreakdown.breakdown(subs, in: "USD", rateTable: nil)
        XCTAssertEqual(result.count, 2)
        let byCat = Dictionary(uniqueKeysWithValues: result.map { ($0.category, $0) })
        XCTAssertEqual(byCat[.streaming]?.monthlyAmount, 30)
        XCTAssertEqual(byCat[.ai]?.monthlyAmount, 20)
    }

    func test_sortedDescendingByMonthlyAmount() {
        let subs = [
            sub(name: "tiny",   amount: 1,  currency: "USD", category: .news),
            sub(name: "huge",   amount: 50, currency: "USD", category: .streaming),
            sub(name: "medium", amount: 10, currency: "USD", category: .ai),
        ]
        let result = CategoryBreakdown.breakdown(subs, in: "USD", rateTable: nil)
        XCTAssertEqual(result.map(\.category), [.streaming, .ai, .news])
    }

    func test_percentages_sumTo100() {
        let subs = [
            sub(name: "a", amount: 25, currency: "USD", category: .streaming),
            sub(name: "b", amount: 75, currency: "USD", category: .ai),
        ]
        let result = CategoryBreakdown.breakdown(subs, in: "USD", rateTable: nil)
        let total = result.map(\.percentage).reduce(0, +)
        XCTAssertEqual(total, 100, accuracy: 0.001)
    }

    func test_inactiveSubs_excluded() {
        let subs = [
            sub(name: "active",   amount: 10, currency: "USD", category: .streaming),
            sub(name: "inactive", amount: 99, currency: "USD", category: .ai,
                isActive: false),
        ]
        let result = CategoryBreakdown.breakdown(subs, in: "USD", rateTable: nil)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.category, .streaming)
    }

    func test_foreignSubs_convertedThroughTable() throws {
        let table = makeUSDTable(rates: ["CNY": 8.0])
        let subs = [
            sub(name: "USDOne", amount: 10, currency: "USD", category: .ai),
            sub(name: "CNYOne", amount: 80, currency: "CNY", category: .ai),
            // 80 CNY / 8 = 10 USD → ai total = 20 USD
        ]
        let result = CategoryBreakdown.breakdown(subs, in: "USD", rateTable: table)
        XCTAssertEqual(result.first?.monthlyAmount, 20)
    }

    func test_foreignSubs_withMissingRate_dropped() throws {
        let table = makeUSDTable(rates: ["CNY": 8.0])  // EUR missing
        let subs = [
            sub(name: "USDOne", amount: 10, currency: "USD", category: .ai),
            sub(name: "EUROne", amount: 50, currency: "EUR", category: .ai),
        ]
        let result = CategoryBreakdown.breakdown(subs, in: "USD", rateTable: table)
        XCTAssertEqual(result.first?.monthlyAmount, 10,
                       "EUR sub with no rate should be dropped, not counted at 0")
    }

    func test_tieSums_stableSecondaryOrder() {
        // Two categories with identical sums must produce a deterministic
        // order across runs.
        let subs = [
            sub(name: "a", amount: 10, currency: "USD", category: .streaming),
            sub(name: "b", amount: 10, currency: "USD", category: .ai),
        ]
        let runA = CategoryBreakdown.breakdown(subs, in: "USD", rateTable: nil)
        let runB = CategoryBreakdown.breakdown(subs, in: "USD", rateTable: nil)
        XCTAssertEqual(runA.map(\.category), runB.map(\.category))
        // ai < streaming alphabetically by rawValue
        XCTAssertEqual(runA.map(\.category), [.ai, .streaming])
    }

    // MARK: - Helpers

    private func sub(name: String,
                     amount: Decimal,
                     currency: String,
                     category: Trackr.Category,
                     isActive: Bool = true) -> Subscription {
        Subscription(
            name: name, amount: amount, currency: currency,
            billingCycle: .monthly,
            nextBillingDate: now.addingTimeInterval(86_400 * 10),
            startDate: now, category: category, isActive: isActive
        )
    }

    private func makeUSDTable(rates: [String: Decimal]) -> FXRateTable {
        let json = (try? JSONEncoder().encode(rates)) ?? Data()
        return FXRateTable(baseCurrency: "USD", ratesJSON: json, fetchedAt: now)
    }
}
