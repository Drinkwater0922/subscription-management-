import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class InsightsViewSnapshotTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func seed(_ subs: [(String, Decimal, BillingCycle)]) throws {
        for (name, amount, cycle) in subs {
            let sub = Subscription(
                name: name, amount: amount, currency: "USD",
                billingCycle: cycle,
                nextBillingDate: .distantFuture, startDate: .now,
                category: .streaming
            )
            container.mainContext.insert(sub)
        }
        try container.mainContext.save()
    }

    /// Seed a curated, multi-currency, multi-category set so the v1.2
    /// InsightsView exercises every block — hero, ranking, BY CATEGORY,
    /// BY CURRENCY. Fixed dates keep the snapshot stable across runs.
    private func seedMultiCurrencyV1_2() throws {
        let ctx = container.mainContext

        // Cached FX table: USD base, CNY at 8.0, EUR at 0.92.
        let rates: [String: Decimal] = [
            "CNY": Decimal(string: "8.0")!,
            "EUR": Decimal(string: "0.92")!,
        ]
        let data = try JSONEncoder().encode(rates)
        ctx.insert(FXRateTable(baseCurrency: "USD", ratesJSON: data,
                                fetchedAt: Date(timeIntervalSince1970: 1_780_000_000)))

        let now = Date(timeIntervalSince1970: 1_780_272_000)
        let mk: (String, Decimal, String, Trackr.Category, Int) -> Subscription
            = { name, amount, currency, category, daysOut in
                Subscription(
                    name: name, amount: amount, currency: currency,
                    billingCycle: .monthly,
                    nextBillingDate: now.addingTimeInterval(
                        TimeInterval(daysOut) * 86_400
                    ),
                    startDate: now, category: category
                )
            }

        ctx.insert(mk("Netflix",     15.49, "USD", .streaming, 3))
        ctx.insert(mk("Disney+",      9.99, "USD", .streaming, 14))
        ctx.insert(mk("Claude Pro",  20.00, "USD", .ai,         9))
        ctx.insert(mk("iCloud 200",   2.99, "USD", .cloud,      5))
        ctx.insert(mk("Notion",       8.00, "USD", .productivity, 18))
        ctx.insert(mk("网易云黑胶",     18.00, "CNY", .music,     22))
        try ctx.save()
    }

    func test_freeUser_showsPaywallStub() async throws {
        let client = FakeStoreKitClient()
        client.currentResult = .free
        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()
        let view = InsightsView()
            .modelContainer(container)
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            // v1.2 (C1): InsightsView reads the shared deep-link router so
            // SuspectRanking row taps can hand off to HomeView's Detail
            // sheet. Snapshot host must supply one or @Environment fatals.
            .environment(AppDeepLinkRouter())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    func test_proUser_showsTotals() async throws {
        try seed([
            ("Netflix", 15.49, .monthly),
            ("iCloud",   0.99, .monthly),
            ("AnnualThing", 120, .yearly),
        ])
        let client = FakeStoreKitClient()
        client.currentResult = .proLifetime
        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()
        let view = InsightsView()
            .modelContainer(container)
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            // v1.2 (C1): InsightsView reads the shared deep-link router so
            // SuspectRanking row taps can hand off to HomeView's Detail
            // sheet. Snapshot host must supply one or @Environment fatals.
            .environment(AppDeepLinkRouter())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    /// v1.2 C2: multi-currency populated state — exercises Hero (NEXT 30
    /// DAYS DUE), CurrencySwitcher, stat strip, suspect ranking, BY
    /// CATEGORY fill bars, and BY CURRENCY block (the latter only renders
    /// because seed has both USD and CNY subs, ≥2 currencies).
    func test_proUser_populatedMultiCurrency() async throws {
        try seedMultiCurrencyV1_2()
        let client = FakeStoreKitClient()
        client.currentResult = .proLifetime
        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()
        let view = InsightsView()
            .modelContainer(container)
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .environment(AppDeepLinkRouter())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    /// v1.2 C2: empty pro state — no subs, no rate table. Verifies the
    /// hero shows "NO CHARGES IN THE NEXT 30 DAYS", the ranking shows the
    /// empty-state copy, and the BY CATEGORY / BY CURRENCY blocks both
    /// hide (their `count >= 2` thresholds aren't met).
    func test_proUser_empty() async throws {
        let client = FakeStoreKitClient()
        client.currentResult = .proLifetime
        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()
        let view = InsightsView()
            .modelContainer(container)
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .environment(AppDeepLinkRouter())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }
}
