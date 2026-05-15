import Foundation
import SwiftData

/// User-tunable app settings. One row only — enforced by `SettingsRepository`,
/// not at the schema level (SwiftData has no singleton constraint).
@Model
final class UserSettings {
    var id: UUID
    var defaultCurrency: String
    /// Days before `nextBillingDate` to fire local notifications. Default [3, 1].
    var leadDays: [Int]
    /// Hour (0–23) at which notifications fire in the user's local timezone.
    var notifyHour: Int
    /// "auto" | "en" | "zh-Hans". M8 wires this into the localization layer.
    var language: String
    var biometricLockEnabled: Bool
    var proStatus: ProStatus
    var proExpiresAt: Date?
    var onboardingCompletedAt: Date?

    init(
        id: UUID = UUID(),
        defaultCurrency: String = "USD",
        leadDays: [Int] = [3, 1],
        notifyHour: Int = 9,
        language: String = "auto",
        biometricLockEnabled: Bool = false,
        proStatus: ProStatus = .free,
        proExpiresAt: Date? = nil,
        onboardingCompletedAt: Date? = nil
    ) {
        self.id = id
        self.defaultCurrency = defaultCurrency
        self.leadDays = leadDays
        self.notifyHour = notifyHour
        self.language = language
        self.biometricLockEnabled = biometricLockEnabled
        self.proStatus = proStatus
        self.proExpiresAt = proExpiresAt
        self.onboardingCompletedAt = onboardingCompletedAt
    }
}
