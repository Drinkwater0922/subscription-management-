import Foundation

/// Per-preset emoji glyph for the library and Home rows. Emojis are chosen for
/// recognizability + zero licensing concerns (real brand marks have trademark
/// restrictions). When a preset isn't in the map we fall back to a category
/// emoji, and from there to the typographic monogram in `MonoSquareIcon`.
enum PresetIcons {

    /// Keyed by preset id (the same id used in `presets.bundled.json` and
    /// stored on `Subscription.presetId` when the row was added from the library).
    static let glyphByPresetId: [String: String] = [
        // AI
        "chatgpt.plus":          "💬",
        "chatgpt.pro":           "💬",
        "claude.pro":            "🤖",
        "claude.max5x":          "🤖",
        "claude.max20x":         "🤖",
        "gemini.advanced":       "✨",
        "grok.supergrok":        "🛰",
        "grok.heavy":            "🛰",
        "perplexity.pro":        "🔎",
        "midjourney.standard":   "🎨",
        "suno.pro":              "🎵",
        "cursor.pro":            "⌨️",
        // Streaming
        "netflix.standard":      "🎬",
        "disneyplus.standard":   "🏰",
        "hbomax.standard":       "🎭",
        "hulu.basic":            "📺",
        "primevideo.standalone": "📦",
        "appletv.plus":          "🍎",
        "youtube.premium":       "▶️",
        // Music
        "spotify.premium":       "🎧",
        "apple.music":           "🎼",
        "tidal.hifi":            "🌊",
        // Games
        "psn.plus.essential":    "🎮",
        "xbox.gamepass.ultimate":"🎯",
        "apple.arcade":          "🕹",
        "nintendo.switch.online":"🎲",
        // Cloud
        "icloud.50":             "☁️",
        "icloud.200":            "☁️",
        "icloud.2tb":            "☁️",
        "googleone.200":         "📁",
        "dropbox.plus":          "📦",
        // Productivity
        "notion.plus":           "📝",
        "microsoft365.personal": "📊",
        "1password.individual":  "🔐",
        // Dev
        "github.copilot":        "👨‍💻",
        "jetbrains.allproducts": "🧰",
        // News
        "nytimes.allaccess":     "📰",
        "wsj.digital":           "📈",
        // Fitness
        "fitness.plus":          "💪",
        "strava.premium":        "🏃",
        // Learning
        "duolingo.super":        "🦉",
        "masterclass.standard":  "🎓",
        // Shopping
        "amazon.prime":          "🛒",
        "costco.gold":           "🛍",
    ]

    /// Fallback when the preset id isn't in the map (or when a sub was added
    /// custom, with no preset link at all).
    static let glyphByCategory: [Category: String] = [
        .ai:           "🤖",
        .streaming:    "🎬",
        .music:        "🎵",
        .games:        "🎮",
        .cloud:        "☁️",
        .productivity: "📝",
        .dev:          "💻",
        .news:         "📰",
        .fitness:      "💪",
        .learning:     "🎓",
        .shopping:     "🛒",
        .other:        "🔹",
    ]

    /// Resolves a glyph for a preset library row. The row's `iconRef` is
    /// `"preset:<id>"`; we strip the prefix and look it up. Category fallback
    /// kicks in for unmapped ids.
    static func glyph(for preset: PresetItem) -> String {
        if let g = glyphByPresetId[preset.id] { return g }
        return glyphByCategory[preset.category] ?? "🔹"
    }

    /// Resolves a glyph for a user's stored subscription. Preference order:
    /// 1. Preset-backed (`presetId` is set) → look up in `glyphByPresetId`.
    /// 2. Custom-added with a user-supplied emoji in `iconRef`
    ///    (`"custom:emoji:<glyph>"`).
    /// 3. Category fallback.
    static func glyph(for sub: Subscription) -> String {
        if let presetId = sub.presetId, let g = glyphByPresetId[presetId] {
            return g
        }
        if sub.iconRef.hasPrefix("custom:emoji:") {
            let g = String(sub.iconRef.dropFirst("custom:emoji:".count))
                       .trimmingCharacters(in: .whitespacesAndNewlines)
            // Ignore the seed default "❓" — prefer category in that case.
            if !g.isEmpty && g != "❓" { return g }
        }
        return glyphByCategory[sub.category] ?? "🔹"
    }
}
