import Foundation
import SwiftData

/// Constructs SwiftData `ModelContainer`s for the app and for tests.
enum ModelContainerConfig {

    /// App Group identifier — both the app and the widget extension read/write
    /// the same SQLite store via this group. Production swaps this for the
    /// real Apple Developer team prefix in M9.
    static let appGroupIdentifier = "group.com.jingxue.pennyloop"

    /// SwiftData CloudKit container ID — matches the entitlement on the app target.
    static let cloudKitContainerIdentifier = "iCloud.com.jingxue.pennyloop"

    /// URL inside the shared App Group container where the SwiftData store lives.
    /// The widget extension targets the same URL so the two processes see the
    /// same data without a sync hop.
    static func sharedStoreURL() -> URL {
        guard let groupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            // App Group entitlement isn't wired up (or tests in a non-entitled
            // environment) — fall back to the documents directory so the app
            // still works locally.
            let docs = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
            return docs.appendingPathComponent("Trackr.sqlite")
        }
        return groupURL.appendingPathComponent("Trackr.sqlite")
    }

    /// The persistent container used by the running app. Lives in the user's
    /// App Group so the widget extension can read the same store.
    /// CloudKit sync is toggled by the caller via `syncMode`.
    static func makeAppContainer(syncMode: SyncMode = .localOnly) throws -> ModelContainer {
        let url = sharedStoreURL()
        let config: ModelConfiguration
        switch syncMode {
        case .localOnly:
            config = ModelConfiguration(schema: schema, url: url,
                                        cloudKitDatabase: .none)
        case .cloudKit:
            config = ModelConfiguration(schema: schema, url: url,
                                        cloudKitDatabase: .private(cloudKitContainerIdentifier))
        }
        return try ModelContainer(for: schema, configurations: config)
    }

    /// An in-memory container for tests. Wipes itself when deallocated.
    /// Explicitly opts out of CloudKit so the simulator doesn't attempt
    /// schema validation against iCloud even when the app-group entitlement
    /// is present in the host process.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: config)
    }

    private static let schema = Schema([
        Subscription.self,
        RenewalEvent.self,
        PriceChangeAlert.self,
        UserSettings.self,
        PresetCache.self,
        PriceHistoryEntry.self,
        FXRateTable.self,
    ])
}

/// Test-target convenience so tests can call `makeInMemoryContainer()` without typing
/// the namespace. Mirrors what most XCTestCase suites do.
func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainerConfig.makeInMemoryContainer()
}
