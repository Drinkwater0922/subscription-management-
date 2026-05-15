import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class UserSettingsTests: XCTestCase {

    func test_defaultsMatchSpec() throws {
        let s = UserSettings()
        XCTAssertEqual(s.defaultCurrency, "USD")
        XCTAssertEqual(s.leadDays, [3, 1])
        XCTAssertEqual(s.notifyHour, 9)
        XCTAssertEqual(s.language, "auto")
        XCTAssertFalse(s.biometricLockEnabled)
        XCTAssertEqual(s.proStatus, .free)
        XCTAssertNil(s.proExpiresAt)
        XCTAssertNil(s.onboardingCompletedAt)
    }

    func test_canBeInsertedAndMutated() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let s = UserSettings()
        context.insert(s)
        try context.save()

        s.notifyHour = 18
        s.proStatus = .proLifetime
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserSettings>()).first
        XCTAssertEqual(fetched?.notifyHour, 18)
        XCTAssertEqual(fetched?.proStatus, .proLifetime)
    }
}
