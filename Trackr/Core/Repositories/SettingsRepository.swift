import Foundation
import SwiftData

/// Singleton-by-convention access to the user's `UserSettings` row.
/// First call creates the row with spec defaults; subsequent calls return the same row.
@MainActor
struct SettingsRepository {
    let context: ModelContext

    func currentSettings() throws -> UserSettings {
        let existing = try context.fetch(FetchDescriptor<UserSettings>()).first
        if let existing { return existing }
        let fresh = UserSettings()
        context.insert(fresh)
        try context.save()
        return fresh
    }

    func save() throws {
        try context.save()
    }
}
