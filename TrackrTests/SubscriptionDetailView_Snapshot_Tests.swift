import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionDetailViewSnapshotTests: XCTestCase {

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

    private func seedAndHost(active: Bool) -> some View {
        let sub = Subscription(
            name: "Notion",
            planName: "Personal Pro",
            amount: 8,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .productivity,
            notes: "Annual savings option later",
            isActive: active
        )
        container.mainContext.insert(sub)
        try? container.mainContext.save()
        return SubscriptionDetailView(subscription: sub)
            .modelContainer(container)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_active_render() {
        assertSnapshot(of: seedAndHost(active: true), as: .image)
    }

    func test_paused_render() {
        assertSnapshot(of: seedAndHost(active: false), as: .image)
    }

    func test_priceChangeBanner_render() throws {
        let sub = Subscription(
            name: "Netflix",
            planName: "Standard",
            amount: 17.99,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .media,
            presetId: "netflix.standard"
        )
        container.mainContext.insert(sub)
        let alert = PriceChangeAlert(
            presetId: "netflix.standard",
            planKey: "Standard",
            oldAmount: 15.49,
            newAmount: 17.99,
            currency: "USD",
            effectiveDate: Date(timeIntervalSince1970: 1_750_000_000),
            messageEn: "Netflix raised its Standard price from $15.49 to $17.99.",
            messageZh: "Netflix Standard 价格已上调，由 $15.49 变为 $17.99。"
        )
        container.mainContext.insert(alert)
        try container.mainContext.save()

        let host = SubscriptionDetailView(subscription: sub)
            .modelContainer(container)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: host, as: .image)
    }
}
