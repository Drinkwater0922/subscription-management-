import SwiftUI

/// 36×36 dark square subscription icon. Renders one of two glyph styles:
/// - When `glyph` is supplied (an emoji or single character), it's drawn at
///   roughly 60% of the square so the icon is recognizable at a glance.
/// - When `glyph` is nil, falls back to a 2-letter pixel-font monogram
///   derived from `name`.
///
/// Library presets pass `PresetIcons.glyph(for:)`; custom subs without an
/// explicit emoji fall through to the monogram.
struct MonoSquareIcon: View {
    /// Monogram glyph height as a fraction of the square's side length.
    /// 0.4 keeps the two pixel-font characters visually balanced inside the square.
    private static let monogramScaleFactor: CGFloat = 0.4
    /// Emoji renders smaller-feeling than text at the same point size — bump it.
    private static let emojiScaleFactor: CGFloat = 0.55

    let name: String
    let glyph: String?
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color

    init(
        name: String,
        glyph: String? = nil,
        size: CGFloat = 36,
        background: Color = TrackrColors.bg3,
        foreground: Color = TrackrColors.fg
    ) {
        self.name = name
        self.glyph = glyph
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
            .overlay(glyphOverlay)
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var glyphOverlay: some View {
        if let glyph, !glyph.isEmpty {
            // Emoji renders via the system font, not VT323 — pixel font has
            // no emoji glyphs.
            Text(glyph)
                .font(.system(size: size * Self.emojiScaleFactor))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        } else {
            PixelText(
                Self.monogram(for: name),
                size: size * Self.monogramScaleFactor,
                color: foregroundColor,
                tracking: 0.5
            )
        }
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
