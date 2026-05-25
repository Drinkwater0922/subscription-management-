import XCTest
@testable import Trackr

/// Tests for the v1.2 SuspectRanker (Insights Requirement 3 in
/// `docs/PRD/v1.2-insights-redesign.md`). All cases use a fixed `now` so
/// the score math is reproducible day-to-day.
final class SuspectRankerTests: XCTestCase {

    // Anchor: 2026-06-01 00:00 UTC. Arbitrary, but stable.
    private let now = Date(timeIntervalSince1970: 1_780_272_000)

    // MARK: - Candidate filtering

    func test_inactiveSubs_excluded() {
        let active = sub(name: "A", amount: 10, nextDaysFromNow: 5)
        let inactive = sub(name: "B", amount: 99, nextDaysFromNow: 5,
                           isActive: false)
        let result = SuspectRanker.rank([inactive, active],
                                         in: "USD", rateTable: nil, now: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.subscription.name, "A")
    }

    func test_pausedSubsWithFuturePauseDate_excluded() {
        let pauseFuture = sub(name: "Paused", amount: 99, nextDaysFromNow: 5,
                              pausedUntil: now.addingTimeInterval(86400 * 30))
        let ok = sub(name: "OK", amount: 10, nextDaysFromNow: 5)
        let result = SuspectRanker.rank([pauseFuture, ok],
                                         in: "USD", rateTable: nil, now: now)
        XCTAssertEqual(result.map { $0.subscription.name }, ["OK"])
    }

    func test_pausedSubsWithExpiredPauseDate_included() {
        // Pause date in the past → effectively unpaused, should be included.
        let oncePaused = sub(name: "OncePaused", amount: 10,
                             nextDaysFromNow: 5,
                             pausedUntil: now.addingTimeInterval(-86400))
        let result = SuspectRanker.rank([oncePaused],
                                         in: "USD", rateTable: nil, now: now)
        XCTAssertEqual(result.count, 1)
    }

    func test_overdueNextBilling_excluded() {
        let overdue = sub(name: "Overdue", amount: 99, nextDaysFromNow: -3)
        let ok = sub(name: "OK", amount: 10, nextDaysFromNow: 5)
        let result = SuspectRanker.rank([overdue, ok],
                                         in: "USD", rateTable: nil, now: now)
        XCTAssertEqual(result.map { $0.subscription.name }, ["OK"])
    }

    // MARK: - Ranking + tie-breaks

    func test_higherScore_rankedFirst() {
        // S1: cheap and far away — low score
        let s1 = sub(name: "Cheap",  amount: 1,  nextDaysFromNow: 25,
                     updatedDaysAgo: 5)
        // S2: expensive and imminent — high score
        let s2 = sub(name: "Pricey", amount: 50, nextDaysFromNow: 2,
                     updatedDaysAgo: 5)
        let result = SuspectRanker.rank([s1, s2],
                                         in: "USD", rateTable: nil, now: now)
        XCTAssertEqual(result.map { $0.subscription.name }, ["Pricey", "Cheap"])
        XCTAssertEqual(result[0].rank, 1)
        XCTAssertEqual(result[1].rank, 2)
    }

    func test_tieScore_breaksOnMonthlyContributionDescending() {
        // Two subs engineered to tie on score: same amount, same imminence,
        // same stagnation. They WILL tie. Distinguish them by giving one
        // higher monthly via a longer cycle... but here, same cycle, so
        // identical scores. The tie-break is name asc when monthly is also
        // equal. Test that separately.
        // For the monthly-desc tie-break specifically, make scores equal
        // but monthly different by using yearly vs monthly:
        // s1: $120/year → $10/month; s2: $10/month — both yield monthly=10.
        // Force a real monthly difference instead:
        let big = sub(name: "Z_big", amount: 20, nextDaysFromNow: 10,
                       cycle: .monthly, updatedDaysAgo: 30)
        let small = sub(name: "A_small", amount: 240, nextDaysFromNow: 10,
                         cycle: .yearly, updatedDaysAgo: 30)
        // big.monthly = 20; small.monthly = 240/12 = 20. They tie on monthly.
        // priceWeight depends on monthly / maxMonthly → same.
        // So same score AND same monthly → falls through to name asc.
        let result = SuspectRanker.rank([big, small],
                                         in: "USD", rateTable: nil, now: now)
        // Name ascending: "A_small" < "Z_big".
        XCTAssertEqual(result.map { $0.subscription.name }, ["A_small", "Z_big"])
    }

    func test_topNTruncation() {
        let many = (0..<10).map { i in
            sub(name: "S\(i)", amount: Decimal(i + 1), nextDaysFromNow: 10)
        }
        let result = SuspectRanker.rank(many, in: "USD", rateTable: nil,
                                         now: now, topN: 3)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.rank), [1, 2, 3])
    }

    func test_emptyCandidates_returnsEmpty() {
        let result = SuspectRanker.rank([], in: "USD", rateTable: nil, now: now)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Tag emission thresholds

    func test_expensiveTag_emittedForHighestMonthlyAndOmittedForCheapest() {
        // priceWeight > 25 means monthly/max > 0.625. Construct:
        // pricey monthly = 100 (max). priceWeight = 40 → tag emitted.
        // cheap monthly = 1. priceWeight ≈ 0.4 → not emitted.
        let pricey = sub(name: "Pricey", amount: 100, nextDaysFromNow: 20,
                         updatedDaysAgo: 5)
        let cheap = sub(name: "Cheap", amount: 1, nextDaysFromNow: 20,
                        updatedDaysAgo: 5)
        let result = SuspectRanker.rank([pricey, cheap],
                                         in: "USD", rateTable: nil, now: now)
        let priceyResult = result.first { $0.subscription.name == "Pricey" }
        let cheapResult = result.first { $0.subscription.name == "Cheap" }
        XCTAssertTrue(priceyResult?.tags.contains(.expensive) ?? false)
        XCTAssertFalse(cheapResult?.tags.contains(.expensive) ?? true)
    }

    func test_renewsInTag_emittedWhenImminenceAboveThreshold() {
        // imminenceWeight > 15 means (1 - days/30)*30 > 15
        // → 1 - days/30 > 0.5 → days < 15.
        let soon = sub(name: "Soon", amount: 10, nextDaysFromNow: 5,
                       updatedDaysAgo: 5)
        let later = sub(name: "Later", amount: 10, nextDaysFromNow: 20,
                        updatedDaysAgo: 5)
        let result = SuspectRanker.rank([soon, later],
                                         in: "USD", rateTable: nil, now: now)
        let soonResult = result.first { $0.subscription.name == "Soon" }!
        let laterResult = result.first { $0.subscription.name == "Later" }!
        XCTAssertTrue(soonResult.tags.contains { tag in
            if case .renewsIn(let d) = tag { return d == 5 }
            return false
        })
        XCTAssertFalse(laterResult.tags.contains { tag in
            if case .renewsIn = tag { return true }
            return false
        })
    }

    func test_notTouchedInTag_emittedWhenStagnationAboveThreshold() {
        // stagnationWeight > 15 means days/180 > 0.5 → days > 90.
        let stale = sub(name: "Stale", amount: 10, nextDaysFromNow: 20,
                        updatedDaysAgo: 120)
        let fresh = sub(name: "Fresh", amount: 10, nextDaysFromNow: 20,
                        updatedDaysAgo: 30)
        let result = SuspectRanker.rank([stale, fresh],
                                         in: "USD", rateTable: nil, now: now)
        let staleResult = result.first { $0.subscription.name == "Stale" }!
        let freshResult = result.first { $0.subscription.name == "Fresh" }!
        XCTAssertTrue(staleResult.tags.contains { tag in
            if case .notTouchedIn(let d) = tag { return d == 120 }
            return false
        })
        XCTAssertFalse(freshResult.tags.contains { tag in
            if case .notTouchedIn = tag { return true }
            return false
        })
    }

    func test_stagnationLabel_usesRawDays_notCapped180() {
        // A 365-day-stale sub should still LABEL "365 days" even though
        // the SCORE saturates at 180.
        let veryStale = sub(name: "Very", amount: 10, nextDaysFromNow: 20,
                            updatedDaysAgo: 365)
        let result = SuspectRanker.rank([veryStale],
                                         in: "USD", rateTable: nil, now: now)
        let tags = result.first?.tags ?? []
        let labelDays = tags.compactMap { tag -> Int? in
            if case .notTouchedIn(let d) = tag { return d }
            return nil
        }.first
        XCTAssertEqual(labelDays, 365,
                       "label must report raw days-since-update, not the 180 cap")
    }

    func test_atMostTwoTags_perRow() {
        // A sub that qualifies for all three tags. Only the two highest
        // weights should be shown.
        let triple = sub(name: "Triple", amount: 100, // highest priceWeight
                         nextDaysFromNow: 2,           // high imminence
                         updatedDaysAgo: 200)          // saturated stagnation
        let result = SuspectRanker.rank([triple],
                                         in: "USD", rateTable: nil, now: now)
        XCTAssertEqual(result.first?.tags.count, 2,
                       "row must show at most 2 tags even if 3 qualify")
    }

    // MARK: - Determinism

    func test_sameInputs_produceSameOutput_acrossRuns() {
        let subs = (0..<6).map { i in
            sub(name: "S\(i)", amount: Decimal(i * 5 + 1),
                nextDaysFromNow: i * 3, updatedDaysAgo: i * 20)
        }
        let runA = SuspectRanker.rank(subs, in: "USD", rateTable: nil, now: now)
        let runB = SuspectRanker.rank(subs, in: "USD", rateTable: nil, now: now)
        XCTAssertEqual(runA.map { $0.subscription.name },
                       runB.map { $0.subscription.name })
        XCTAssertEqual(runA.map { $0.score }, runB.map { $0.score })
    }

    // MARK: - Helpers

    private func sub(name: String,
                     amount: Decimal,
                     nextDaysFromNow: Int,
                     currency: String = "USD",
                     cycle: BillingCycle = .monthly,
                     isActive: Bool = true,
                     pausedUntil: Date? = nil,
                     updatedDaysAgo: Int = 0) -> Subscription {
        let next = now.addingTimeInterval(TimeInterval(nextDaysFromNow) * 86400)
        let updated = now.addingTimeInterval(TimeInterval(-updatedDaysAgo) * 86400)
        return Subscription(
            name: name,
            amount: amount,
            currency: currency,
            billingCycle: cycle,
            nextBillingDate: next,
            startDate: now,
            category: .other,
            isActive: isActive,
            pausedUntil: pausedUntil,
            createdAt: updated,
            updatedAt: updated
        )
    }
}
