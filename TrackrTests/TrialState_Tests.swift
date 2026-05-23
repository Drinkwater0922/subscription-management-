import XCTest
@testable import Trackr

/// Tests for the v1.1 free-trial concept on `Subscription`:
///   * `trialEndsAt` round-trips through `SubscriptionDraft`.
///   * `isTrial(at:)` honors the in-the-future / in-the-past boundary.
final class TrialStateTests: XCTestCase {

    private func makeDraft() -> SubscriptionDraft {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Spotify"
        draft.amountString = "9.99"
        draft.category = .music
        return draft
    }

    // MARK: - Draft round-trip

    func test_draft_withoutTrial_savesNil() throws {
        let sub = try makeDraft().makeSubscription()
        XCTAssertNil(sub.trialEndsAt)
    }

    func test_draft_withTrial_savesDate() throws {
        var draft = makeDraft()
        let when = Date(timeIntervalSince1970: 1_780_000_000)
        draft.trialEndsAt = when
        let sub = try draft.makeSubscription()
        XCTAssertEqual(sub.trialEndsAt, when)
    }

    // MARK: - isTrial gating

    func test_isTrial_nilDate_isFalse() {
        let sub = Subscription(name: "X", amount: 1, currency: "USD",
                                billingCycle: .monthly,
                                nextBillingDate: .now, startDate: .now,
                                category: .other)
        XCTAssertFalse(sub.isTrial())
    }

    func test_isTrial_futureDate_isTrue() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let later = now.addingTimeInterval(60 * 60 * 24 * 3)
        let sub = Subscription(name: "X", amount: 1, currency: "USD",
                                billingCycle: .monthly,
                                nextBillingDate: now, startDate: now,
                                category: .other,
                                trialEndsAt: later)
        XCTAssertTrue(sub.isTrial(at: now))
    }

    func test_isTrial_pastDate_isFalse() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let earlier = now.addingTimeInterval(-60 * 60 * 24)
        let sub = Subscription(name: "X", amount: 1, currency: "USD",
                                billingCycle: .monthly,
                                nextBillingDate: now, startDate: now,
                                category: .other,
                                trialEndsAt: earlier)
        XCTAssertFalse(sub.isTrial(at: now),
                       "expired trial should flow into ACTIVE, not stay in FREE TRIALS")
    }

    func test_isTrial_atExactBoundary_isFalse() {
        let when = Date(timeIntervalSince1970: 1_780_000_000)
        let sub = Subscription(name: "X", amount: 1, currency: "USD",
                                billingCycle: .monthly,
                                nextBillingDate: when, startDate: when,
                                category: .other,
                                trialEndsAt: when)
        XCTAssertFalse(sub.isTrial(at: when),
                       "trial that ends exactly now is no longer a trial")
    }
}
