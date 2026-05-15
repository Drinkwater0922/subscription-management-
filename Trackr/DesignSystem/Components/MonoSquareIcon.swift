import SwiftUI

/// 36×36 dark square showing a 2-letter pixel-font monogram. Subscription icon
/// default when no real product logo is bundled.
struct MonoSquareIcon: View {
    /// Monogram glyph height as a fraction of the square's side length.
    /// 0.4 keeps the two pixel-font characters visually balanced inside the square
    /// with comfortable padding on all sides. Adjust together with the visual review.
    private static let monogramScaleFactor: CGFloat = 0.4

    let name: String
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color

    init(
        name: String,
        size: CGFloat = 36,
        background: Color = TrackrColors.bg3,
        foreground: Color = TrackrColors.fg
    ) {
        self.name = name
        self.size = size
        self.backgroundColor = background
        self.foregroundColor = foreground
    }

    var body: some View {
        Rectangle()
            .fill(backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(TrackrColors.border, lineWidth: 1)
            )
            .overlay(
                PixelText(
                    Self.monogram(for: name),
                    size: size * Self.monogramScaleFactor,
                    color: foregroundColor,
                    tracking: 0.5
                )
            )
            .frame(width: size, height: size)
    }

    /// Derives an uppercase monogram from a product name. Returns 1 or 2 characters.
    /// Rules:
    ///   - Strip non-letter characters.
    ///   - 1 word, 2+ letters -> first 2 letters uppercased.
    ///   - 1 word, 1 letter   -> that letter uppercased (no padding).
    ///   - 2+ words           -> first letter of each of the first two words, uppercased.
    ///   - Empty / whitespace -> "?".
    static func monogram(for name: String) -> String {
        let words = name
            .split(whereSeparator: { !$0.isLetter })
            .map { String($0) }

        switch words.count {
        case 0:
            return "?"
        case 1:
            let word = words[0].uppercased()
            if word.count >= 2 {
                return String(word.prefix(2))
            } else {
                return word    // single letter — keep as-is
            }
        default:
            let first = words[0].uppercased().prefix(1)
            let second = words[1].uppercased().prefix(1)
            return String(first) + String(second)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            MonoSquareIcon(name: "AI Chat Pro")
            MonoSquareIcon(name: "Code Editor +")
            MonoSquareIcon(name: "Copilot")
            MonoSquareIcon(name: "Design Gen")
        }
        HStack(spacing: 12) {
            MonoSquareIcon(name: "Search AI")
            MonoSquareIcon(name: "Video Gen")
            MonoSquareIcon(name: "X")
            MonoSquareIcon(name: "")
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(TrackrColors.bg)
}
