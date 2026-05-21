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

    override class func setUp() {
        super.setUp()
        // Force the entire test process — and via persisted UserDefaults the
        // simulator container itself — to resolve `String(localized:)`
        // lookups through the English (`en`) localization, regardless of the
        // host simulator's language. Without this, settings labels like
        // "RESTORE PURCHASES" render in zh-Hans on a Chinese sim and break
        // the App Store screenshot baselines.
        //
        // Side effect (intentional, do not "fix" with a tearDown): the
        // override persists across test invocations on the same simulator,
        // which keeps *every* snapshot test class in en regardless of order.
        // Adding a tearDown that restores the original value makes the rest
        // of the snapshot suite drift back to the sim's natural locale, and
        // their baselines (also recorded in en) start failing. If you ever
        // need an isolated zh-Hans render in this test bundle, do it under
        // a `withUserDefaults`-style scope inside a single test, not here.
        UserDefaults.standard.set(["en"],   forKey: "AppleLanguages")
        UserDefaults.standard.set("en_US",  forKey: "AppleLocale")
    }

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

    // 6.5" iPhone (e.g., iPhone 11 Pro Max / 14 Pro Max) — 428×926 points.
    // Renders at 3× to 1284×2778 px, which App Store Connect accepts for the
    // iPhone screenshot slot.
    private let storeFrameWidth: CGFloat = 428
    private let storeFrameHeight: CGFloat = 926

    private func mount<V: View>(_ view: V, proStatus: ProStatus = .free) async -> some View {
        let client = FakeStoreKitClient()
        client.currentResult = proStatus
        client.products = [
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$7.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        // Synchronously resolve the entitlement so gated features (Insights)
        // render their unlocked state on first render — `start()` reads from
        // the fake client + writes through to `current` before returning.
        await entitlement.start()
        return view
            .modelContainer(container)
            .environment(AppDeepLinkRouter())
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .frame(width: storeFrameWidth, height: storeFrameHeight)
            .preferredColorScheme(.dark)
            .environment(\.locale, Locale(identifier: "en_US"))
    }

    /// Wraps a raw screen mount in App Store-style marketing decoration:
    /// lime headline banner pinned to the bottom, the actual screen fills the
    /// canvas above. Bottom placement keeps the app's hero content (totals,
    /// first list rows, paywall feature list) fully visible. Total stays
    /// 430×932 so the PNG hits the App Store's exact 1290×2796 at 3×.
    private func decorated<Content: View>(
        headline: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let lime = Color(red: 204/255, green: 255/255, blue: 102/255)
        return ZStack(alignment: .bottom) {
            // Backdrop: actual screen at full canvas size.
            content()
                .frame(width: storeFrameWidth, height: storeFrameHeight)

            // Bottom banner.
            VStack(spacing: 0) {
                // Hairline seam so the banner reads as an intentional overlay
                // rather than a render glitch where the screen ends.
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)

                Text(headline)
                    .font(.custom("VT323", size: 40))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 56)
                    .frame(maxWidth: .infinity)
                    .background(lime)
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

    private let populatedSeed: [(name: String, presetId: String, category: Trackr.Category, amount: Decimal, cycle: BillingCycle, billing: Date)] = {
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        return [
            (name: "Netflix",         presetId: "netflix.standard",     category: .streaming,    amount: 15.49, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 1)),
            (name: "Spotify",         presetId: "spotify.premium",      category: .music,        amount: 10.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 3)),
            (name: "iCloud+",         presetId: "icloud.200",           category: .cloud,        amount:  2.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 5)),
            (name: "Dropbox",         presetId: "dropbox.plus",         category: .cloud,        amount:  9.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 8)),
            (name: "Notion",          presetId: "notion.plus",          category: .productivity, amount:     8, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 12)),
            (name: "YouTube Premium", presetId: "youtube.premium",      category: .streaming,    amount: 13.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 14)),
            (name: "HBO Max",         presetId: "hbomax.standard",      category: .streaming,    amount: 15.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 18)),
            (name: "1Password",       presetId: "1password.individual", category: .productivity, amount:  2.99, cycle: .monthly, billing: base.addingTimeInterval(86_400 * 22)),
        ]
    }()

    func test_store_insights() async throws {
        try seed(populatedSeed)
        // Persist Pro state so InsightsView renders the unlocked totals view.
        let settings = try SettingsRepository(context: container.mainContext).currentSettings()
        settings.proStatus = .proLifetime
        try container.mainContext.save()

        let inner = await mount(InsightsView(), proStatus: .proLifetime)
        let view = decorated(headline: "SEE WHERE\nYOUR MONEY GOES") { inner }
        assertSnapshot(of: view, as: .image)
    }

    func test_store_home_populated() async throws {
        try seed(populatedSeed)
        let inner = await mount(HomeView())
        let view = decorated(headline: "YOUR MONTHLY BILL\nAT A GLANCE") { inner }
        assertSnapshot(of: view, as: .image)
    }

    func test_store_detail() async throws {
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
        let inner = await mount(SubscriptionDetailView(subscription: sub))
        let view = decorated(headline: "NEVER MISS\nA RENEWAL") { inner }
        assertSnapshot(of: view, as: .image)
    }

    func test_store_paywall() async {
        let client = FakeStoreKitClient()
        client.products = [
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$7.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()
        let inner = PaywallView(reason: .subscriptionLimit)
            .modelContainer(container)
            .environment(entitlement)
            .frame(width: storeFrameWidth, height: storeFrameHeight)
            .preferredColorScheme(.dark)
            .environment(\.locale, Locale(identifier: "en_US"))
        let view = decorated(headline: "GO PRO ONCE.\nUNLOCK FOREVER.") { inner }
        assertSnapshot(of: view, as: .image)
    }

    func test_store_settings() async throws {
        let settings = try SettingsRepository(context: container.mainContext).currentSettings()
        settings.leadDays = [7, 3, 1]
        settings.notifyHour = 9
        try container.mainContext.save()
        let inner = await mount(SettingsView())
        let view = decorated(headline: "BUILT FOR\nTHE LONG HAUL") { inner }
        assertSnapshot(of: view, as: .image)
    }
}
