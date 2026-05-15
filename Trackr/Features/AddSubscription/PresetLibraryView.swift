import SwiftUI

/// LIBRARY tab inside the Add Subscription sheet. Pure presentation — receives
/// the catalog items and a callback; never touches SwiftData.
struct PresetLibraryView: View {

    let items: [PresetItem]
    @Binding var searchQuery: String
    let onSelect: (PresetItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            DashedDivider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedKeys, id: \.self) { category in
                        section(for: category)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            PixelText("🔍", size: 14, color: TrackrColors.fg2, tracking: 0)
            TextField("Search library", text: $searchQuery)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var filtered: [PresetItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0.name.lowercased().contains(q) }
    }

    private var grouped: [Category: [PresetItem]] {
        Dictionary(grouping: filtered, by: \.category)
    }

    private var groupedKeys: [Category] {
        Category.allCases.filter { grouped[$0] != nil }
    }

    @ViewBuilder
    private func section(for category: Category) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PixelText(category.displayName.uppercased(),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            ForEach(grouped[category] ?? [], id: \.id) { item in
                Button { onSelect(item) } label: { row(item) }
                .buttonStyle(.plain)
                DashedDivider()
            }
        }
    }

    @ViewBuilder
    private func row(_ item: PresetItem) -> some View {
        HStack(spacing: 12) {
            MonoSquareIcon(name: item.name)
            VStack(alignment: .leading, spacing: 2) {
                PixelText(item.name.uppercased(),
                          size: TrackrTypography.Scale.value, tracking: 1.5)
                PixelText(item.defaultPlanName.uppercased(),
                          size: TrackrTypography.Scale.sectionLabel,
                          color: TrackrColors.fg2, tracking: 1.5)
            }
            Spacer()
            PixelText(AmountFormatter.format(item.defaultAmount,
                                              currency: item.defaultCurrency),
                      size: TrackrTypography.Scale.value, tracking: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
