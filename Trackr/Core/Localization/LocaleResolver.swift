import Foundation

/// Maps `UserSettings.language` (a free-form string) to a concrete `Locale` so
/// SwiftUI can override the rendering locale at the app root.
///
/// Recognized values:
///   - `"auto"` → use the supplied system locale.
///   - `"en"`   → force English (`en_US`).
///   - `"zh-Hans"` → force Simplified Chinese (`zh-Hans_CN`).
///   - anything else → defer to system (defensive default).
enum LocaleResolver {
    static func resolve(languagePreference: String, systemLocale: Locale) -> Locale {
        switch languagePreference {
        case "en":      return Locale(identifier: "en_US")
        case "zh-Hans": return Locale(identifier: "zh-Hans_CN")
        default:        return systemLocale
        }
    }
}
