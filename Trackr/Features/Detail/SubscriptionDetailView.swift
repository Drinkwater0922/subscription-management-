import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {

    @Bindable var subscription: Subscription
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.notificationCoordinator) private var coordinator

    @State private var editing = false
    @State private var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().background(TrackrColors.border)
                ScrollView {
                    if editing {
                        editingBody
                    } else {
                        readingBody
                    }
                }
                footer
            }
        }
        .confirmationDialog("Delete \(subscription.name)?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var header: some View {
        HStack {
            Button("CLOSE") { dismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            PixelText("DETAIL", size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            if editing {
                Button("DONE") { commitEdits() }
                    .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                    .foregroundStyle(TrackrColors.accent)
            } else {
                Button("EDIT") { beginEdit() }
                    .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                    .foregroundStyle(TrackrColors.accent)
            }
        }
        .padding(20)
    }

    private var readingBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            heroAmount
            DashedDivider()
            row("PLAN", subscription.planName ?? "—")
            row("CYCLE", cycleText)
            row("CATEGORY", subscription.category.displayName.uppercased())
            row("STARTED", iso(subscription.startDate))
            row("NEXT", iso(subscription.nextBillingDate))
            row("STATUS", subscription.isActive ? "ACTIVE" : "PAUSED")
            if let notes = subscription.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    PixelText("NOTES",
                              size: TrackrTypography.Scale.sectionLabel,
                              color: TrackrColors.fg2,
                              tracking: 2)
                    Text(notes)
                        .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                        .foregroundStyle(TrackrColors.fg)
                }
            }
        }
        .padding(20)
    }

    private var editingBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            labeled("NAME") {
                TextField("", text: $draft.name)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
            }
            labeled("AMOUNT") {
                TextField("0.00", text: $draft.amountString)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
            }
            labeled("PLAN") {
                TextField("optional", text: $draft.planName)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
            }
            labeled("NOTES") {
                TextField("optional", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
            }
        }
        .padding(20)
    }

    private var heroAmount: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(subscription.name.uppercased(),
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            PixelText(AmountFormatter.format(subscription.amount, currency: subscription.currency),
                      size: TrackrTypography.Scale.hero,
                      color: subscription.isActive ? TrackrColors.fg : TrackrColors.fg3,
                      tracking: 1)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            DashedDivider()
            HStack(spacing: 12) {
                TrackrButton(subscription.isActive ? "PAUSE" : "RESUME",
                             variant: .outlined) { togglePause() }
                TrackrButton("DELETE", variant: .outlined) { confirmingDelete = true }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            PixelText(label, size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            Spacer()
            PixelText(value, size: TrackrTypography.Scale.value, tracking: 1)
        }
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(label, size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            content()
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var cycleText: String {
        switch subscription.billingCycle {
        case .monthly:           return "MONTHLY"
        case .yearly:            return "YEARLY"
        case .weekly:            return "WEEKLY"
        case .customDays(let d): return "EVERY \(d) DAYS"
        }
    }

    private func iso(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    // MARK: - Actions

    private func beginEdit() {
        draft = SubscriptionDraft(
            name: subscription.name,
            planName: subscription.planName ?? "",
            amountString: "\(subscription.amount)",
            currency: subscription.currency,
            billingCycle: subscription.billingCycle,
            customDays: {
                if case .customDays(let d) = subscription.billingCycle { return d }
                return 30
            }(),
            startDate: subscription.startDate,
            category: subscription.category,
            notes: subscription.notes ?? "",
            urlString: subscription.url?.absoluteString ?? ""
        )
        editing = true
    }

    private func commitEdits() {
        Task {
            if await Self.applyEdits(to: subscription,
                                      draft: draft,
                                      context: context,
                                      coordinator: coordinator) == nil {
                editing = false
            }
        }
    }

    /// Pure-ish helper: validates `draft`, mutates `subscription`, saves the context.
    /// Returns `nil` on success or a user-facing error message on failure.
    @discardableResult
    static func applyEdits(to subscription: Subscription,
                           draft: SubscriptionDraft,
                           context: ModelContext,
                           coordinator: NotificationCoordinator? = nil) async -> String? {
        do {
            let built = try draft.makeSubscription()
            subscription.name = built.name
            subscription.planName = built.planName
            subscription.amount = built.amount
            subscription.currency = built.currency
            subscription.billingCycle = built.billingCycle
            subscription.category = built.category
            subscription.notes = built.notes
            subscription.url = built.url
            subscription.updatedAt = .now
            try context.save()
            if let coordinator { try? await coordinator.refresh() }
            return nil
        } catch SubscriptionDraft.ValidationError.emptyName {
            return "Name is required"
        } catch SubscriptionDraft.ValidationError.invalidAmount {
            return "Enter a valid amount"
        } catch SubscriptionDraft.ValidationError.invalidCustomDays {
            return "Custom cycle days must be > 0"
        } catch {
            return "Could not save: \(error.localizedDescription)"
        }
    }

    private func togglePause() {
        Task {
            try? await Self.togglePause(subscription: subscription,
                                        context: context,
                                        coordinator: coordinator)
        }
    }

    static func togglePause(subscription: Subscription,
                            context: ModelContext,
                            coordinator: NotificationCoordinator? = nil) async throws {
        subscription.isActive.toggle()
        subscription.updatedAt = .now
        try context.save()
        if let coordinator { try? await coordinator.refresh() }
    }

    private func performDelete() {
        Task {
            try? await Self.performDelete(subscription: subscription,
                                          context: context,
                                          coordinator: coordinator,
                                          onDismiss: { dismiss() })
        }
    }

    static func performDelete(subscription: Subscription,
                              context: ModelContext,
                              coordinator: NotificationCoordinator? = nil,
                              onDismiss: () -> Void) async throws {
        try SubscriptionRepository(context: context).delete(subscription)
        if let coordinator { try? await coordinator.refresh() }
        onDismiss()
    }
}
