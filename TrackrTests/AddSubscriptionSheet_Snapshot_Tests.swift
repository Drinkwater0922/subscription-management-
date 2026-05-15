import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class AddSubscriptionSheetSnapshotTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func host(initial: SubscriptionDraft = .empty(defaultCurrency: "USD")) -> some View {
        let entitlement = ProEntitlement(client: FakeStoreKitClient(), container: container)
        return AddSubscriptionSheet(initialDraft: initial)
            .modelContainer(container)
            .environment(entitlement)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_emptyForm_render() {
        assertSnapshot(of: host(), as: .image)
    }

    func test_filledForm_render() {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Notion"
        draft.amountString = "8.00"
        draft.category = .productivity
        draft.planName = "Personal Pro"
        assertSnapshot(of: host(initial: draft), as: .image)
    }
}
