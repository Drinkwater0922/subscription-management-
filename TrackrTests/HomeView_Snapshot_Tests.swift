import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class HomeViewSnapshotTests: XCTestCase {

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

    private func seed(_ subs: [Subscription]) throws {
        let ctx = container.mainContext
        for s in subs { ctx.insert(s) }
        try ctx.save()
    }

    private func host() -> some View {
        HomeView()
            .modelContainer(container)
            .environment(AppDeepLinkRouter())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_emptyState_render() {
        assertSnapshot(of: host(), as: .image)
    }

    func test_populated_render() throws {
        try seed([
            Subscription(name: "Netflix", amount: 15.49, currency: "USD",
                         billingCycle: .monthly,
                         nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
                         startDate: Date(timeIntervalSince1970: 1_700_000_000),
                         category: .media),
            Subscription(name: "iCloud", amount: 0.99, currency: "USD",
                         billingCycle: .monthly,
                         nextBillingDate: Date(timeIntervalSince1970: 1_760_000_000),
                         startDate: Date(timeIntervalSince1970: 1_700_000_000),
                         category: .cloud),
        ])
        assertSnapshot(of: host(), as: .image)
    }
}
