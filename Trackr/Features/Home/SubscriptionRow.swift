import SwiftUI

/// One subscription as it appears in the Home list. Stateless — accepts the
/// model directly and renders. Tapping is handled by the parent.
struct SubscriptionRow: View {

    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            MonoSquareIcon(name: subscription.name,
                           glyph: PresetIcons.glyph(for: subscription),
                           assetName: PresetIcons.assetName(for: subscription),
                           assetTint: PresetIcons.tint(for: subscription))
                .opacity(subscription.isActive ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 2) {
                PixelText(subscription.name.uppercased(),
                          size: TrackrTypography.Scale.value,
                          tracking: 1.5)
                PixelText(cycleLine,
                          size: TrackrTypography.Scale.sectionLabel,
                          color: TrackrColors.fg2,
                          tracking: 1.5)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                PixelText(AmountFormatter.format(subscription.amount,
                                                  currency: subscription.currency),
                          size: TrackrTypography.Scale.value,
                          color: subscription.isActive ? TrackrColors.fg : TrackrColors.fg3,
                          tracking: 1)
                PixelText(renewalLine,
                          size: TrackrTypography.Scale.sectionLabel,
                          color: renewalColor,
                          tracking: 1.5)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private var cycleLine: String {
        let cycle: String
        switch subscription.billingCycle {
        case .monthly:           cycle = "MONTHLY"
        case .yearly:            cycle = "YEARLY"
        case .weekly:            cycle = "WEEKLY"
        case .customDays(let d): cycle = "EVERY \(d) DAYS"
        }
        if let plan = subscription.planName, !plan.isEmpty {
            return "\(cycle) · \(plan.uppercased())"
        }
        return cycle
    }

    /// v1.1: "RENEWS IN 3 DAYS" line under the amount. For trials,
    /// reads the trial conversion date instead of the next billing date.
    private var renewalLine: String {
        let target = subscription.isTrial()
            ? (subscription.trialEndsAt ?? subscription.nextBillingDate)
            : subscription.nextBillingDate
        return RelativeRenewalText.shortLabel(
            for: RelativeRenewalText.variant(nextBillingDate: target),
            locale: .current
        )
    }

    /// Use accent lime when the renewal is today or tomorrow — those
    /// are the rows the triage view wants to draw the eye to. Everything
    /// else stays muted so the section doesn't visually shout.
    private var renewalColor: Color {
        let variant = RelativeRenewalText.variant(
            nextBillingDate: subscription.isTrial()
                ? (subscription.trialEndsAt ?? subscription.nextBillingDate)
                : subscription.nextBillingDate
        )
        switch variant {
        case .today, .tomorrow, .overdue: return TrackrColors.accent
        case .inDays: return TrackrColors.fg2
        }
    }
}
