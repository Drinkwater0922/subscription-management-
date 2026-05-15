import Foundation

/// Coarse classification used for grouping and Insights breakdown.
enum Category: String, Codable, CaseIterable, Hashable {
    case ai
    case dev
    case media
    case cloud
    case productivity
    case other

    /// Human-readable English label. Localization comes in M8 via `LocalizedStringKey`.
    var displayName: String {
        switch self {
        case .ai:           return "AI"
        case .dev:          return "Developer"
        case .media:        return "Media"
        case .cloud:        return "Cloud"
        case .productivity: return "Productivity"
        case .other:        return "Other"
        }
    }
}
