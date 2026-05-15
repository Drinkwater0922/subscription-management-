import SwiftUI
import SwiftData

/// Pro-gated insights dashboard. V1 shows totals only — trends and category
/// breakdowns ship in a later milestone.
struct InsightsView: View {

    @Environment(ProEntitlement.self) private var entitlement
    @Environment(PaywallTriggerCoordinator.self) private var paywallTrigger
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Subscription.nextBillingDate, order: .forward)
    private var subscriptions: [Subscription]

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
        let monthly = MonthlyTotalCalculator.total(of: subscriptions, in: currency)
        let yearly = monthly * 12
        let count = subscriptions.filter { $0.isActive }.count
        return VStack(alignment: .leading, spacing: 24) {
            metricCard(label: "MONTHLY",
                       value: AmountFormatter.format(monthly, currency: currency))
            metricCard(label: "YEARLY",
                       value: AmountFormatter.format(yearly, currency: currency))
            metricCard(label: "ACTIVE SUBS",
                       value: "\(count)")
        }
        .padding(20)
    }

    private func metricCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(label,
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(value,
                      size: TrackrTypography.Scale.hero,
                      tracking: 1)
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var lockedBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            PixelText("INSIGHTS ARE PRO",
                      size: TrackrTypography.Scale.title, tracking: 2)
            Text("Upgrade to Trackr Pro to see totals, trends, and category breakdowns.")
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            TrackrButton("UPGRADE") {
                paywallTrigger.present(reason: .insightsLocked)
            }
        }
        .padding(20)
    }
}

#Preview { InsightsView() }
