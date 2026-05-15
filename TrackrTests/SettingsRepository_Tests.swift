import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SettingsRepositoryTests: XCTestCase {

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

    private func makeRepo() -> SettingsRepository {
        SettingsRepository(context: container.mainContext)
    }

    func test_currentSettings_createsRowOnFirstCall() throws {
        let repo = makeRepo()
        let settings = try repo.currentSettings()
        XCTAssertEqual(settings.defaultCurrency, "USD")
        XCTAssertEqual(settings.leadDays, [3, 1])
        XCTAssertEqual(settings.proStatus, .free)
    }

    func test_currentSettings_returnsSameRowOnSubsequentCalls() throws {
        let repo = makeRepo()
        let first = try repo.currentSettings()
        first.notifyHour = 22
        try repo.save()

        let second = try repo.currentSettings()
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.notifyHour, 22)
    }

    func test_proStatus_canBeMutated() throws {
        let repo = makeRepo()
        let s = try repo.currentSettings()
        s.proStatus = .proLifetime
        try repo.save()

        let reFetched = try repo.currentSettings()
        XCTAssertEqual(reFetched.proStatus, .proLifetime)
    }
}
