import Foundation
import UserNotifications

/// Narrow seam over `UNUserNotificationCenter`. The notification subsystem only
/// ever touches the methods declared here; the production wrapper forwards to
/// `UNUserNotificationCenter.current()`, and tests inject `FakeNotificationCenter`.
protocol NotificationCenterProtocol: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers: [String])
}
