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
    private let entitlement: ProEntitlement
    private let paywallTrigger: PaywallTriggerCoordinator
    private let haptics: Haptics
    private let fxClient: FXRateClient
    private let fxLatestRatesClient: any FXLatestRatesClient
    private let photoImport: PhotoImportPipeline

    init() {
        // Read the cached entitlement from a temporary local-only container so
        // we know which SyncMode to build the real container with. The temp
        // container is scoped to this function and released before the real
        // container opens, so SQLite can reopen the same store.
        let cachedProStatus = Self.readCachedProStatus()
        let syncMode: SyncMode = SyncDecider.decide(
            proStatus: cachedProStatus,
            iCloud: .couldNotDetermine
        )

        do {
            self.container = try ModelContainerConfig.makeAppContainer(syncMode: syncMode)
        } catch {
            // CloudKit can fail to attach (no entitlement in dev, account
            // signed out mid-launch, etc.). Fall back to local-only.
            do {
                self.container = try ModelContainerConfig.makeAppContainer(syncMode: .localOnly)
            } catch {
                fatalError("Failed to construct ModelContainer: \(error)")
            }
        }

        self.router = AppDeepLinkRouter()
        self.coordinator = NotificationCoordinator(
            scheduler: LocalNotificationScheduler(center: SystemNotificationCenter()),
            container: container
        )
        self.notificationDelegate = TrackrNotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate
        self.entitlement = ProEntitlement(client: SystemStoreKitClient(), container: container)
        self.paywallTrigger = PaywallTriggerCoordinator()
        self.haptics = SystemHaptics()
        self.fxClient = FrankfurterFXClient()
        self.fxLatestRatesClient = FrankfurterLatestRatesClient()
        self.photoImport = FallbackPhotoImport()

        // v1.1 FX bootstrap: seed the persisted rate table from the bundled
        // fallback so first launch / offline still has rates to convert
        // with. No-op if a table already exists. The Home-appear refresh
        // hook (HomeView .task) keeps the table current after that.
        let seedContext = container.mainContext
        FXRateBootstrap.seedIfNeeded(
            repository: FXRateTableRepository(context: seedContext)
        )

        // v1.1 price-history backfill: legacy v1.0 / TestFlight subs have
        // no PriceHistoryEntry rows. Write one .initial baseline per
        // legacy sub so the Detail price-history list has an anchor from
        // first launch. Idempotent — subsequent launches see all subs
        // already have history and no-op.
        PriceHistoryBackfill.run(context: seedContext)

        let catalogURL = BrandConfig.presetCatalogURL
        let pushPublisher = PriceChangePushPublisher(center: SystemNotificationCenter())
        self.presetSync = PresetSync(
            fetcher: URLSessionPresetFetcher(catalogURL: catalogURL),
            container: container,
            pushPublisher: pushPublisher
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(\.notificationCoordinator, coordinator)
                .environment(\.presetSync, presetSync)
                .environment(entitlement)
                .environment(paywallTrigger)
                .environment(\.haptics, haptics)
                .environment(\.fxRateClient, fxClient)
                .environment(\.fxLatestRatesClient, fxLatestRatesClient)
                .environment(\.photoImportPipeline, photoImport)
                .preferredColorScheme(.dark)
                .task { await entitlement.start() }
        }
        .modelContainer(container)
    }

    /// Reads the previously-persisted `UserSettings.proStatus` from the shared
    /// App Group container. Used at launch (before `ProEntitlement.start()`)
    /// to decide whether to spin up CloudKit. Scopes the container to a `do`
    /// block so ARC releases it before the real container opens.
    @MainActor
    private static func readCachedProStatus() -> ProStatus {
        do {
            let temp: ModelContainer = try ModelContainerConfig.makeAppContainer(syncMode: .localOnly)
            let context = temp.mainContext
            let settings = try context.fetch(FetchDescriptor<UserSettings>()).first
            return settings?.proStatus ?? .free
        } catch {
            return .free
        }
    }
}

/// Root coordinator: shows the onboarding flow as a full-screen cover on
/// first launch (`UserSettings.onboardingCompletedAt == nil`), and `HomeView`
/// otherwise. Writing the completion timestamp through SwiftData triggers
/// re-evaluation of `needsOnboarding` and the cover dismisses.
private struct RootView: View {

    @Environment(\.modelContext) private var context
    @Query private var settings: [UserSettings]

    var body: some View {
        HomeView()
            .environment(\.locale, resolvedLocale)
            .fullScreenCover(isPresented: .constant(needsOnboarding)) {
                OnboardingView(onComplete: completeOnboarding)
                    .environment(\.locale, resolvedLocale)
            }
    }

    private var needsOnboarding: Bool {
        guard let row = settings.first else { return true }
        return row.onboardingCompletedAt == nil
    }

    private var resolvedLocale: Locale {
        let preference = settings.first?.language ?? "auto"
        return LocaleResolver.resolve(
            languagePreference: preference,
            systemLocale: Locale.current
        )
    }

    private func completeOnboarding() {
        do {
            let row = try SettingsRepository(context: context).currentSettings()
            row.onboardingCompletedAt = .now
            try context.save()
        } catch {
            // M8 ignores this — worst case the user sees onboarding again next launch.
        }
    }
}
