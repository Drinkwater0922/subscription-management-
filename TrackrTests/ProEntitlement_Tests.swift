import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class ProEntitlementTests: XCTestCase {

    private var container: ModelContainer!
    private var client: FakeStoreKitClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        client = FakeStoreKitClient()
    }

    override func tearDownWithError() throws {
        container = nil
        client = nil
        try super.tearDownWithError()
    }

    func test_start_resolvesInitialEntitlement_andWritesToSettings() async throws {
        client.currentResult = .proLifetime

        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()

        XCTAssertEqual(entitlement.current, .proLifetime)
        let s = try SettingsRepository(context: container.mainContext).currentSettings()
        XCTAssertEqual(s.proStatus, .proLifetime,
                       "ProEntitlement should write through to UserSettings on start")
    }

    func test_purchase_flipsCurrent_andWritesSettings() async throws {
        client.purchaseResults[ProProductID.lifetime] = .success(.proLifetime)

        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()

        try await entitlement.purchase(productID: ProProductID.lifetime)
        XCTAssertEqual(entitlement.current, .proLifetime)
        XCTAssertEqual(client.purchaseCallCount, 1)
        let s = try SettingsRepository(context: container.mainContext).currentSettings()
        XCTAssertEqual(s.proStatus, .proLifetime)
    }

    func test_transactionUpdate_updatesCurrent() async throws {
        client.currentResult = .free
        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()
        XCTAssertEqual(entitlement.current, .free)

        // Pump an update through the fake's continuation. The listener task
        // ProEntitlement spawned in `start()` reads from this stream.
        client.updatesContinuation?.yield(.proLifetime)
        // Give the listener task a moment to consume the value.
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(entitlement.current, .proLifetime)
    }

    func test_availableProducts_passesThroughClient() async {
        client.products = [
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$7.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        let products = await entitlement.availableProducts()
        XCTAssertEqual(products.map(\.priceDisplay), ["$7.99"])
    }
}
