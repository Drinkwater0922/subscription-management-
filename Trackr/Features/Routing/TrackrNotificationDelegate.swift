import Foundation
import UserNotifications

/// Catches notification taps and forwards the target subscription UUID into the
/// shared `AppDeepLinkRouter` so SwiftUI can react.
@MainActor
final class TrackrNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    let router: AppDeepLinkRouter

    init(router: AppDeepLinkRouter) {
        self.router = router
    }

    // Foreground presentation: show the banner + play sound.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completion([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completion: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let raw = userInfo["subscriptionID"] as? String, let uuid = UUID(uuidString: raw) {
            Task { @MainActor in
                router.requestOpen(subscriptionID: uuid)
                completion()
            }
        } else {
            completion()
        }
    }
}
