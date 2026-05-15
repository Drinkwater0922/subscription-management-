import XCTest
@testable import Trackr

final class HapticsTests: XCTestCase {

    func test_fake_recordsEventsInOrder() {
        let fake = FakeHaptics()
        fake.play(.lightImpact)
        fake.play(.success)
        fake.play(.warning)
        XCTAssertEqual(fake.events, [.lightImpact, .success, .warning])
    }

    @MainActor
    func test_systemHaptics_constructsWithoutCrashing() {
        // The real generator can't be exercised in unit tests (UIKit binding),
        // but constructing it must not crash on the simulator.
        _ = SystemHaptics()
    }
}
