import SwiftUI
import SwiftData

/// Multi-candidate confirmation sheet. Shows up when "Import from Photo"
/// recognised more than one subscription on the same image (typical iOS
/// Subscriptions full-page screenshot). User picks which rows to keep and
/// taps the action button to write them all to SwiftData in one shot.
struct BulkImportSheet: View {

    let candidates: [ExtractedSubscription]
    let onCancel: () -> Void
    let onConfirm: ([ExtractedSubscription]) -> Void

    @State private var selected: Set<Int>

    init(candidates: [ExtractedSubscription],
         onCancel: @escaping () -> Void,
         onConfirm: @escaping ([ExtractedSubscription]) -> Void) {
        self.candidates = candidates
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        // Pre-select every candidate. User unticks the ones they don't want.
        _selected = State(initialValue: Set(0..<candidates.count))
    }

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().background(TrackrColors.border)
                summary
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(candidates.enumerated()), id: \.offset) { idx, candidate in
                            row(index: idx, candidate: candidate)
                            DashedDivider()
                        }
                    }
                }
                footer
            }
        }
    }

    private var header: some View {
        HStack {
            Button(String(localized: "CANCEL"), action: onCancel)
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            PixelText(LocalizedStringKey("IMPORT"),
                      size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(20)
    }

    private var summary: some View {
        HStack {
            PixelText("FOUND \(candidates.count) SUBSCRIPTIONS",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            Spacer()
            Button(allSelected ? String(localized: "DESELECT ALL")
                               : String(localized: "SELECT ALL")) {
                if allSelected { selected.removeAll() }
                else { selected = Set(0..<candidates.count) }
            }
            .font(TrackrTypography.pixel(size: TrackrTypography.Scale.caption))
            .foregroundStyle(TrackrColors.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var allSelected: Bool {
        selected.count == candidates.count
    }

    @ViewBuilder
    private func row(index: Int, candidate: ExtractedSubscription) -> some View {
        let isOn = selected.contains(index)
        Button {
            if isOn { selected.remove(index) } else { selected.insert(index) }
        } label: {
            HStack(spacing: 12) {
                checkbox(isOn: isOn)
                MonoSquareIcon(
                    name: candidate.displayName,
                    // When the row didn't match any preset, use a generic
                    // bookmark glyph so the icon column doesn't fall back to
                    // a meaningless 2-char monogram for unknown brands.
                    glyph: candidate.matchedPreset.map { PresetIcons.glyph(for: $0) } ?? "🔖",
                    assetName: candidate.matchedPreset.flatMap { PresetIcons.assetName(for: $0) },
                    assetTint: candidate.matchedPreset.flatMap { PresetIcons.tint(for: $0) }
                )
                VStack(alignment: .leading, spacing: 2) {
                    PixelText(candidate.displayName.uppercased(),
                              size: TrackrTypography.Scale.value, tracking: 1.5)
                    PixelText(detailLine(for: candidate),
                              size: TrackrTypography.Scale.sectionLabel,
                              color: TrackrColors.fg2,
                              tracking: 1.5)
                }
                Spacer()
                if let amount = candidate.amount {
                    PixelText(AmountFormatter.format(amount,
                                                     currency: candidate.currency ?? "USD"),
                              size: TrackrTypography.Scale.value, tracking: 1)
                } else {
                    PixelText("—",
                              size: TrackrTypography.Scale.value,
                              color: TrackrColors.fg3, tracking: 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func checkbox(isOn: Bool) -> some View {
        Rectangle()
            .fill(isOn ? TrackrColors.accent : Color.clear)
            .frame(width: 20, height: 20)
            .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
            .overlay(
                Group {
                    if isOn {
                        PixelText("✓", size: 14, color: TrackrColors.onAccent, tracking: 0)
                    }
                }
            )
    }

    private func detailLine(for candidate: ExtractedSubscription) -> String {
        var parts: [String] = []
        switch candidate.billingCycle {
        case .monthly?:           parts.append("MONTHLY")
        case .yearly?:            parts.append("YEARLY")
        case .weekly?:            parts.append("WEEKLY")
        case .customDays(let d)?: parts.append("EVERY \(d) DAYS")
        case nil:                 break
        }
        if let preset = candidate.matchedPreset {
            parts.append(preset.category.displayName.uppercased())
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private var footer: some View {
        VStack(spacing: 0) {
            DashedDivider()
            TrackrButton(actionLabel) {
                let picks = selected.sorted().compactMap { idx in
                    candidates.indices.contains(idx) ? candidates[idx] : nil
                }
                onConfirm(picks)
            }
            .disabled(selected.isEmpty)
            .padding(20)
        }
    }

    private var actionLabel: String {
        if selected.isEmpty { return String(localized: "PICK SOME ROWS") }
        return String(format: String(localized: "ADD %d SUBSCRIPTIONS"), selected.count)
    }
}

#Preview {
    BulkImportSheet(
        candidates: [
            ExtractedSubscription(amount: 25, currency: "CNY",
                                  billingCycle: .monthly, matchedPreset: nil,
                                  inferredName: "腾讯视频", confidence: 0.5),
            ExtractedSubscription(amount: 68, currency: "CNY",
                                  billingCycle: .monthly, matchedPreset: nil,
                                  inferredName: "iCloud+", confidence: 0.5),
            ExtractedSubscription(amount: nil, currency: nil,
                                  billingCycle: nil, matchedPreset: nil,
                                  inferredName: "爱奇艺", confidence: 0.5),
        ],
        onCancel: {},
        onConfirm: { _ in }
    )
    .preferredColorScheme(.dark)
}
