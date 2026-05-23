import XCTest
import SwiftData
@testable import Trackr

/// Legacy M11 FX behavior that survives into v1.1 unchanged:
///   * `FakeFXClient` test double sanity (still used by some preset/photo flows).
///   * `SubscriptionDetailView.convertedAmountText` — the per-sub "≈ ¥144 @ date"
///     line that renders when an existing TestFlight row has a pinned rate.
///
/// The v1.1 calculator-side conversion (FXRateTable) is covered by
/// `MonthlyTotalCalculatorTests` and `FXRateTableTests`. The
/// AddSubscriptionSheet no longer pins rates, so the corresponding submit
/// tests have moved into `AddSubscriptionSheetSubmitTests`.
final class FXTests: XCTestCase {

    // MARK: - FakeFXClient sanity

    func test_fakeClient_returnsStubbedRate() async throws {
        let client = FakeFXClient()
        client.stubbedRates["USD→CNY"] = Decimal(string: "7.12")!
        let rate = try await client.rate(from: "USD", to: "CNY", on: .now)
        XCTAssertEqual(rate, Decimal(string: "7.12"))
        XCTAssertEqual(client.calls.count, 1)
        XCTAssertEqual(client.calls.first?.base, "USD")
        XCTAssertEqual(client.calls.first?.quote, "CNY")
    }

    func test_fakeClient_throwsWhenRateMissing() async {
        let client = FakeFXClient()
        do {
            _ = try await client.rate(from: "USD", to: "JPY", on: .now)
            XCTFail("expected missing-rate throw")
        } catch let err as FXError {
            XCTAssertEqual(err, .missingRate(quote: "JPY"))
        } catch {
            XCTFail("expected FXError, got \(error)")
        }
    }

    // MARK: - SubscriptionDetailView.convertedAmountText (legacy display)

    private func makeSub(amount: Decimal,
                         currency: String,
                         exchangeRateToHome: Decimal? = nil,
                         homeCurrency: String? = nil) -> Subscription {
        Subscription(
            name: "Test",
            amount: amount,
            currency: currency,
            billingCycle: .monthly,
            nextBillingDate: .now,
            startDate: .now,
            category: .other,
            exchangeRateToHome: exchangeRateToHome,
            exchangeRateAsOf: exchangeRateToHome == nil ? nil : .now,
            homeCurrencyAtCreation: homeCurrency
        )
    }

    func test_convertedAmountText_renders_whenPinned() {
        let sub = makeSub(amount: 20, currency: "USD",
                           exchangeRateToHome: Decimal(string: "7.0")!,
                           homeCurrency: "CNY")
        let text = SubscriptionDetailView.convertedAmountText(for: sub) ?? ""
        XCTAssertTrue(text.hasPrefix("≈ "), "got: \(text)")
        XCTAssertTrue(text.contains("@"), "got: \(text)")
    }

    func test_convertedAmountText_nil_whenNoRate() {
        let sub = makeSub(amount: 20, currency: "USD")
        XCTAssertNil(SubscriptionDetailView.convertedAmountText(for: sub))
    }

    func test_convertedAmountText_nil_whenSameCurrency() {
        let sub = makeSub(amount: 20, currency: "USD",
                           exchangeRateToHome: Decimal(string: "1.0")!,
                           homeCurrency: "USD")
        XCTAssertNil(SubscriptionDetailView.convertedAmountText(for: sub))
    }
}
