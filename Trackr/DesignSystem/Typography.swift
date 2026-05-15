import SwiftUI

/// Design-system typography tokens. All app code should obtain fonts through this enum.
enum TrackrTypography {

    /// Numeric / heading / label font. VT323 (OFL-licensed pixel font).
    static func pixel(size: CGFloat) -> Font {
        Font.custom("VT323-Regular", size: size)
    }

    /// Body / button-label font. Uses the SF Pro system font.
    static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight)
    }

    /// Canonical type scale. Use these constants instead of hand-rolling sizes.
    enum Scale {
        /// 68 — home screen hero amount (e.g. "$147.92").
        static let hero: CGFloat = 68
        /// 32 — secondary big numbers (currency in hero, large countdowns).
        static let largeNumber: CGFloat = 32
        /// 22 — modal titles, screen names.
        static let title: CGFloat = 22
        /// 18 — row prices, detail values.
        static let value: CGFloat = 18
        /// 14 — body, button labels.
        static let body: CGFloat = 14
        /// 13 — section labels, top-bar metadata.
        static let sectionLabel: CGFloat = 13
        /// 11 — small captions.
        static let caption: CGFloat = 11
    }
}
