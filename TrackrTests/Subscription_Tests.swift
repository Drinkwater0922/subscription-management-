import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionTests: XCTestCase {

    func test_canBeInsertedIntoInMemoryContainerAndFetched() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let sub = Subscription(
            name: "AI Chat Pro",
            amount: 20,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_730_000_000),
            category: .ai
        )
        context.insert(sub)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Subscription>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "AI Chat Pro")
        XCTAssertEqual(fetched.first?.billingCycle, .monthly)
        XCTAssertEqual(fetched.first?.category, .ai)
        XCTAssertEqual(fetched.first?.amount, 20)
    }

    func test_defaultValuesAreSetOnInit() throws {
        let sub = Subscription(
            name: "X",
            amount: 1,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture,
            startDate: .now,
            category: .other
        )
        XCTAssertTrue(sub.isActive)
        XCTAssertNil(sub.planName)
        XCTAssertNil(sub.notes)
        XCTAssertNil(sub.url)
        XCTAssertNil(sub.presetId)
        XCTAssertNil(sub.paymentMethod)
        XCTAssertNil(sub.pausedUntil)
    }

    func test_iconRefDefaultsToCustomQuestionMark() throws {
        let sub = Subscription(
            name: "X",
            amount: 1,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture,
            startDate: .now,
            category: .other
        )
        XCTAssertEqual(sub.iconRef, "custom:emoji:❓")
    }
}

// Temporary helper — superseded by Task 7's ModelContainerConfig.
// Update the `for:` list as each subsequent @Model task lands.

func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Subscription.self, RenewalEvent.self, PriceChangeAlert.self,
        configurations: config
    )
}
