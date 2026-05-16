import Foundation

/// Coarse classification used for grouping in the preset library, the Add form
/// picker, the Detail screen, and the Insights breakdown.
///
/// **Declaration order matters** — `PresetLibraryView` iterates `Category.allCases`
/// to render its section list, so `.ai` is intentionally first.
enum Category: String, Codable, CaseIterable, Hashable {
    case ai
    case streaming
    case music
    case games
    case cloud
    case productivity
    case dev
    case news
    case fitness
    case learning
    case shopping
    case other

    /// Human-readable English label. zh-Hans localization deferred — call sites
    /// render this verbatim today.
    var displayName: String {
        switch self {
        case .ai:           return "AI"
        case .streaming:    return "Streaming"
        case .music:        return "Music"
        case .games:        return "Games"
        case .cloud:        return "Cloud"
        case .productivity: return "Productivity"
        case .dev:          return "Developer"
        case .news:         return "News"
        case .fitness:      return "Fitness"
        case .learning:     return "Learning"
        case .shopping:     return "Shopping"
        case .other:        return "Other"
        }
    }
}
