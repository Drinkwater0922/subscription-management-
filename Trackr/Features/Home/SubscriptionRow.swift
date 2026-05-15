import SwiftUI

/// One subscription as it appears in the Home list. Stateless — accepts the
/// model directly and renders. Tapping is handled by the parent.
struct SubscriptionRow: View {

    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            MonoSquareIcon(name: subscription.name)
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

            PixelText(AmountFormatter.format(subscription.amount, currency: subscription.currency),
                      size: TrackrTypography.Scale.value,
                      color: subscription.isActive ? TrackrColors.fg : TrackrColors.fg3,
                      tracking: 1)
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
}
