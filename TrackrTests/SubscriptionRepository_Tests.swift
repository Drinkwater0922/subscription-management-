import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionRepositoryTests: XCTestCase {

    /// Test-owned container so the in-memory store outlives each test method.
    /// If the container is allowed to drop mid-test, `context.save()` crashes.
    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    private func makeRepo() -> SubscriptionRepository {
        SubscriptionRepository(context: container.mainContext)
    }

    private func makeSub(name: String = "Test", nextBilling: Date = .distantFuture) -> Subscription {
        Subscription(
            name: name,
            amount: 10,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: nextBilling,
            startDate: .now,
            category: .other
        )
    }

    func test_insert_thenFetchAll_returnsOneSub() throws {
        let repo = makeRepo()
        try repo.insert(makeSub(name: "Alpha"))
        XCTAssertEqual(try repo.fetchAll().count, 1)
        XCTAssertEqual(try repo.fetchAll().first?.name, "Alpha")
    }

    func test_fetchAll_sortsByNextBillingDateAscending() throws {
        let repo = makeRepo()
        let near = makeSub(name: "Near", nextBilling: Date(timeIntervalSince1970: 1_000))
        let far  = makeSub(name: "Far",  nextBilling: Date(timeIntervalSince1970: 2_000))
        try repo.insert(far)
        try repo.insert(near)
        let result = try repo.fetchAll()
        XCTAssertEqual(result.map(\.name), ["Near", "Far"])
    }

    func test_delete_removesIt() throws {
        let repo = makeRepo()
        let sub = makeSub(name: "ToDelete")
        try repo.insert(sub)
        XCTAssertEqual(try repo.fetchAll().count, 1)
        try repo.delete(sub)
        XCTAssertEqual(try repo.fetchAll().count, 0)
    }

    func test_count_reflectsInserts() throws {
        let repo = makeRepo()
        XCTAssertEqual(try repo.count(), 0)
        try repo.insert(makeSub())
        try repo.insert(makeSub())
        XCTAssertEqual(try repo.count(), 2)
    }

    func test_fetchByID_findsIt() throws {
        let repo = makeRepo()
        let sub = makeSub(name: "FindMe")
        try repo.insert(sub)
        let found = try repo.fetch(byID: sub.id)
        XCTAssertEqual(found?.name, "FindMe")
    }

    func test_fetchByID_returnsNilForMissing() throws {
        let repo = makeRepo()
        let result = try repo.fetch(byID: UUID())
        XCTAssertNil(result)
    }
}
