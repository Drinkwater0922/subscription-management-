import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class SubscriptionRowSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func make(name: String, plan: String? = nil, amount: Decimal,
                      cycle: BillingCycle = .monthly, active: Bool = true) -> Subscription {
        Subscription(
            name: name,
            planName: plan,
            amount: amount,
            currency: "USD",
            billingCycle: cycle,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .streaming,
            isActive: active
        )
    }

    private func host(_ sub: Subscription) -> some View {
        SubscriptionRow(subscription: sub)
            .frame(width: 360, height: 72)
            .background(TrackrColors.bg)
    }

    func test_activeRow_render() {
        assertSnapshot(of: host(make(name: "Netflix", plan: "Standard", amount: 15.49)),
                       as: .image)
    }

    func test_pausedRow_render() {
        assertSnapshot(of: host(make(name: "Spotify", amount: 9.99, active: false)),
                       as: .image)
    }

    func test_customDaysCycle_render() {
        assertSnapshot(of: host(make(name: "Box60", amount: 30, cycle: .customDays(60))),
                       as: .image)
    }
}
