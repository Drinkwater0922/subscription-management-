import SwiftUI
import SwiftData
import PhotosUI

struct AddSubscriptionSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.notificationCoordinator) private var coordinator
    @Environment(ProEntitlement.self) private var entitlement
    @Environment(PaywallTriggerCoordinator.self) private var paywallTrigger
    @Environment(\.haptics) private var haptics
    @Environment(\.photoImportPipeline) private var photoImport

    private enum Tab: Hashable { case custom, library }
    @State private var selectedTab: Tab = .custom
    @State private var pendingPresetId: String?
    @State private var presetItems: [PresetItem] = []
    @State private var presetSearch: String = ""

    @State private var draft: SubscriptionDraft
    @State private var errorMessage: String?
    @State private var hasResolvedDefaultCurrency = false

    // Photo import state
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var importBanner: String?
    @State private var isImporting = false
    @State private var bulkCandidates: [ExtractedSubscription] = []
    @State private var showBulkSheet = false

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
        .sheet(isPresented: $showBulkSheet) {
            BulkImportSheet(
                candidates: bulkCandidates,
                onCancel: { showBulkSheet = false },
                onConfirm: runBulkImport
            )
            .preferredColorScheme(.dark)
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
            photoImportRow
            nameField
            amountAndCurrency
            cycleField
            startDateField
            trialEndsField
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

    @ViewBuilder
    private var photoImportRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            PhotosPicker(selection: $photoPickerItem,
                         matching: .images,
                         photoLibrary: .shared()) {
                HStack(spacing: 8) {
                    PixelText(isImporting ? "SCANNING…" : "IMPORT FROM PHOTO",
                              size: TrackrTypography.Scale.body,
                              color: TrackrColors.accent,
                              tracking: 2)
                    Spacer()
                    PixelText("→",
                              size: TrackrTypography.Scale.body,
                              color: TrackrColors.accent,
                              tracking: 0)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .disabled(isImporting)
            if let importBanner {
                PixelText(importBanner.uppercased(),
                          size: TrackrTypography.Scale.caption,
                          color: TrackrColors.fg2,
                          tracking: 1.5)
            }
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            runPhotoImport(item: newItem)
        }
    }

    private func runPhotoImport(item: PhotosPickerItem) {
        Task {
            isImporting = true
            defer { isImporting = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    importBanner = "Couldn't load photo"
                    return
                }
                let presets = presetItems.isEmpty
                    ? (try? PresetBundleLoader.loadBundled().items) ?? []
                    : presetItems
                let pipeline = photoImport ?? FallbackPhotoImport()
                let textLines = try await pipeline.recognizeText(in: data)
                let candidates = SubscriptionExtractor.extractAll(
                    textLines: textLines, presets: presets
                )
                photoPickerItem = nil

                if candidates.count > 1 {
                    // Multi-sub screenshot — show the picker.
                    bulkCandidates = candidates
                    showBulkSheet = true
                    importBanner = nil
                    haptics?.play(.success)
                } else {
                    // Single-sub or empty — fill the current draft (existing flow).
                    let result = candidates.first
                        ?? SubscriptionExtractor.extract(
                            lines: textLines.map(\.text), presets: presets
                        )
                    result.apply(to: &draft)
                    importBanner = Self.bannerMessage(for: result)
                    haptics?.play(result.confidence > 0 ? .success : .warning)
                }
            } catch {
                importBanner = "Scan failed — try a clearer photo"
                haptics?.play(.warning)
            }
        }
    }

    /// Batch-save every candidate the user kept in the bulk sheet. Reuses the
    /// existing `submit` helper so the free-tier gate, FX pinning, and
    /// notification refresh all apply per row.
    private func runBulkImport(_ picks: [ExtractedSubscription]) {
        showBulkSheet = false
        guard !picks.isEmpty else { return }
        Task {
            let homeCurrency = (try? SettingsRepository(context: context).currentSettings().defaultCurrency) ?? "USD"
            var saved = 0
            var skipped = 0
            for candidate in picks {
                var rowDraft = SubscriptionDraft.empty(defaultCurrency: homeCurrency)
                candidate.apply(to: &rowDraft)
                if rowDraft.amountString.isEmpty { rowDraft.amountString = "0" }
                if rowDraft.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    rowDraft.name = "Untitled"
                }
                let err = await Self.submit(
                    draft: rowDraft,
                    presetId: candidate.matchedPreset?.id,
                    proStatus: entitlement.current,
                    context: context,
                    coordinator: coordinator,
                    onLimitExceeded: { skipped += 1 },
                    onDismiss: { /* don't dismiss the sheet per-row */ }
                )
                if err == nil { saved += 1 } else { skipped += 1 }
            }
            importBanner = "Imported \(saved). Skipped \(skipped)."
            haptics?.play(.success)
            // Close the parent sheet after a successful batch.
            if saved > 0 { dismiss() }
        }
    }

    /// Pure formatter exposed for tests.
    static func bannerMessage(for result: ExtractedSubscription) -> String {
        switch result.confidence {
        case 1.0:
            if let name = result.matchedPreset?.name {
                return "Matched \(name) — confirm and save"
            }
            return "Imported — confirm and save"
        case 0.5:
            if result.matchedPreset != nil {
                return "Found a match — add the price and save"
            }
            return "Captured price — add a name and save"
        default:
            return "Couldn't read this one — try a clearer photo"
        }
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

    /// v1.1 free-trial entry. Off by default; when the user toggles it on,
    /// a date picker appears and the sub lands in the FREE TRIALS group on
    /// Home until the date passes.
    private var trialEndsField: some View {
        let hasTrial = Binding<Bool>(
            get: { draft.trialEndsAt != nil },
            set: { isOn in
                if isOn {
                    if draft.trialEndsAt == nil {
                        // Default to 7 days out — common free-trial length;
                        // user can adjust.
                        draft.trialEndsAt = Calendar.current.date(
                            byAdding: .day, value: 7, to: draft.startDate
                        ) ?? draft.startDate
                    }
                } else {
                    draft.trialEndsAt = nil
                }
            }
        )
        let trialBinding = Binding<Date>(
            get: { draft.trialEndsAt ?? draft.startDate },
            set: { draft.trialEndsAt = $0 }
        )
        return labeled("FREE TRIAL") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: hasTrial) {
                    PixelText("TRACK AS FREE TRIAL",
                              size: TrackrTypography.Scale.caption,
                              color: TrackrColors.fg2,
                              tracking: 1.5)
                }
                .tint(TrackrColors.accent)
                if hasTrial.wrappedValue {
                    DatePicker("", selection: trialBinding, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
            }
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
                haptics?.play(.warning)
                errorMessage = msg
            } else {
                haptics?.play(.success)
                errorMessage = nil
            }
        }
    }

    private func handleLimitExceeded() {
        paywallTrigger.present(reason: .subscriptionLimit)
        dismiss()
    }

    /// Pure-ish submit helper exposed for tests. Returns `nil` on success
    /// or a user-facing error message on failure.
    ///
    /// **v1.1:** no FX pinning. Subscriptions are saved in their own
    /// currency; the Home hero converts at display time via the cached
    /// `FXRateTable`. Legacy pinned-rate fields stay on the model for
    /// existing TestFlight rows but are no longer written.
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
