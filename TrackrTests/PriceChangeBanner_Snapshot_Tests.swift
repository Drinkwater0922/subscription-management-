import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class PriceChangeBannerSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    func test_priceIncrease_render() {
        let banner = PriceChangeBanner(
            message: "Netflix raised its Standard price from $15.49 to $17.99.",
            onDismiss: {}
        )
        .frame(width: 360, height: 80)
        .preferredColorScheme(.dark)
        assertSnapshot(of: banner, as: .image)
    }
}
