import Foundation
import UserNotifications
@testable import Trackr

/// In-memory stand-in for `UNUserNotificationCenter`. The scheduler talks to
/// `NotificationCenterProtocol` so tests can inject this and assert on
/// `addedRequests` / `removedIdentifiers` directly.
final class FakeNotificationCenter: NotificationCenterProtocol {

    var authorizationResult: Bool = true
    var requestedOptions: UNAuthorizationOptions?
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var pendingRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions = options
        return authorizationResult
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        removedIdentifiers.append(contentsOf: ids)
        pendingRequests.removeAll { ids.contains($0.identifier) }
    }
}
