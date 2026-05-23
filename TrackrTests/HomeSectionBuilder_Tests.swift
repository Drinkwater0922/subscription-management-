import XCTest
@testable import Trackr

@MainActor
final class HomeSectionBuilderTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func sub(name: String,
                     trialEndsAt: Date? = nil,
                     nextBillingDate: Date? = nil,
                     active: Bool = true) -> Subscription {
        Subscription(
            name: name,
            amount: 10,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: nextBillingDate ?? now,
            startDate: now,
            category: .other,
            isActive: active,
            trialEndsAt: trialEndsAt
        )
    }

    // MARK: - Section presence

    func test_empty_input_returnsNoSections() {
        XCTAssertTrue(HomeSectionBuilder.build(from: [], now: now).isEmpty)
    }

    func test_onlyActive_omitsFreeTrialsSection() {
        let result = HomeSectionBuilder.build(from: [sub(name: "Netflix")], now: now)
        XCTAssertEqual(result.map(\.kind), [.active])
    }

    func test_onlyTrial_omitsActiveSection() {
        let trial = sub(name: "Spotify",
                        trialEndsAt: now.addingTimeInterval(60 * 60 * 24 * 3))
        let result = HomeSectionBuilder.build(from: [trial], now: now)
        XCTAssertEqual(result.map(\.kind), [.freeTrials])
    }

    func test_mixed_putsFreeTrialsFirst() {
        let trial = sub(name: "Spotify",
                        trialEndsAt: now.addingTimeInterval(60 * 60 * 24 * 3))
        let active = sub(name: "Netflix")
        let result = HomeSectionBuilder.build(from: [active, trial], now: now)
        XCTAssertEqual(result.map(\.kind), [.freeTrials, .active])
        XCTAssertEqual(result[0].items.map(\.name), ["Spotify"])
        XCTAssertEqual(result[1].items.map(\.name), ["Netflix"])
    }

    // MARK: - Trial expiry transitions

    func test_expiredTrial_flowsIntoActive() {
        let expired = sub(name: "Apple TV+",
                          trialEndsAt: now.addingTimeInterval(-60))
        let result = HomeSectionBuilder.build(from: [expired], now: now)
        XCTAssertEqual(result.map(\.kind), [.active],
                       "trial whose end has passed must move to ACTIVE")
    }

    func test_pausedTrial_doesNotShowInFreeTrials() {
        // A paused sub keeps its trial date but should NOT live in the
        // FREE TRIALS group — pause means "I don't want this in my face."
        let paused = sub(name: "Hulu",
                         trialEndsAt: now.addingTimeInterval(60 * 60 * 24),
                         active: false)
        let result = HomeSectionBuilder.build(from: [paused], now: now)
        XCTAssertEqual(result.map(\.kind), [.active])
        XCTAssertEqual(result.first?.items.map(\.name), ["Hulu"])
    }

    // MARK: - Sorting within sections

    func test_activeSection_sortsByNextBillingDate() {
        let s1 = sub(name: "Later",
                     nextBillingDate: now.addingTimeInterval(60 * 60 * 24 * 5))
        let s2 = sub(name: "Soon",
                     nextBillingDate: now.addingTimeInterval(60 * 60 * 24 * 2))
        let s3 = sub(name: "Today",
                     nextBillingDate: now)
        let result = HomeSectionBuilder.build(from: [s1, s2, s3], now: now)
        XCTAssertEqual(result.first?.items.map(\.name), ["Today", "Soon", "Later"])
    }

    func test_trialsSection_sortsByTrialEndsAt() {
        let day = TimeInterval(60 * 60 * 24)
        let t1 = sub(name: "EndsLater",
                     trialEndsAt: now.addingTimeInterval(day * 6))
        let t2 = sub(name: "EndsSoon",
                     trialEndsAt: now.addingTimeInterval(day * 2))
        let t3 = sub(name: "EndsTomorrow",
                     trialEndsAt: now.addingTimeInterval(day))
        let result = HomeSectionBuilder.build(from: [t1, t2, t3], now: now)
        XCTAssertEqual(result.first?.items.map(\.name),
                       ["EndsTomorrow", "EndsSoon", "EndsLater"])
    }

    // MARK: - Section titles

    func test_title_en() {
        XCTAssertEqual(HomeSectionBuilder.title(for: .freeTrials,
                                                locale: Locale(identifier: "en")),
                       "FREE TRIALS")
        XCTAssertEqual(HomeSectionBuilder.title(for: .active,
                                                locale: Locale(identifier: "en")),
                       "ACTIVE")
    }

    func test_title_zh() {
        XCTAssertEqual(HomeSectionBuilder.title(for: .freeTrials,
                                                locale: Locale(identifier: "zh-Hans")),
                       "免费试用")
        XCTAssertEqual(HomeSectionBuilder.title(for: .active,
                                                locale: Locale(identifier: "zh-Hans")),
                       "进行中")
    }
}
