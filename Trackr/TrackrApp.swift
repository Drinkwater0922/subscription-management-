import SwiftUI
import SwiftData
import UserNotifications

@main
struct TrackrApp: App {

    private let container: ModelContainer
    private let router: AppDeepLinkRouter
    private let coordinator: NotificationCoordinator
    private let notificationDelegate: TrackrNotificationDelegate
    private let presetSync: PresetSync

    init() {
        do {
            self.container = try ModelContainerConfig.makeAppContainer()
        } catch {
            fatalError("Failed to construct ModelContainer: \(error)")
        }
        self.router = AppDeepLinkRouter()
        self.coordinator = NotificationCoordinator(
            scheduler: LocalNotificationScheduler(center: SystemNotificationCenter()),
            container: container
        )
        self.notificationDelegate = TrackrNotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // M5: the live host lands in M9. Until then we point at a placeholder
        // that fails on every device — the bundled seed catalog drives LIBRARY.
        let catalogURL = URL(string: "https://presets.invalid/trackr/v1/presets.json")!
        self.presetSync = PresetSync(
            fetcher: URLSessionPresetFetcher(catalogURL: catalogURL),
            container: container
        )
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(router)
                .environment(\.notificationCoordinator, coordinator)
                .environment(\.presetSync, presetSync)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
