import SwiftUI
import StoreKit

struct PaywallView: View {

    let reason: PaywallTriggerCoordinator.Reason

    @Environment(ProEntitlement.self) private var entitlement
    @Environment(\.dismiss) private var dismiss

    @State private var products: [ProProductDisplay] = []
    @State private var purchaseInFlight = false
    @State private var errorMessage: String?
    // TODO(M11-launch): remove this debug state before final App Store submission.
    @State private var debugReport: String = "DEBUG: …"

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        hero
                        DashedDivider()
                        featureList
                        productCards
                        if let errorMessage {
                            PixelText(errorMessage.uppercased(),
                                      size: TrackrTypography.Scale.caption,
                                      color: TrackrColors.warn,
                                      tracking: 1.5)
                        }
                        TrackrButton("RESTORE PURCHASES", variant: .outlined) {
                            Task { await restore() }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .task {
            products = await entitlement.availableProducts()
            await collectDebugReport()
        }
    }

    private var header: some View {
        HStack {
            Button("CLOSE") { dismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            PixelText("PENNYLOOP PRO", size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(20)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            PixelText(headline(for: reason).uppercased(),
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            Text(subhead(for: reason))
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow("UNLIMITED SUBSCRIPTIONS")
            featureRow("PUSH NOTIFICATIONS ON PRICE CHANGES")
            featureRow("INSIGHTS DASHBOARD")
            featureRow("iCLOUD SYNC ACROSS DEVICES")
        }
    }

    private func featureRow(_ label: String) -> some View {
        HStack(spacing: 8) {
            PixelText("✓",
                      size: TrackrTypography.Scale.value,
                      color: TrackrColors.accent, tracking: 0)
            PixelText(label,
                      size: TrackrTypography.Scale.body,
                      tracking: 1.5)
        }
    }

    private var productCards: some View {
        VStack(spacing: 12) {
            productCard(productID: ProProductID.lifetime,
                        title: "LIFETIME",
                        subtitle: "ONE-TIME PURCHASE · NO RECURRING CHARGE")
            // TODO(M11-launch): remove this debug overlay before final App Store submission.
            debugProductDump
        }
    }

    /// Renders raw StoreKit data in the system font (NOT VT323), so we can
    /// distinguish a font-rendering bug from a data/storefront bug. Visible
    /// only in TestFlight builds during launch QA.
    private var debugProductDump: some View {
        Text(debugReport)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(TrackrColors.warn)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func collectDebugReport() async {
        var lines: [String] = []
        if let sf = await Storefront.current {
            lines.append("storefront: code=\(sf.countryCode) id=\(sf.id)")
        } else {
            lines.append("storefront: nil")
        }
        do {
            let raw = try await Product.products(for: [ProProductID.lifetime])
            if raw.isEmpty {
                lines.append("products: <empty>")
            }
            for p in raw {
                lines.append("id: \(p.id)")
                lines.append("displayName: \(p.displayName)")
                lines.append("displayPrice: \"\(p.displayPrice)\"")
                lines.append("price: \(p.price)")
                lines.append("currency: \(p.priceFormatStyle.currencyCode)")
                lines.append("locale: \(p.priceFormatStyle.locale.identifier)")
            }
        } catch {
            lines.append("products error: \(error)")
        }
        debugReport = lines.joined(separator: "\n")
    }

    private func productCard(productID: String,
                             title: String,
                             subtitle: String) -> some View {
        let price = products.first(where: { $0.productID == productID })?.priceDisplay ?? "—"
        return Button {
            Task { await purchase(productID: productID) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PixelText(title,
                              size: TrackrTypography.Scale.title,
                              tracking: 2)
                    Spacer()
                    PixelText(price,
                              size: TrackrTypography.Scale.title,
                              color: TrackrColors.accent,
                              tracking: 1)
                }
                PixelText(subtitle,
                          size: TrackrTypography.Scale.sectionLabel,
                          color: TrackrColors.fg2, tracking: 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(purchaseInFlight)
    }

    private func headline(for reason: PaywallTriggerCoordinator.Reason) -> String {
        switch reason {
        case .subscriptionLimit:        return "Hit the 5-sub limit?"
        case .insightsLocked:           return "Insights are Pro"
        case .pushNotificationsLocked:  return "Push notifications are Pro"
        case .iCloudSyncLocked:         return "Sync is Pro"
        case .manual:                   return "Go Pro"
        }
    }

    private func subhead(for reason: PaywallTriggerCoordinator.Reason) -> String {
        switch reason {
        case .subscriptionLimit:        return "Pro removes the cap and unlocks everything below."
        case .insightsLocked:           return "Spend totals, trends, and category breakdowns."
        case .pushNotificationsLocked:  return "Get notified the moment a service changes its price."
        case .iCloudSyncLocked:         return "Keep your subscriptions in sync across every device."
        case .manual:                   return "One purchase. Every feature, forever."
        }
    }

    private func purchase(productID: String) async {
        guard !purchaseInFlight else { return }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            try await entitlement.purchase(productID: productID)
            dismiss()
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    private func restore() async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        await entitlement.refresh()
        errorMessage = nil
    }
}
