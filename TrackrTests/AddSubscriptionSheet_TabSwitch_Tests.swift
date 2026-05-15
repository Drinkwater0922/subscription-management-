import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class AddSubscriptionSheetTabSwitchTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_submitFromPreset_stampsPresetIdOnSubscription() async throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Netflix"
        draft.amountString = "15.49"

        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: "netflix.standard",
            context: container.mainContext,
            coordinator: nil,
            onDismiss: {}
        )
        XCTAssertNil(result)

        let saved = try SubscriptionRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(saved.first?.presetId, "netflix.standard")
    }

    func test_submitWithoutPreset_leavesPresetIdNil() async throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Manual"
        draft.amountString = "5"

        _ = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: nil,
            context: container.mainContext,
            coordinator: nil,
            onDismiss: {}
        )
        let saved = try SubscriptionRepository(context: container.mainContext).fetchAll()
        XCTAssertNil(saved.first?.presetId)
    }
}
