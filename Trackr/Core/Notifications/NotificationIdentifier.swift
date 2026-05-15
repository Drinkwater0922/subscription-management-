import Foundation

/// Stable identifier strategy for Trackr's local notifications. The `trackr.`
/// prefix lets the scheduler distinguish its own requests from anything else
/// running in the same process (a future widget refresh, etc.) when it cancels
/// in bulk during `refresh()`.
enum NotificationIdentifier {

    static func perSubscription(subscriptionID: UUID, leadDay: Int) -> String {
        "trackr.sub.\(subscriptionID.uuidString.lowercased()).lead.\(leadDay)"
    }

    static func aggregate(fireDay: Date, leadDay: Int) -> String {
        "trackr.aggregate.\(dayFormatter.string(from: fireDay)).lead.\(leadDay)"
    }

    static func isTrackrIdentifier(_ id: String) -> Bool {
        id.hasPrefix("trackr.")
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
