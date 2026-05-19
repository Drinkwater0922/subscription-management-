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

    /// Wraps a raw screen mount in App Store-style marketing decoration:
    /// lime headline banner pinned to the top, the screen fills the rest of
    /// the canvas. Total stays 430×932 so the PNG hits the App Store's exact
    /// 1290×2796 spec at 3× scale.
    private func decorated<Content: View>(
        headline: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let lime = Color(red: 204/255, green: 255/255, blue: 102/255)
        return ZStack(alignment: .top) {
            // Backdrop: actual screen at full canvas size.
            content()
                .frame(width: storeFrameWidth, height: storeFrameHeight)

            // Top banner: lime block with VT323 headline. Overlays the app's
            // own status-bar area — standard practice for marketing shots.
            VStack(spacing: 0) {
                Text(headline)
                    .font(.custom("VT323", size: 42))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .padding(.top, 64)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                    .background(lime)

                // Hairline seam so the banner reads as an intentional overlay
                // rather than a render glitch.
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
            }
        }
        .frame(width: storeFrameWidth, height: storeFrameHeight)
    }

    private func seed(_ rows: [(name: String, presetId: String, category: Trackr.Category, amount: Decimal, cycle: BillingCycle, billing: Date)]) throws {
        for row in rows {
            let sub = Subscription(
                name: row.name,
                amount: row.amount, currency: "USD",
                billingCycle: row.cycle,
                nextBillingDate: row.billing,
                startDate: Date(timeIntervalSince1970: 1_700_000_000),
                category: row.category,
                presetId: row.presetId
            )
            container.mainContext.insert(sub)
        }
        try container.mainContext.save()
    }

    func test_store_home_empty() {
        let view = decorated(headline: "EVERY SUBSCRIPTION\nIN ONE PLACE") {
            mount(HomeView())
        }
        assertSnapshot(of: view, as: .image)
    }

    func test_store_home_populated() throws {
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        try seed([
            (name: "Netflix",         presetId: "netflix.standard",     category: .streaming,    amount: 15.49, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 1)),
            (name: "Spotify",         presetId: "spotify.premium",      category: .music,        amount: 10.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 3)),
            (name: "iCloud+",         presetId: "icloud.200",           category: .cloud,        amount:  2.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 5)),
            (name: "ChatGPT Plus",    presetId: "chatgpt.plus",         category: .ai,           amount:    20, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 8)),
            (name: "Notion",          presetId: "notion.plus",          category: .productivity, amount:     8, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 12)),
            (name: "YouTube Premium", presetId: "youtube.premium",      category: .streaming,    amount: 13.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 14)),
            (name: "HBO Max",         presetId: "hbomax.standard",      category: .streaming,    amount: 15.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 18)),
            (name: "1Password",       presetId: "1password.individual", category: .productivity, amount:  2.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 22)),
        ])
        let view = decorated(headline: "YOUR MONTHLY BILL\nAT A GLANCE") {
            mount(HomeView())
        }
        assertSnapshot(of: view, as: .image)
    }

    func test_store_detail() throws {
        let sub = Subscription(
            name: "Notion", planName: "Personal Pro",
            amount: 8, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .productivity,
            notes: "Switched from the team plan in June.",
            presetId: "notion.plus"
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()
        let view = decorated(headline: "NEVER MISS\nA RENEWAL") {
            mount(SubscriptionDetailView(subscription: sub))
        }
        assertSnapshot(of: view, as: .image)
    }

    func test_store_paywall() async {
        let client = FakeStoreKitClient()
        client.products = [
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$7.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        let view = decorated(headline: "GO PRO ONCE.\nUNLOCK FOREVER.") {
            PaywallView(reason: .subscriptionLimit)
                .modelContainer(container)
                .environment(entitlement)
                .frame(width: storeFrameWidth, height: storeFrameHeight)
                .preferredColorScheme(.dark)
        }
        assertSnapshot(of: view, as: .image)
    }

    func test_store_settings() throws {
        let settings = try SettingsRepository(context: container.mainContext).currentSettings()
        settings.leadDays = [7, 3, 1]
        settings.notifyHour = 9
        try container.mainContext.save()
        let view = decorated(headline: "BUILT FOR\nTHE LONG HAUL") {
            mount(SettingsView())
        }
        assertSnapshot(of: view, as: .image)
    }
}
