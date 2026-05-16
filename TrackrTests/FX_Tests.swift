import XCTest
import SwiftData
@testable import Trackr

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

    // MARK: - MonthlyTotalCalculator multi-currency rules

    private func makeSub(amount: Decimal,
                         currency: String,
                         cycle: BillingCycle = .monthly,
                         exchangeRateToHome: Decimal? = nil,
                         homeCurrency: String? = nil) -> Subscription {
        Subscription(
            name: "Test",
            amount: amount,
            currency: currency,
            billingCycle: cycle,
            nextBillingDate: .now,
            startDate: .now,
            category: .other,
            exchangeRateToHome: exchangeRateToHome,
            exchangeRateAsOf: exchangeRateToHome == nil ? nil : .now,
            homeCurrencyAtCreation: homeCurrency
        )
    }

    func test_total_homeCurrencyOnly_unchanged() {
        let subs = [
            makeSub(amount: 10, currency: "USD"),
            makeSub(amount: 20, currency: "USD"),
        ]
        XCTAssertEqual(MonthlyTotalCalculator.total(of: subs, in: "USD"), 30)
    }

    func test_total_foreignWithPinnedRate_convertsIntoHome() {
        // CNY sub with pinned 1 CNY = 0.14 USD → 70 CNY/month becomes 9.8 USD.
        let cnySub = makeSub(amount: 70, currency: "CNY",
                              exchangeRateToHome: Decimal(string: "0.14")!,
                              homeCurrency: "USD")
        let usdSub = makeSub(amount: 5, currency: "USD")
        let total = MonthlyTotalCalculator.total(of: [cnySub, usdSub], in: "USD")
        XCTAssertEqual(total, Decimal(string: "14.8"))
    }

    func test_total_foreignWithoutRate_isSkipped() {
        let foreign = makeSub(amount: 100, currency: "CNY")
        let usd = makeSub(amount: 12, currency: "USD")
        let total = MonthlyTotalCalculator.total(of: [foreign, usd], in: "USD")
        XCTAssertEqual(total, 12, "unconvertible foreign sub must be skipped, not invented")
    }

    func test_total_pinnedHomeMismatch_isSkipped() {
        // Sub was pinned against USD; user is asking for the total in CNY.
        // Without an inverse rate we shouldn't try to invent one.
        let usdSub = makeSub(amount: 20, currency: "USD",
                              exchangeRateToHome: Decimal(string: "7.0")!,
                              homeCurrency: "USD")
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [usdSub], in: "CNY"), 0)
    }

    func test_monthlyContribution_perSub() {
        let sub = makeSub(amount: 120, currency: "USD", cycle: .yearly)
        XCTAssertEqual(MonthlyTotalCalculator.monthlyContribution(of: sub, in: "USD"), 10)
    }

    // MARK: - AddSubscriptionSheet.submit FX wiring

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Subscription.self, RenewalEvent.self, UserSettings.self,
                             PresetCache.self, PriceChangeAlert.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true,
                                         cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    func test_submit_foreignCurrency_pinsRate() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fx = FakeFXClient()
        fx.stubbedRates["USD→CNY"] = Decimal(string: "7.0")!
        let pinDate = Date(timeIntervalSince1970: 1_700_000_000)

        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Netflix"
        draft.amountString = "15.49"
        draft.currency = "USD"
        draft.billingCycle = .monthly
        draft.category = .streaming

        let err = await AddSubscriptionSheet.submit(
            draft: draft,
            fxClient: fx,
            homeCurrency: "CNY",
            today: pinDate,
            context: context,
            onDismiss: { }
        )
        XCTAssertNil(err)

        let saved = try SubscriptionRepository(context: context).fetchAll()
        XCTAssertEqual(saved.count, 1)
        let sub = try XCTUnwrap(saved.first)
        XCTAssertEqual(sub.exchangeRateToHome, Decimal(string: "7.0"))
        XCTAssertEqual(sub.homeCurrencyAtCreation, "CNY")
        XCTAssertEqual(sub.exchangeRateAsOf, pinDate)
        XCTAssertEqual(fx.calls.count, 1)
        XCTAssertEqual(fx.calls.first?.base, "USD")
        XCTAssertEqual(fx.calls.first?.quote, "CNY")
    }

    @MainActor
    func test_submit_homeCurrencyMatches_skipsFXLookup() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fx = FakeFXClient()

        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Netflix"
        draft.amountString = "15.49"
        draft.currency = "USD"

        let err = await AddSubscriptionSheet.submit(
            draft: draft,
            fxClient: fx,
            homeCurrency: "USD",
            context: context,
            onDismiss: { }
        )
        XCTAssertNil(err)
        XCTAssertEqual(fx.calls.count, 0, "no FX lookup needed when currencies match")

        let sub = try XCTUnwrap(SubscriptionRepository(context: context).fetchAll().first)
        XCTAssertNil(sub.exchangeRateToHome)
        XCTAssertNil(sub.homeCurrencyAtCreation)
    }

    @MainActor
    func test_submit_fxFailure_stillSavesWithoutRate() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let fx = FakeFXClient()
        fx.stubbedError = FXError.network("offline")

        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Netflix"
        draft.amountString = "15.49"
        draft.currency = "USD"

        let err = await AddSubscriptionSheet.submit(
            draft: draft,
            fxClient: fx,
            homeCurrency: "CNY",
            context: context,
            onDismiss: { }
        )
        XCTAssertNil(err, "FX failure must not block save")
        let sub = try XCTUnwrap(SubscriptionRepository(context: context).fetchAll().first)
        XCTAssertNil(sub.exchangeRateToHome, "no rate pinned on FX failure")
    }

    // MARK: - SubscriptionDetailView.convertedAmountText

    func test_convertedAmountText_renders_whenPinned() {
        let sub = makeSub(amount: 20, currency: "USD",
                           exchangeRateToHome: Decimal(string: "7.0")!,
                           homeCurrency: "CNY")
        // exchangeRateAsOf is set inside `makeSub` to .now — just assert structure.
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
