import XCTest
@testable import Trackr

final class SubscriptionDraftTests: XCTestCase {

    private func validDraft() -> SubscriptionDraft {
        SubscriptionDraft(
            name: "Netflix",
            amountString: "9.99",
            currency: "USD",
            billingCycle: .monthly,
            customDays: 30,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .streaming
        )
    }

    func test_validDraft_validatesAndBuildsSubscription() throws {
        let draft = validDraft()
        let sub = try draft.makeSubscription()
        XCTAssertEqual(sub.name, "Netflix")
        XCTAssertEqual(sub.amount, Decimal(string: "9.99"))
        XCTAssertEqual(sub.currency, "USD")
        XCTAssertEqual(sub.billingCycle, .monthly)
        XCTAssertEqual(sub.category, .streaming)
    }

    func test_emptyName_isInvalid() {
        var draft = validDraft()
        draft.name = "   "
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .emptyName)
        }
    }

    func test_nonNumericAmount_isInvalid() {
        var draft = validDraft()
        draft.amountString = "abc"
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .invalidAmount)
        }
    }

    func test_negativeAmount_isInvalid() {
        var draft = validDraft()
        draft.amountString = "-5"
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .invalidAmount)
        }
    }

    func test_zeroAmount_isInvalid() {
        var draft = validDraft()
        draft.amountString = "0"
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .invalidAmount)
        }
    }

    func test_customCycle_usesCustomDays() throws {
        var draft = validDraft()
        draft.billingCycle = .customDays(1) // placeholder; struct should read customDays field
        draft.customDays = 45
        let sub = try draft.makeSubscription()
        XCTAssertEqual(sub.billingCycle, .customDays(45))
    }

    func test_customCycle_zeroDays_isInvalid() {
        var draft = validDraft()
        draft.billingCycle = .customDays(1)
        draft.customDays = 0
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .invalidCustomDays)
        }
    }

    func test_initialNextBillingDate_equalsStartDate() throws {
        let draft = validDraft()
        let sub = try draft.makeSubscription()
        XCTAssertEqual(sub.nextBillingDate, sub.startDate)
    }

    func test_initialEmpty_factoryHasSpecDefaults() {
        let empty = SubscriptionDraft.empty(defaultCurrency: "CNY")
        XCTAssertEqual(empty.currency, "CNY")
        XCTAssertEqual(empty.billingCycle, .monthly)
        XCTAssertEqual(empty.category, .other)
        XCTAssertTrue(empty.name.isEmpty)
        XCTAssertEqual(empty.amountString, "")
    }
}
