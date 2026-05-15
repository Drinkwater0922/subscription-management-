import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class PresetCacheTests: XCTestCase {

    func test_canBeInsertedAndFetched() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let payload = Data("{\"version\":\"2026.05.15\"}".utf8)
        let cache = PresetCache(
            version: "2026.05.15",
            fetchedAt: Date(timeIntervalSince1970: 1_750_000_000),
            data: payload
        )
        context.insert(cache)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PresetCache>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.version, "2026.05.15")
        XCTAssertEqual(fetched.first?.data, payload)
    }
}
