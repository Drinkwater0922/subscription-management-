import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The four flavors of feedback Trackr uses. Add cases here as new
/// interactions need haptics — never call UIKit generators directly.
enum HapticEvent: Equatable {
    case lightImpact     // FAB tap, picker change
    case mediumImpact    // sheet present
    case success         // save succeeded
    case warning         // gate trip (limit hit, validation error)
}

/// Narrow seam over UIKit's feedback generators. Tests inject `FakeHaptics`;
/// the SwiftUI views consume this protocol via `@Environment(\.haptics)`.
protocol Haptics: AnyObject {
    func play(_ event: HapticEvent)
}

/// Production `Haptics` implementation. Lazily holds the three generator
/// types — `prepare()` warms them on first call so the response feels snappy.
@MainActor
final class SystemHaptics: Haptics {

    #if canImport(UIKit)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    init() {
        #if canImport(UIKit)
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
        #endif
    }

    nonisolated func play(_ event: HapticEvent) {
        Task { @MainActor in
            #if canImport(UIKit)
            switch event {
            case .lightImpact:  lightImpact.impactOccurred()
            case .mediumImpact: mediumImpact.impactOccurred()
            case .success:      notification.notificationOccurred(.success)
            case .warning:      notification.notificationOccurred(.warning)
            }
            #endif
        }
    }
}
