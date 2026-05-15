import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class SmallRenewalWidgetViewSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func host(_ renewal: UpcomingRenewal?) -> some View {
        SmallRenewalWidgetView(renewal: renewal)
            .frame(width: 158, height: 158)
            .background(TrackrColors.bg)
            .preferredColorScheme(.dark)
    }

    func test_withRenewal_render() {
        let renewal = UpcomingRenewal(
            id: UUID(),
            name: "Netflix",
            displayAmount: "$15.49",
            daysUntil: 3,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000)
        )
        assertSnapshot(of: host(renewal), as: .image)
    }

    func test_empty_render() {
        assertSnapshot(of: host(nil), as: .image)
    }
}
