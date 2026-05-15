import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class AlertRepositoryTests: XCTestCase {

    /// Test-owned container so the in-memory store outlives each test method.
    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    private func makeRepo() -> AlertRepository {
        AlertRepository(context: container.mainContext)
    }

    private func makeAlert(presetId: String = "p", seen: Date? = nil) -> PriceChangeAlert {
        PriceChangeAlert(
            presetId: presetId, planKey: "pro",
            oldAmount: 1, newAmount: 2,
            currency: "USD",
            effectiveDate: .now,
            messageEn: "", messageZh: "",
            seenAt: seen
        )
    }

    func test_insertedAlertIsFetchable() throws {
        let repo = makeRepo()
        let alert = makeAlert(presetId: "vendor.product")
        try repo.insert(alert)
        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.presetId, "vendor.product")
    }

    func test_fetchUnseen_excludesAlreadyDismissed() throws {
        let repo = makeRepo()
        try repo.insert(makeAlert(presetId: "a"))
        try repo.insert(makeAlert(presetId: "b", seen: .now))
        let unseen = try repo.fetchUnseen()
        XCTAssertEqual(unseen.map(\.presetId), ["a"])
    }

    func test_markSeen_setsSeenAt() throws {
        let repo = makeRepo()
        let alert = makeAlert(presetId: "x")
        try repo.insert(alert)
        XCTAssertNil(alert.seenAt)
        try repo.markSeen(alert)
        XCTAssertNotNil(alert.seenAt)
    }

    func test_fetchForPreset_filtersById() throws {
        let repo = makeRepo()
        try repo.insert(makeAlert(presetId: "match"))
        try repo.insert(makeAlert(presetId: "other"))
        let result = try repo.fetch(forPresetId: "match")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.presetId, "match")
    }
}
