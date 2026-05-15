import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class PaywallViewSnapshotTests: XCTestCase {

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

    private func host() -> some View {
        let client = FakeStoreKitClient()
        client.products = [
            ProProductDisplay(productID: ProProductID.monthly,  priceDisplay: "$2.99"),
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$29.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        return PaywallView(reason: .subscriptionLimit)
            .modelContainer(container)
            .environment(entitlement)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_paywall_render() {
        assertSnapshot(of: host(), as: .image)
    }
}
