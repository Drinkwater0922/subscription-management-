import Foundation

/// Brand-icon resolution for the library and Home rows. Three-tier lookup:
///
///   1. **Asset image** — `assetByPresetId[id]` returns the name of a bundled
///      SVG asset (Simple Icons, MIT-licensed library; brand marks remain the
///      property of their owners and are used here for nominative reference).
///   2. **Emoji glyph** — `glyphByPresetId[id]` returns a representative
///      emoji.
///   3. **Category fallback** — `glyphByCategory[cat]` is the last resort
///      before `MonoSquareIcon` shows the 2-letter monogram.
///
/// Asset names mirror our preset-id "slug" namespace, *not* Simple Icons'
/// raw slug — so Grok (which has no Simple Icons entry) doesn't have an asset
/// at all, and ChatGPT maps to `chatgpt` (containing the OpenAI logo SVG).
enum PresetIcons {

    /// Bundled SVG asset name, keyed by preset id. Asset Catalog lookup —
    /// the SVGs live in `Trackr/Assets.xcassets/BrandIcons/<name>.imageset/`.
    /// Misses fall through to emoji.
    static let assetByPresetId: [String: String] = [
        // AI
        "chatgpt.plus":          "chatgpt",
        "chatgpt.pro":           "chatgpt",
        "claude.pro":            "claude",
        "claude.max5x":          "claude",
        "claude.max20x":         "claude",
        "gemini.advanced":       "gemini",
        "grok.supergrok":        "x",
        "grok.heavy":            "x",
        "perplexity.pro":        "perplexity",
        "suno.pro":              "suno",
        "cursor.pro":            "cursor",
        // Streaming
        "netflix.standard":      "netflix",
        "hbomax.standard":       "max",
        "hulu.basic":            "hulu",
        "primevideo.standalone": "primevideo",
        "appletv.plus":          "appletv",
        "youtube.premium":       "youtube",
        // Music
        "spotify.premium":       "spotify",
        "apple.music":           "applemusic",
        "tidal.hifi":            "tidal",
        // Games
        "psn.plus.essential":    "playstation",
        "xbox.gamepass.ultimate":"xbox",
        "apple.arcade":          "apple",
        "nintendo.switch.online":"nintendoswitch",
        // Cloud
        "icloud.50":             "icloud",
        "icloud.200":            "icloud",
        "icloud.2tb":            "icloud",
        "googleone.200":         "googledrive",
        "dropbox.plus":          "dropbox",
        // Productivity
        "notion.plus":           "notion",
        "microsoft365.personal": "microsoftoffice",
        "1password.individual":  "1password",
        // Dev
        "github.copilot":        "githubcopilot",
        "jetbrains.allproducts": "jetbrains",
        // News
        "nytimes.allaccess":     "newyorktimes",
        // Fitness
        "fitness.plus":          "apple",
        "strava.premium":        "strava",
        // Learning
        "duolingo.super":        "duolingo",
        // Shopping
        "amazon.prime":          "amazon",
        // Midjourney, masterclass, costco, disneyplus, wsj — no Simple Icons
        // entry. Emoji handles those.
    ]


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

    /// Asset name for a preset library row (nil if no bundled SVG).
    static func assetName(for preset: PresetItem) -> String? {
        assetByPresetId[preset.id]
    }

    /// Asset name for a stored subscription (only when it's preset-backed).
    static func assetName(for sub: Subscription) -> String? {
        guard let presetId = sub.presetId else { return nil }
        return assetByPresetId[presetId]
    }

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
