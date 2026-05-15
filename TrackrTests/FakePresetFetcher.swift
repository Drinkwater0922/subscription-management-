import Foundation
@testable import Trackr

/// In-memory `PresetFetcher` for tests. Set `result` to the catalog you want
/// returned (or `error` to throw). `fetchCallCount` is captured for assertion.
final class FakePresetFetcher: PresetFetcher {

    var result: PresetCatalog?
    var error: Error?
    private(set) var fetchCallCount = 0

    func fetch() async throws -> PresetCatalog {
        fetchCallCount += 1
        if let error { throw error }
        guard let result else {
            struct Unconfigured: Error {}
            throw Unconfigured()
        }
        return result
    }
}
