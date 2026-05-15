import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class OnboardingViewSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    func test_brandPage_render() {
        let view = OnboardingBrandPage()
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    func test_valuePage_render() {
        let view = OnboardingValuePage()
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    func test_permissionPage_render() {
        let view = OnboardingPermissionPage(onEnable: {}, onSkip: {})
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }
}
