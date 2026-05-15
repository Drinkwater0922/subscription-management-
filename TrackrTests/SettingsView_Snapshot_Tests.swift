import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class SettingsViewSnapshotTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func host(leadDays: [Int] = [3, 1], hour: Int = 9) throws -> some View {
        let settings = try SettingsRepository(context: container.mainContext).currentSettings()
        settings.leadDays = leadDays
        settings.notifyHour = hour
        try container.mainContext.save()
        let entitlement = ProEntitlement(client: FakeStoreKitClient(), container: container)
        return SettingsView()
            .modelContainer(container)
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_defaults_render() throws {
        assertSnapshot(of: try host(), as: .image)
    }

    func test_allLeadDaysAndLateHour_render() throws {
        assertSnapshot(of: try host(leadDays: [7, 3, 1], hour: 22), as: .image)
    }

    func test_commit_writesSettingsAndRefreshes() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake)
        let coordinator = NotificationCoordinator(scheduler: scheduler, container: container)
        await SettingsView.commit(
            leadDays: [7, 3],
            notifyHour: 18,
            currency: "cny",
            language: "auto",
            context: container.mainContext,
            coordinator: coordinator
        )
        let s = try SettingsRepository(context: container.mainContext).currentSettings()
        XCTAssertEqual(s.leadDays, [7, 3])
        XCTAssertEqual(s.notifyHour, 18)
        XCTAssertEqual(s.defaultCurrency, "CNY")
        XCTAssertEqual(fake.requestedOptions, [.alert, .sound, .badge])
    }
}
