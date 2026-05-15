import Foundation

/// JSON envelope around `[PresetItem]`. `version` is a plain string —
/// `PresetSync` only compares it for equality, never parses semver.
struct PresetCatalog: Codable, Equatable {
    let version: String
    let items: [PresetItem]

    func item(withID id: String) -> PresetItem? {
        items.first { $0.id == id }
    }
}
