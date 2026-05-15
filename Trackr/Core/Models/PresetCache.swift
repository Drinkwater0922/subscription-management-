import Foundation
import SwiftData

/// Mirror of the remote `presets.json`. One row only.
/// `data` holds the raw JSON payload — parsing into typed `PresetItem` is done by
/// `PresetSync` (M5) so this model stays schema-agnostic.
@Model
final class PresetCache {
    var id: UUID
    var version: String
    var fetchedAt: Date
    var data: Data

    init(
        id: UUID = UUID(),
        version: String,
        fetchedAt: Date,
        data: Data
    ) {
        self.id = id
        self.version = version
        self.fetchedAt = fetchedAt
        self.data = data
    }
}
