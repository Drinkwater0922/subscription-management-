import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

/// Renders five App Store hero scenes at iPhone 6.7" frame size (430×932
/// points). The snapshot library writes them to
/// `TrackrTests/__Snapshots__/StoreScreenshots_Tests/` at 3× density
/// (1290×2796 px) — the exact resolution App Store Connect demands for the
/// 6.7" iPhone screenshot set.
///
/// These tests record on first run via `record: .missing`; subsequent runs
/// verify the baselines. When marketing copy / screen layout changes, delete
/// the baselines and re-record.
@MainActor
final class StoreScreenshotsTests: XCTestCase {

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

    // 6.7" iPhone (e.g., iPhone 16 Pro Max) — 430×932 points.
    private let storeFrameWidth: CGFloat = 430
    private let storeFrameHeight: CGFloat = 932

    private func mount<V: View>(_ view: V) -> some View {
        let client = FakeStoreKitClient()
        client.products = [
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$7.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        return view
            .modelContainer(container)
            .environment(AppDeepLinkRouter())
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .frame(width: storeFrameWidth, height: storeFrameHeight)
            .preferredColorScheme(.dark)
    }

    private func seed(_ rows: [(String, Decimal, BillingCycle, Date)]) throws {
        for (name, amount, cycle, billing) in rows {
            let sub = Subscription(
                name: name,
                amount: amount, currency: "USD",
                billingCycle: cycle,
                nextBillingDate: billing,
                startDate: Date(timeIntervalSince1970: 1_700_000_000),
                category: .streaming
            )
            container.mainContext.insert(sub)
        }
        try container.mainContext.save()
    }

    func test_store_home_empty() {
        assertSnapshot(of: mount(HomeView()), as: .image)
    }

    func test_store_home_populated() throws {
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        try seed([
            ("Netflix", 15.49, .monthly, base.addingTimeInterval(86_400 * 3)),
            ("Spotify", 10.99, .monthly, base.addingTimeInterval(86_400 * 7)),
            ("iCloud+", 0.99,  .monthly, base.addingTimeInterval(86_400 * 12)),
            ("ChatGPT Plus", 20, .monthly, base.addingTimeInterval(86_400 * 19)),
        ])
        assertSnapshot(of: mount(HomeView()), as: .image)
    }

    func test_store_detail() throws {
        let sub = Subscription(
            name: "Notion", planName: "Personal Pro",
            amount: 8, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .productivity,
            notes: "Switched from the team plan in June."
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()
        assertSnapshot(of: mount(SubscriptionDetailView(subscription: sub)),
                       as: .image)
    }

    func test_store_paywall() async {
        let client = FakeStoreKitClient()
        client.products = [
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$7.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        let view = PaywallView(reason: .subscriptionLimit)
            .modelContainer(container)
            .environment(entitlement)
            .frame(width: storeFrameWidth, height: storeFrameHeight)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    func test_store_settings() throws {
        let settings = try SettingsRepository(context: container.mainContext).currentSettings()
        settings.leadDays = [7, 3, 1]
        settings.notifyHour = 9
        try container.mainContext.save()
        assertSnapshot(of: mount(SettingsView()), as: .image)
    }
}
