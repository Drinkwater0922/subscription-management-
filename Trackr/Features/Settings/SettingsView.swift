import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.notificationCoordinator) private var coordinator

    @State private var leadDays: Set<Int> = [3, 1]
    @State private var notifyHour: Int = 9
    @State private var currency: String = "USD"
    @State private var language: String = "auto"
    @Environment(ProEntitlement.self) private var entitlement
    @Environment(PaywallTriggerCoordinator.self) private var paywallTrigger

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().background(TrackrColors.border)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        leadDaysSection
                        notifyHourSection
                        currencySection
                        languageSection
                        proStatusSection
                        linksSection
                    }
                    .padding(20)
                }
            }
        }
        .onAppear { hydrateFromStore() }
    }

    private var header: some View {
        HStack {
            Button(String(localized: "CLOSE")) { saveAndDismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.accent)
            Spacer()
            PixelText(LocalizedStringKey("SETTINGS"), size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(20)
    }

    private var leadDaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText(LocalizedStringKey("REMIND ME"),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            HStack(spacing: 8) {
                ForEach([7, 3, 1], id: \.self) { d in
                    chip(label: "\(d) DAY\(d == 1 ? "" : "S") BEFORE",
                         isOn: leadDays.contains(d)) {
                        toggle(day: d)
                    }
                }
            }
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var notifyHourSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText("AT", size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            Picker("", selection: $notifyHour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d:00", h)).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(LocalizedStringKey("DEFAULT CURRENCY"),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            TextField("USD", text: $currency)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .frame(width: 80)
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private func chip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PixelText(label,
                      size: TrackrTypography.Scale.caption,
                      color: isOn ? TrackrColors.onAccent : TrackrColors.fg,
                      tracking: 1.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isOn ? TrackrColors.accent : TrackrColors.bg2)
                .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func toggle(day: Int) {
        if leadDays.contains(day) { leadDays.remove(day) } else { leadDays.insert(day) }
    }

    private func hydrateFromStore() {
        guard let s = try? SettingsRepository(context: context).currentSettings() else { return }
        leadDays = Set(s.leadDays)
        notifyHour = s.notifyHour
        currency = s.defaultCurrency
        language = s.language
    }

    private func saveAndDismiss() {
        Task {
            await Self.commit(
                leadDays: Array(leadDays).sorted(by: >),
                notifyHour: notifyHour,
                currency: currency,
                language: language,
                context: context,
                coordinator: coordinator
            )
            dismiss()
        }
    }

    /// Pure-ish helper exposed for testing — writes to the store and refreshes notifications.
    static func commit(
        leadDays: [Int],
        notifyHour: Int,
        currency: String,
        language: String,
        context: ModelContext,
        coordinator: NotificationCoordinator?
    ) async {
        do {
            let s = try SettingsRepository(context: context).currentSettings()
            s.leadDays = leadDays
            s.notifyHour = notifyHour
            s.defaultCurrency = currency.uppercased()
            s.language = language
            try context.save()
            if let coordinator { try? await coordinator.refresh() }
        } catch { }
    }
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText(LocalizedStringKey("LANGUAGE"),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            HStack(spacing: 8) {
                languageChip(value: "auto",    labelKey: LocalizedStringKey("AUTO"))
                languageChip(value: "en",      labelKey: LocalizedStringKey("ENGLISH"))
                languageChip(value: "zh-Hans", labelKey: LocalizedStringKey("简体中文"))
            }
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private func languageChip(value: String, labelKey: LocalizedStringKey) -> some View {
        let isOn = language == value
        Button(action: { language = value }) {
            PixelText(labelKey,
                      size: TrackrTypography.Scale.caption,
                      color: isOn ? TrackrColors.onAccent : TrackrColors.fg,
                      tracking: 1.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isOn ? TrackrColors.accent : TrackrColors.bg2)
                .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var proStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText(LocalizedStringKey("PRO STATUS"),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            HStack {
                PixelText(proStatusLabel,
                          size: TrackrTypography.Scale.value,
                          color: entitlement.current == .free ? TrackrColors.fg2 : TrackrColors.accent,
                          tracking: 1.5)
                Spacer()
                if entitlement.current == .free {
                    Button(action: { paywallTrigger.present(reason: .manual) }) {
                        PixelText(LocalizedStringKey("UPGRADE"),
                                  size: TrackrTypography.Scale.body,
                                  color: TrackrColors.accent, tracking: 1.5)
                    }.buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                        PixelText(LocalizedStringKey("MANAGE SUBSCRIPTION"),
                                  size: TrackrTypography.Scale.body,
                                  color: TrackrColors.accent, tracking: 1.5)
                    }
                }
            }
            TrackrButton(String(localized: "RESTORE PURCHASES"), variant: .outlined) {
                Task { await entitlement.refresh() }
            }
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var proStatusLabel: LocalizedStringKey {
        switch entitlement.current {
        case .free:        return LocalizedStringKey("FREE")
        case .proMonthly:  return LocalizedStringKey("PRO MONTHLY")
        case .proLifetime: return LocalizedStringKey("PRO LIFETIME")
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Link(destination: URL(string: "https://trackr.placeholder/privacy")!) {
                PixelText(LocalizedStringKey("PRIVACY POLICY"),
                          size: TrackrTypography.Scale.body,
                          color: TrackrColors.fg2, tracking: 1.5)
            }
            Link(destination: URL(string: "https://trackr.placeholder/terms")!) {
                PixelText(LocalizedStringKey("TERMS OF SERVICE"),
                          size: TrackrTypography.Scale.body,
                          color: TrackrColors.fg2, tracking: 1.5)
            }
        }
    }
}

#Preview { SettingsView().preferredColorScheme(.dark) }
