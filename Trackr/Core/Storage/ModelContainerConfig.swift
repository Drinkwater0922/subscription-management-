import Foundation
import SwiftData

/// Constructs SwiftData `ModelContainer`s for the app and for tests.
enum ModelContainerConfig {

    /// The persistent container used by the running app. Lives in the user's app group.
    /// CloudKit sync wiring lands in M7; for M2 this is local-only persistence.
    static func makeAppContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: config)
    }

    /// An in-memory container for tests. Wipes itself when deallocated.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: config)
    }

    private static let schema = Schema([
        Subscription.self,
        RenewalEvent.self,
        PriceChangeAlert.self,
        UserSettings.self,
        PresetCache.self,
    ])
}

/// Test-target convenience so tests can call `makeInMemoryContainer()` without typing
/// the namespace. Mirrors what most XCTestCase suites do.
func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainerConfig.makeInMemoryContainer()
}
