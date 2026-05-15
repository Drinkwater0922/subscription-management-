import Foundation
import UserNotifications

/// Fires one immediate local notification per price-change alert — but only
/// when the user is on a Pro tier (`FeatureGate.pricePushNotifications`).
/// Free users still see the in-app banner from M5; this layer adds the push.
@MainActor
final class PriceChangePushPublisher {

    private let center: NotificationCenterProtocol

    init(center: NotificationCenterProtocol) {
        self.center = center
    }

    func publish(alerts: [PriceChangeAlert], proStatus: ProStatus) async throws {
        guard FeatureGate.isAllowed(.pricePushNotifications, given: proStatus) else { return }
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = "Price change"
            content.body = alert.messageEn
            content.sound = .default
            content.userInfo = ["presetId": alert.presetId]
            // No trigger → deliver immediately.
            let request = UNNotificationRequest(
                identifier: "trackr.price-change.\(alert.id.uuidString.lowercased())",
                content: content,
                trigger: nil
            )
            try await center.add(request)
        }
    }
}
