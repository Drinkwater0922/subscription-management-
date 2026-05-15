import SwiftUI
import SwiftData

struct AddSubscriptionSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.notificationCoordinator) private var coordinator
    @Environment(ProEntitlement.self) private var entitlement

    private enum Tab: Hashable { case custom, library }
    @State private var selectedTab: Tab = .custom
    @State private var pendingPresetId: String?
    @State private var presetItems: [PresetItem] = []
    @State private var presetSearch: String = ""

    @State private var draft: SubscriptionDraft
    @State private var errorMessage: String?
    @State private var hasResolvedDefaultCurrency = false

    /// Production callers use the default initializer. The `initialDraft` overload
    /// is for snapshot tests that need to render a pre-filled form.
    init(initialDraft: SubscriptionDraft? = nil) {
        if let initialDraft {
            _draft = State(initialValue: initialDraft)
        } else {
            _draft = State(initialValue: .empty(defaultCurrency: "USD"))
        }
    }

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                tabPicker
                Divider().background(TrackrColors.border)
                ScrollView {
                    Group {
                        if selectedTab == .custom {
                            customForm
                        } else {
                            PresetLibraryView(items: presetItems,
                                              searchQuery: $presetSearch,
                                              onSelect: selectPreset)
                        }
                    }
                    .padding(selectedTab == .custom ? 20 : 0)
                }
                if selectedTab == .custom { footer }
            }
        }
        .onAppear {
            guard !hasResolvedDefaultCurrency else { return }
            hasResolvedDefaultCurrency = true
            if draft.currency.isEmpty {
                draft = SubscriptionDraft.empty(
                    defaultCurrency: (try? SettingsRepository(context: context).currentSettings().defaultCurrency) ?? "USD"
                )
            }
            if presetItems.isEmpty {
                presetItems = (try? PresetBundleLoader.loadBundled().items) ?? []
            }
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text("CUSTOM").tag(Tab.custom)
            Text("LIBRARY").tag(Tab.library)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var customForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            nameField
            amountAndCurrency
            cycleField
            startDateField
            categoryField
            planNameField
            notesField
            urlField
            if let errorMessage {
                PixelText(errorMessage.uppercased(),
                          size: TrackrTypography.Scale.caption,
                          color: TrackrColors.warn,
                          tracking: 1.5)
            }
        }
    }

    private func selectPreset(_ item: PresetItem) {
        draft = item.toDraft(defaultStart: draft.startDate)
        pendingPresetId = item.id
        selectedTab = .custom
    }

    private var header: some View {
        HStack {
            Button("CANCEL") { dismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            PixelText("ADD SUB", size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            Button("SAVE") { attemptSave() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.accent)
        }
        .padding(20)
    }

    private var nameField: some View {
        labeled("NAME") {
            TextField("", text: $draft.name)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
        }
    }

    private var amountAndCurrency: some View {
        HStack(spacing: 16) {
            labeled("AMOUNT") {
                TextField("0.00", text: $draft.amountString)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
                    .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
            }
            labeled("CCY") {
                TextField("USD", text: $draft.currency)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
                    .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                    .frame(width: 64)
            }
        }
    }

    private var cycleField: some View {
        labeled("CYCLE") {
            Picker("", selection: $draft.billingCycle) {
                Text("MONTHLY").tag(BillingCycle.monthly)
                Text("YEARLY").tag(BillingCycle.yearly)
                Text("WEEKLY").tag(BillingCycle.weekly)
                Text("CUSTOM").tag(BillingCycle.customDays(draft.customDays))
            }
            .pickerStyle(.segmented)
            if case .customDays = draft.billingCycle {
                HStack {
                    PixelText("EVERY", size: TrackrTypography.Scale.caption, color: TrackrColors.fg2, tracking: 1.5)
                    TextField("30", value: $draft.customDays, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .foregroundStyle(TrackrColors.fg)
                        .frame(width: 60)
                    PixelText("DAYS", size: TrackrTypography.Scale.caption, color: TrackrColors.fg2, tracking: 1.5)
                }
            }
        }
    }

    private var startDateField: some View {
        labeled("STARTS") {
            DatePicker("", selection: $draft.startDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
        }
    }

    private var categoryField: some View {
        labeled("CATEGORY") {
            Picker("", selection: $draft.category) {
                ForEach(Category.allCases, id: \.self) { cat in
                    Text(cat.displayName.uppercased()).tag(cat)
                }
            }
            .pickerStyle(.menu)
            .tint(TrackrColors.fg)
        }
    }

    private var planNameField: some View {
        labeled("PLAN") {
            TextField("optional", text: $draft.planName)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
        }
    }

    private var notesField: some View {
        labeled("NOTES") {
            TextField("optional", text: $draft.notes, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
        }
    }

    private var urlField: some View {
        labeled("URL") {
            TextField("https://", text: $draft.urlString)
                .keyboardType(.URL)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            DashedDivider()
            TrackrButton("SAVE") { attemptSave() }
                .padding(20)
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

    private func attemptSave() {
        Task {
            if let msg = await Self.submit(draft: draft,
                                            presetId: pendingPresetId,
                                            proStatus: entitlement.current,
                                            context: context,
                                            coordinator: coordinator,
                                            onLimitExceeded: handleLimitExceeded,
                                            onDismiss: { dismiss() }) {
                errorMessage = msg
            } else {
                errorMessage = nil
            }
        }
    }

    private func handleLimitExceeded() {
        // Task 7 fills this in (presents PaywallTriggerCoordinator). For now,
        // the inline `errorMessage` already informs the user.
    }

    /// Pure-ish submit helper exposed for tests. Returns `nil` on success or a
    /// user-facing error message on failure.
    @discardableResult
    static func submit(draft: SubscriptionDraft,
                       presetId: String? = nil,
                       proStatus: ProStatus = .proLifetime,
                       context: ModelContext,
                       coordinator: NotificationCoordinator? = nil,
                       onLimitExceeded: () -> Void = {},
                       onDismiss: () -> Void) async -> String? {
        do {
            // Free-tier gate.
            let count = try SubscriptionRepository(context: context).count()
            if !FeatureGate.canAddSubscription(currentCount: count, proStatus: proStatus) {
                onLimitExceeded()
                return "Free tier is limited to \(FeatureGate.freeSubscriptionLimit) subscriptions. Upgrade to Pro for unlimited."
            }

            let sub = try draft.makeSubscription()
            if let presetId { sub.presetId = presetId }
            try SubscriptionRepository(context: context).insert(sub)
            if let coordinator {
                try? await coordinator.refresh()
            }
            onDismiss()
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
}

#Preview {
    AddSubscriptionSheet()
        .preferredColorScheme(.dark)
}
