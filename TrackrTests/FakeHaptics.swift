import Foundation
@testable import Trackr

/// In-memory `Haptics` stand-in for tests. Records every event so call sites
/// can assert "yes, the FAB tap triggered a `.light` impact" without actually
/// asking UIKit to vibrate the simulator.
final class FakeHaptics: Haptics {
    private(set) var events: [HapticEvent] = []

    func play(_ event: HapticEvent) {
        events.append(event)
    }
}
