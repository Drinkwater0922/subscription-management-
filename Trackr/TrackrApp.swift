import SwiftUI
import SwiftData

@main
struct TrackrApp: App {
    /// The app's SwiftData container. Constructed once at launch.
    private let container: ModelContainer

    init() {
        do {
            self.container = try ModelContainerConfig.makeAppContainer()
        } catch {
            // Schema mismatch or disk-full at first launch — both warrant a crash
            // rather than silent degradation. M7 revisits with CloudKit sync.
            fatalError("Failed to construct ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
