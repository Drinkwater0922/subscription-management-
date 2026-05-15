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
}
