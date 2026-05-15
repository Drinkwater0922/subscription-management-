import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class RenewalEventTests: XCTestCase {

    func test_canBeInsertedAndFetched() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let subId = UUID()
        let event = RenewalEvent(
            subscriptionId: subId,
            date: .now,
            amount: 20,
            currency: "USD",
            status: .scheduled
        )
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RenewalEvent>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.subscriptionId, subId)
        XCTAssertEqual(fetched.first?.status, .scheduled)
        XCTAssertEqual(fetched.first?.amount, 20)
    }
}
