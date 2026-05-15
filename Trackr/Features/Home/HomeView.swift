import SwiftUI
import SwiftData

/// Home screen. Lists the user's active subscriptions in `nextBillingDate` order
/// and shows the monthly-equivalent total in the user's default currency.
struct HomeView: View {

    @Query(sort: \Subscription.nextBillingDate, order: .forward)
    private var subscriptions: [Subscription]

    @Environment(\.modelContext) private var context
    @Environment(AppDeepLinkRouter.self) private var router
    @Environment(\.notificationCoordinator) private var coordinator
    @Environment(\.presetSync) private var presetSync
    @Environment(ProEntitlement.self) private var entitlement
    @Environment(PaywallTriggerCoordinator.self) private var paywallTrigger

    @State private var showingAdd = false
    @State private var showingSettings = false
    @State private var showingInsights = false
    @State private var selected: Subscription?

    /// Resolved lazily — `SettingsRepository` creates the row on first access.
    private var defaultCurrency: String {
        do {
            let repo = SettingsRepository(context: context)
            return try repo.currentSettings().defaultCurrency
        } catch {
            return "USD"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TrackrColors.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer().frame(height: 24)
                heroAmount
                Spacer().frame(height: 20)
                DashedDivider()
                Spacer().frame(height: 8)
                content
                Spacer()
            }
            .padding(.horizontal, 20)

            FloatingActionButton(action: { showingAdd = true })
                .padding(24)
        }
        .sheet(isPresented: $showingAdd) {
            AddSubscriptionSheet()
                .modelContext(context)
        }
        .sheet(item: $selected) { sub in
            SubscriptionDetailView(subscription: sub)
                .modelContext(context)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .modelContext(context)
                .environment(\.notificationCoordinator, coordinator)
        }
        .onChange(of: router.pendingSubscriptionID) { _, newValue in
            guard let id = newValue else { return }
            if let match = subscriptions.first(where: { $0.id == id }) {
                selected = match
            }
            _ = router.consume()
        }
        .task {
            try? await presetSync?.run()
        }
        .sheet(isPresented: Binding(
            get: { paywallTrigger.isShowing },
            set: { newValue in if !newValue { paywallTrigger.dismiss() } }
        )) {
            PaywallView(reason: paywallTrigger.reason ?? .manual)
                .modelContext(context)
                .environment(entitlement)
        }
        .sheet(isPresented: $showingInsights) {
            InsightsView()
                .modelContext(context)
                .environment(entitlement)
                .environment(paywallTrigger)
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Rectangle().fill(TrackrColors.accent).frame(width: 8, height: 8)
                PixelText("TRACKR", size: TrackrTypography.Scale.title, tracking: 3)
            }
            Spacer()
            HStack(spacing: 14) {
                Button { showingInsights = true } label: {
                    Color.clear.frame(width: 32, height: 32)
                        .overlay(PixelText("≡", size: 14, color: TrackrColors.fg2, tracking: 0))
                        .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button { showingSettings = true } label: {
                    Color.clear.frame(width: 32, height: 32)
                        .overlay(PixelText("⚙", size: 14, color: TrackrColors.fg2, tracking: 0))
                        .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var heroAmount: some View {
        let currency = defaultCurrency
        let total = MonthlyTotalCalculator.total(of: subscriptions, in: currency)
        return VStack(alignment: .leading, spacing: 6) {
            PixelText("MONTHLY · \(currency.uppercased())",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(AmountFormatter.format(total, currency: currency),
                      size: TrackrTypography.Scale.hero,
                      tracking: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if subscriptions.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(subscriptions) { sub in
                        Button { selected = sub } label: {
                            SubscriptionRow(subscription: sub)
                        }
                        .buttonStyle(.plain)
                        DashedDivider()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            PixelText("NO SUBS\nTRACKED",
                      size: TrackrTypography.Scale.title,
                      color: TrackrColors.fg3,
                      tracking: 3)
                .multilineTextAlignment(.center)
            Text("Tap + to add your first subscription")
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.caption))
                .foregroundStyle(TrackrColors.fg3)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview { HomeView() }
