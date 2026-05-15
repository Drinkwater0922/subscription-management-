import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class PresetLibraryViewSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func items() throws -> [PresetItem] {
        try PresetBundleLoader.loadBundled().items
    }

    private func host(items: [PresetItem], query: String = "") -> some View {
        PresetLibraryView(items: items,
                          searchQuery: .constant(query),
                          onSelect: { _ in })
            .frame(width: 390, height: 700)
            .preferredColorScheme(.dark)
    }

    func test_fullList_render() throws {
        assertSnapshot(of: host(items: try items()), as: .image)
    }

    func test_searchFiltered_render() throws {
        assertSnapshot(of: host(items: try items(), query: "net"), as: .image)
    }
}
