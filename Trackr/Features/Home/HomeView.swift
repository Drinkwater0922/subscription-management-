import SwiftUI
import SwiftData

/// Home screen. Lists the user's active subscriptions in `nextBillingDate` order
/// and shows the monthly-equivalent total in the user's default currency.
struct HomeView: View {

    @Query(sort: \Subscription.nextBillingDate, order: .forward)
    private var subscriptions: [Subscription]

    /// v1.1: persisted FX rate table used to convert foreign-currency subs
    /// into the display currency at render time. Single row in practice —
    /// `FXRateTableRepository.replace` enforces it. Always take `.first`.
    @Query private var fxTables: [FXRateTable]

    @Environment(\.modelContext) private var context
    @Environment(AppDeepLinkRouter.self) private var router
    @Environment(\.notificationCoordinator) private var coordinator
    @Environment(\.presetSync) private var presetSync
    @Environment(ProEntitlement.self) private var entitlement
    @Environment(PaywallTriggerCoordinator.self) private var paywallTrigger
    @Environment(\.haptics) private var haptics
    @Environment(\.fxLatestRatesClient) private var fxLatestRatesClient

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

            FloatingActionButton(action: {
                haptics?.play(.lightImpact)
                showingAdd = true
            })
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
        .task {
            // v1.1 FX refresh: if the persisted FXRateTable is older than
            // ~24h and the network is up, refresh it on Home appear. Never
            // blocks the UI; failures keep the cached table.
            guard let client = fxLatestRatesClient else { return }
            _ = await FXRateBootstrap.refreshIfStale(
                repository: FXRateTableRepository(context: context),
                client: client
            )
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
                PixelText("PENNYLOOP", size: TrackrTypography.Scale.title, tracking: 3)
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

    @State private var anchorRotation: Int = 0

    private var heroAmount: some View {
        let currency = defaultCurrency
        let table = fxTables.first
        let monthly = MonthlyTotalCalculator.total(of: subscriptions,
                                                   in: currency,
                                                   rateTable: table)
        let annualDisplay = monthly * 12
        let annualUSD = AnnualSpendCalculator.total(of: subscriptions,
                                                   in: "USD",
                                                   rateTable: table)
        let anchors = SpendAnchorCatalog.pick(annualSpendUSD: annualUSD, limit: 4)
        let activeCount = subscriptions.filter { $0.isActive }.count

        return VStack(alignment: .leading, spacing: 10) {
            PixelText(annualLabel(currency: currency),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(AmountFormatter.format(annualDisplay, currency: currency),
                      size: TrackrTypography.Scale.hero,
                      tracking: 1)
            if !anchors.isEmpty {
                Button {
                    haptics?.play(.lightImpact)
                    anchorRotation = (anchorRotation + 1) % anchors.count
                } label: {
                    PixelText(SpendAnchorRenderer.render(
                                annualSpendUSD: annualUSD,
                                anchor: anchors[anchorRotation % anchors.count]
                              ),
                              size: TrackrTypography.Scale.body,
                              color: TrackrColors.accent,
                              tracking: 1)
                }
                .buttonStyle(.plain)
            }
            PixelText(secondaryLine(monthly: monthly, currency: currency,
                                     count: activeCount),
                      size: TrackrTypography.Scale.caption,
                      color: TrackrColors.fg2,
                      tracking: 1.5)
        }
    }

    private func annualLabel(currency: String) -> String {
        let isChinese = Locale.current.language.languageCode?.identifier == "zh"
        if isChinese { return "今年订阅花费" }
        return "SUBS · THIS YEAR · \(currency.uppercased())"
    }

    private func secondaryLine(monthly: Decimal, currency: String, count: Int) -> String {
        let monthlyText = AmountFormatter.format(monthly, currency: currency)
        let isChinese = Locale.current.language.languageCode?.identifier == "zh"
        if isChinese { return "每月 \(monthlyText) · \(count) 个订阅" }
        let unit = count == 1 ? "SUBSCRIPTION" : "SUBSCRIPTIONS"
        return "\(monthlyText) / MONTH · \(count) \(unit)"
    }

    @ViewBuilder
    private var content: some View {
        if subscriptions.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(HomeSectionBuilder.build(from: subscriptions), id: \.kind) { section in
                        PixelText(HomeSectionBuilder.title(for: section.kind),
                                  size: TrackrTypography.Scale.sectionLabel,
                                  color: TrackrColors.fg2,
                                  tracking: 2)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                        ForEach(section.items) { sub in
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
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            PixelText(LocalizedStringKey("NO SUBS\nTRACKED"),
                      size: TrackrTypography.Scale.title,
                      color: TrackrColors.fg3,
                      tracking: 3)
                .multilineTextAlignment(.center)
            Text(LocalizedStringKey("Tap + to add your first subscription"))
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.caption))
                .foregroundStyle(TrackrColors.fg3)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview { HomeView() }
