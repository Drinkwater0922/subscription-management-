import SwiftUI
import SwiftData

/// Pro-gated insights dashboard.
///
/// **v1.2 (this commit, C1):** demoted stat strip (THIS MONTH / THIS YEAR /
/// ACTIVE) + top-5 SuspectRanker ranking with cross-sheet routing to Detail.
/// NEXT 30 DAYS DUE hero + currency switcher + category / currency
/// breakdowns land in C2.
struct InsightsView: View {

    @Environment(ProEntitlement.self) private var entitlement
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// v1.2: when a SuspectRanking row is tapped, request the sub's Detail
    /// via the shared router and dismiss this sheet. HomeView's
    /// `.sheet(item: $selected)` picks up the request and presents Detail.
    /// This avoids stacking a second sheet on top of Insights.
    @Environment(AppDeepLinkRouter.self) private var router

    @Query(sort: \Subscription.nextBillingDate, order: .forward)
    private var subscriptions: [Subscription]

    @Query private var fxTables: [FXRateTable]

    /// InsightsView is itself presented as a sheet from `HomeView`. Routing
    /// the paywall through the shared `PaywallTriggerCoordinator` would ask
    /// HomeView to present a second sheet while this one is still up — which
    /// silently no-ops (the "unresponsive upgrade button" App Review caught
    /// on iPad). Present the paywall locally from this sheet instead.
    @State private var showUpgradePaywall = false

    private var currentCurrency: String {
        do {
            return try SettingsRepository(context: context).currentSettings().defaultCurrency
        } catch {
            return "USD"
        }
    }

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    if FeatureGate.isAllowed(.insights, given: entitlement.current) {
                        proBody
                    } else {
                        lockedBody
                    }
                }
            }
        }
        .sheet(isPresented: $showUpgradePaywall) {
            PaywallView(reason: .insightsLocked)
                .modelContext(context)
                .environment(entitlement)
                .preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        HStack {
            Button("CLOSE") { dismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            PixelText("INSIGHTS", size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(20)
    }

    private var proBody: some View {
        let currency = currentCurrency
        let monthly = MonthlyTotalCalculator.total(of: subscriptions,
                                                   in: currency,
                                                   rateTable: fxTables.first)
        let yearly = monthly * 12
        let activeCount = subscriptions.filter { $0.isActive }.count
        let ranked = SuspectRanker.rank(subscriptions,
                                         in: currency,
                                         rateTable: fxTables.first)

        return VStack(alignment: .leading, spacing: 20) {
            statStrip(monthly: monthly, yearly: yearly,
                       activeCount: activeCount, currency: currency)

            stripDivider

            SuspectRankingSection(
                ranked: ranked,
                displayCurrency: currency,
                onSelect: { sub in
                    // Hand off to HomeView via the shared router; the sheet
                    // dismiss lets HomeView's .sheet(item:) take over.
                    router.requestOpen(subscriptionID: sub.id)
                    dismiss()
                }
            )
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
    }

    /// Horizontal three-column strip replacing the three full-bleed metric
    /// cards. Stays in C1; the v1.2 hero (NEXT 30 DAYS DUE) lands in C2.
    private func statStrip(monthly: Decimal, yearly: Decimal,
                            activeCount: Int, currency: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            statColumn(label: "THIS MONTH",
                        value: AmountFormatter.format(monthly, currency: currency))
            statColumn(label: "THIS YEAR",
                        value: AmountFormatter.format(yearly, currency: currency))
            statColumn(label: "ACTIVE", value: "\(activeCount)")
        }
        .padding(.horizontal, 20)
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            PixelText(label,
                      size: TrackrTypography.Scale.caption,
                      color: TrackrColors.fg3,
                      tracking: 1.5)
            PixelText(value,
                      size: TrackrTypography.Scale.value,
                      tracking: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stripDivider: some View {
        Rectangle()
            .fill(TrackrColors.border)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    private var lockedBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            PixelText("INSIGHTS ARE PRO",
                      size: TrackrTypography.Scale.title, tracking: 2)
            Text("Upgrade to PennyLoop Pro to see totals, trends, and category breakdowns.")
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            TrackrButton("UPGRADE") {
                showUpgradePaywall = true
            }
        }
        .padding(20)
    }
}

#Preview {
    InsightsView()
        .environment(AppDeepLinkRouter())
}
