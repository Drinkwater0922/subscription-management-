import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.notificationCoordinator) private var coordinator

    @State private var leadDays: Set<Int> = [3, 1]
    @State private var notifyHour: Int = 9
    @State private var currency: String = "USD"

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
    }

    private func saveAndDismiss() {
        Task {
            await Self.commit(
                leadDays: Array(leadDays).sorted(by: >),
                notifyHour: notifyHour,
                currency: currency,
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
        context: ModelContext,
        coordinator: NotificationCoordinator?
    ) async {
        do {
            let s = try SettingsRepository(context: context).currentSettings()
            s.leadDays = leadDays
            s.notifyHour = notifyHour
            s.defaultCurrency = currency.uppercased()
            try context.save()
            if let coordinator { try? await coordinator.refresh() }
        } catch {
            // M4 ignores save failures — there's nowhere meaningful to surface
            // them yet. M8's onboarding adds an error banner.
        }
    }
}

#Preview { SettingsView().preferredColorScheme(.dark) }
