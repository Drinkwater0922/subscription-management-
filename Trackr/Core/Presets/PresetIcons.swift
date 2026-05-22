import Foundation
import SwiftUI

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
/// at all and falls back to emoji.
enum PresetIcons {

    /// Bundled SVG asset name, keyed by preset id. Asset Catalog lookup —
    /// the SVGs live in `Trackr/Assets.xcassets/BrandIcons/<name>.imageset/`.
    /// Misses fall through to emoji.
    static let assetByPresetId: [String: String] = [
        // AI
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
        "icloud.2tb.cn":         "icloud",
        // Chinese apps + Plaud + Apple Developer — real App Store icons
        // fetched via Apple's public iTunes Search API. These imagesets use
        // `template-rendering-intent: original` so they render in full
        // colour (App Store icons are colourful, not monochrome).
        "plaud.ai":              "plaud",
        "maimai.member":         "maimai",
        "xunfei.tingjian":       "xunfei",
        "iqiyi.vip":             "iqiyi",
        "tencent.video.vip":     "tencent-video",
        "youku.vip":             "youku",
        "bilibili.premium":      "bilibili-app",       // overrides Simple Icons
        "mango.tv.vip":          "mango-tv",
        "netease.music":         "netease-music",
        "qq.music":              "qq-music",           // overrides Simple Icons
        "wechat.reading":        "wechat-reading",     // overrides Simple Icons
        "xiaoyuzhou.plus":       "xiaoyuzhou",
        "jike.app":              "jike",
        "caixin.pro":            "caixin",
        "douyin.vip":            "douyin-app",         // overrides Simple Icons
        "xiaohongshu":           "xiaohongshu",
        "dingtalk.pro":          "dingtalk-app",
        "feishu.pro":            "feishu",
        "apple.developer":       "apple-developer",
        // Midjourney, masterclass, costco, disneyplus, wsj — no Simple
        // Icons entry and not worth fetching as full App Store icons until
        // there's user demand; emoji handles those.
    ]


    /// Keyed by preset id (the same id used in `presets.bundled.json` and
    /// stored on `Subscription.presetId` when the row was added from the library).
    static let glyphByPresetId: [String: String] = [
        // AI
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
        // Chinese apps
        "plaud.ai":              "🎙",
        "maimai.member":         "🔵",
        "xunfei.tingjian":       "🎤",
        "iqiyi.vip":             "🎬",
        "tencent.video.vip":     "📺",
        "youku.vip":             "📺",
        "bilibili.premium":      "📺",
        "mango.tv.vip":          "🥭",
        "netease.music":         "🎵",
        "qq.music":              "🎶",
        "xiaoyuzhou.plus":       "🪐",
        "wechat.reading":        "📖",
        "caixin.pro":            "📰",
        "jike.app":              "🟡",
        "douyin.vip":            "🎵",
        "xiaohongshu":           "📕",
        "dingtalk.pro":          "💼",
        "feishu.pro":            "✈️",
        "apple.developer":       "🍎",
        "icloud.2tb.cn":         "☁️",
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

    /// Official brand colors per Simple Icons. Used to tint the bundled SVG
    /// so logos read at a glance instead of disappearing into a sea of
    /// monochrome. Brands whose official color is black / near-black (Apple,
    /// X, Tidal, JetBrains, NYTimes, Notion, GitHub Copilot, Cursor) are
    /// deliberately omitted — they're invisible on our dark background, so
    /// we let them fall back to the foreground white in `MonoSquareIcon`.
    static let tintByPresetId: [String: Color] = [
        // AI
        "claude.pro":            Color(hex: 0xD97757),   // Anthropic orange
        "claude.max5x":          Color(hex: 0xD97757),
        "claude.max20x":         Color(hex: 0xD97757),
        "gemini.advanced":       Color(hex: 0x8E75B2),   // Gemini purple
        "perplexity.pro":        Color(hex: 0x20B8CD),   // Perplexity teal
        // Streaming
        "netflix.standard":      Color(hex: 0xE50914),   // Netflix red
        "hbomax.standard":       Color(hex: 0x002BE7),   // Max blue
        "hulu.basic":            Color(hex: 0x1CE783),   // Hulu green
        "primevideo.standalone": Color(hex: 0x00A8E1),   // Prime Video cyan
        "youtube.premium":       Color(hex: 0xFF0000),   // YouTube red
        // Music
        "spotify.premium":       Color(hex: 0x1DB954),   // Spotify green
        "apple.music":           Color(hex: 0xFA243C),   // Apple Music pink-red
        // Games
        "psn.plus.essential":    Color(hex: 0x006FCD),   // PlayStation blue
        "xbox.gamepass.ultimate":Color(hex: 0x107C10),   // Xbox green
        "nintendo.switch.online":Color(hex: 0xE60012),   // Nintendo red
        // Cloud
        "icloud.50":             Color(hex: 0x3693F3),   // iCloud blue
        "icloud.200":            Color(hex: 0x3693F3),
        "icloud.2tb":            Color(hex: 0x3693F3),
        "googleone.200":         Color(hex: 0x4285F4),   // Google blue
        "dropbox.plus":          Color(hex: 0x0061FF),   // Dropbox blue
        // Productivity
        "microsoft365.personal": Color(hex: 0xD83B01),   // MS Office red
        "1password.individual":  Color(hex: 0x3B66BC),   // 1Password blue
        // Dev / News / Fitness / Learning / Shopping
        "jetbrains.allproducts": Color(hex: 0xFF318C),   // JetBrains magenta accent (logo has it)
        "strava.premium":        Color(hex: 0xFC4C02),   // Strava orange
        "duolingo.super":        Color(hex: 0x58CC02),   // Duolingo green
        "amazon.prime":          Color(hex: 0xFF9900),   // Amazon orange
        // Intentionally omitted (use white foreground for visibility on dark bg):
        //   suno.pro, cursor.pro, grok.*, apple.arcade, fitness.plus,
        //   appletv.plus, github.copilot, notion.plus, nytimes.allaccess
    ]

    /// Brand tint for a preset library row, or `nil` to use the default
    /// foreground color (white).
    static func tint(for preset: PresetItem) -> Color? {
        tintByPresetId[preset.id]
    }

    /// Brand tint for a stored subscription.
    static func tint(for sub: Subscription) -> Color? {
        guard let presetId = sub.presetId else { return nil }
        return tintByPresetId[presetId]
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
