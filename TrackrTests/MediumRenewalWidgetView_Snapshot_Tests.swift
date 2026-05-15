import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class MediumRenewalWidgetViewSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func host(_ renewals: [UpcomingRenewal]) -> some View {
        MediumRenewalWidgetView(renewals: renewals)
            .frame(width: 338, height: 158)
            .background(TrackrColors.bg)
            .preferredColorScheme(.dark)
    }

    private func renewal(name: String, days: Int, amount: String) -> UpcomingRenewal {
        UpcomingRenewal(id: UUID(), name: name, displayAmount: amount,
                        daysUntil: days, nextBillingDate: .distantFuture)
    }

    func test_threeRenewals_render() {
        assertSnapshot(of: host([
            renewal(name: "Netflix", days: 3, amount: "$15.49"),
            renewal(name: "Spotify", days: 7, amount: "$10.99"),
            renewal(name: "iCloud",  days: 12, amount: "$0.99"),
        ]), as: .image)
    }

    func test_empty_render() {
        assertSnapshot(of: host([]), as: .image)
    }
}
