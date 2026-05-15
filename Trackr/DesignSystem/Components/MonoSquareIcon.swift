import SwiftUI

/// 36×36 dark square showing a 2-letter pixel-font monogram. Subscription icon
/// default when no real product logo is bundled.
struct MonoSquareIcon: View {
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
                    size: size * 0.4,
                    color: foregroundColor,
                    tracking: 0.5
                )
            )
            .frame(width: size, height: size)
    }

    /// Derives a 2-letter uppercase monogram from a product name.
    /// Rules:
    ///   - Strip non-letter characters.
    ///   - 1 word -> first two letters of that word (or pad).
    ///   - 2+ words -> first letter of each of the first two words.
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
