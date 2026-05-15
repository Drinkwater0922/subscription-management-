import XCTest
import SwiftData
import UserNotifications
@testable import Trackr

@MainActor
final class PresetSyncProPushTests: XCTestCase {

    private var container: ModelContainer!
    private var fetcher: FakePresetFetcher!
    private var notificationCenter: FakeNotificationCenter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        fetcher = FakePresetFetcher()
        notificationCenter = FakeNotificationCenter()
    }

    override func tearDownWithError() throws {
        notificationCenter = nil
        fetcher = nil
        container = nil
        try super.tearDownWithError()
    }

    private func seedSettings(proStatus: ProStatus) throws {
        let s = try SettingsRepository(context: container.mainContext).currentSettings()
        s.proStatus = proStatus
        try container.mainContext.save()
    }

    private func seedSubAndCache() throws {
        let sub = Subscription(
            name: "X", amount: 10, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now,
            category: .media, presetId: "a"
        )
        container.mainContext.insert(sub)
        let initial = try JSONDecoder().decode(PresetCatalog.self,
            from: Data(#"""
            {"version":"1.0.0","items":[{"id":"a","name":"Service A","defaultPlanName":"S","defaultAmount":"10","defaultCurrency":"USD","defaultCycle":"monthly","category":"media","iconRef":"preset:a"}]}
            """#.utf8))
        let cache = PresetCache(version: "1.0.0", fetchedAt: .now,
                                data: try JSONEncoder().encode(initial))
        container.mainContext.insert(cache)
        try container.mainContext.save()
    }

    func test_pro_pricesChange_firesPush() async throws {
        try seedSubAndCache()
        try seedSettings(proStatus: .proLifetime)
        fetcher.result = try JSONDecoder().decode(PresetCatalog.self,
            from: Data(#"""
            {"version":"1.1.0","items":[{"id":"a","name":"Service A","defaultPlanName":"S","defaultAmount":"12","defaultCurrency":"USD","defaultCycle":"monthly","category":"media","iconRef":"preset:a"}]}
            """#.utf8))

        let publisher = PriceChangePushPublisher(center: notificationCenter)
        let sync = PresetSync(fetcher: fetcher,
                              container: container,
                              pushPublisher: publisher)
        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(notificationCenter.addedRequests.count, 1,
                       "Pro user should get one push per alert")
    }

    func test_free_pricesChange_noPush() async throws {
        try seedSubAndCache()
        try seedSettings(proStatus: .free)
        fetcher.result = try JSONDecoder().decode(PresetCatalog.self,
            from: Data(#"""
            {"version":"1.1.0","items":[{"id":"a","name":"Service A","defaultPlanName":"S","defaultAmount":"12","defaultCurrency":"USD","defaultCycle":"monthly","category":"media","iconRef":"preset:a"}]}
            """#.utf8))

        let publisher = PriceChangePushPublisher(center: notificationCenter)
        let sync = PresetSync(fetcher: fetcher,
                              container: container,
                              pushPublisher: publisher)
        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(notificationCenter.addedRequests.count, 0)
    }
}
