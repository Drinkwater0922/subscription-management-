import SwiftUI

/// Design-system color tokens. All app code should read colors through this enum.
/// Hex values match the spec; do not introduce ad-hoc colors elsewhere.
enum TrackrColors {
    /// App background. Pure black per spec.
    static let bg     = Color(hex: 0x000000)
    /// Subtle panel background.
    static let bg2    = Color(hex: 0x0E0E10)
    /// Mono-square icon background.
    static let bg3    = Color(hex: 0x1A1A1D)
    /// Hairline borders and dashed dividers.
    static let border = Color(hex: 0x2A2A2D)

    /// Primary text.
    static let fg     = Color(hex: 0xF5F5F7)
    /// Secondary text.
    static let fg2    = Color(hex: 0x8A8A8D)
    /// Tertiary / disabled text.
    static let fg3    = Color(hex: 0x4A4A4D)

    /// Brand accent (lime). Used on FAB, CTAs, "due soon" countdowns.
    static let accent = Color(hex: 0xC7F284)
    /// True-warning red. Reserved for overdue subscriptions and price-increase alerts.
    static let warn   = Color(hex: 0xA8453D)
}

extension Color {
    /// Construct a fully-opaque SwiftUI Color from a 6-digit hex literal like `0xC7F284`.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, opacity: 1.0)
    }
}
