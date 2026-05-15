import Foundation
import UserNotifications

/// Production `NotificationCenterProtocol` implementation. Thin forwarder over
/// `UNUserNotificationCenter.current()` — no logic of its own, kept tiny so the
/// untestable surface area stays as small as possible.
final class SystemNotificationCenter: NotificationCenterProtocol {

    let underlying: UNUserNotificationCenter

    init(_ center: UNUserNotificationCenter = .current()) {
        self.underlying = center
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await underlying.requestAuthorization(options: options)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await underlying.pendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await underlying.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        underlying.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
