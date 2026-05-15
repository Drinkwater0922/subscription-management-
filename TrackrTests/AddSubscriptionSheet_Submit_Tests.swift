import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class AddSubscriptionSheetSubmitTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_submit_validDraft_insertsRow() async throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "ChatGPT Plus"
        draft.amountString = "20"
        draft.category = .ai

        var dismissed = false
        let result = await AddSubscriptionSheet.submit(draft: draft,
                                                       context: container.mainContext,
                                                       coordinator: nil,
                                                       onDismiss: { dismissed = true })

        XCTAssertNil(result, "submit should return nil error on success")
        XCTAssertTrue(dismissed)
        let all = try SubscriptionRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(all.map(\.name), ["ChatGPT Plus"])
        XCTAssertEqual(all.first?.amount, 20)
        XCTAssertEqual(all.first?.category, .ai)
    }

    func test_submit_invalidDraft_returnsErrorAndDoesNotInsert() async throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = ""   // invalid

        var dismissed = false
        let result = await AddSubscriptionSheet.submit(draft: draft,
                                                       context: container.mainContext,
                                                       coordinator: nil,
                                                       onDismiss: { dismissed = true })

        XCTAssertNotNil(result)
        XCTAssertFalse(dismissed)
        let count = try SubscriptionRepository(context: container.mainContext).count()
        XCTAssertEqual(count, 0)
    }
}
