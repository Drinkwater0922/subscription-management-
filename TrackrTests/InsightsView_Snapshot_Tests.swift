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
                category: .media
            )
            container.mainContext.insert(sub)
        }
        try container.mainContext.save()
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
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }
}
