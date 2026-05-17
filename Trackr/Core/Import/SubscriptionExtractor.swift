import Foundation
import CoreGraphics

/// Outcome of running OCR-derived text through `SubscriptionExtractor`. Every
/// field is optional because we'd rather pre-fill what we *do* know than fight
/// for a fully populated draft. `confidence` lets the UI decide whether to
/// auto-submit, ask the user to confirm, or fall back to a manual form.
struct ExtractedSubscription: Equatable {
    var amount: Decimal?
    var currency: String?
    var billingCycle: BillingCycle?
    var matchedPreset: PresetItem?
    /// Free-form name read from the OCR text when no preset matched. Lets the
    /// bulk-import sheet show *some* label for rows the catalog doesn't know.
    var inferredName: String?
    /// 0.0 = nothing useful. 0.5 = price only OR preset only. 1.0 = both.
    var confidence: Double

    static let empty = ExtractedSubscription(amount: nil, currency: nil,
                                              billingCycle: nil,
                                              matchedPreset: nil,
                                              inferredName: nil,
                                              confidence: 0)

    /// User-facing display name. Preset name wins if matched; otherwise the
    /// OCR-derived inference; otherwise "Unknown".
    var displayName: String {
        matchedPreset?.name ?? inferredName ?? "Unknown"
    }

    /// Mutates a draft in place. Fields that were not extracted are left
    /// untouched so the user's pre-existing input survives.
    func apply(to draft: inout SubscriptionDraft) {
        // Preset match seeds name + plan + category + cycle in one shot —
        // but downstream regex hits can still overwrite cycle/currency/amount.
        if let preset = matchedPreset {
            draft.name = preset.name
            draft.planName = preset.defaultPlanName
            draft.amountString = "\(preset.defaultAmount)"
            draft.currency = preset.defaultCurrency
            draft.billingCycle = preset.defaultCycle
            draft.category = preset.category
        } else if let inferredName, !inferredName.isEmpty {
            draft.name = inferredName
        }
        if let amount {
            draft.amountString = Self.canonicalAmountString(amount)
        }
        if let currency { draft.currency = currency }
        if let billingCycle { draft.billingCycle = billingCycle }
    }

    private static func canonicalAmountString(_ d: Decimal) -> String {
        var value = d
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return "\(rounded)"
    }
}

/// Stateless OCR-text → subscription-draft pipeline. Three responsibilities,
/// independently testable:
///   1. `extractAll` — split multi-row screenshots (e.g. iOS Subscriptions
///      page) into one candidate per row.
///   2. `matchPreset` — name-based fuzzy lookup into the catalog.
///   3. `extractPrice` / `extractCycle` — regex over the same text.
enum SubscriptionExtractor {

    // MARK: - Multi-row entry point (M10.5)

    /// For screenshots that contain *multiple* subscriptions (typical iOS
    /// Subscriptions page). Uses the recognised text lines' Y bounds to
    /// cluster lines into rows, then runs single-row extraction on each.
    /// Rows that yielded nothing useful (no name, no price, no preset) are
    /// dropped.
    static func extractAll(textLines: [RecognizedTextLine],
                            presets: [PresetItem]) -> [ExtractedSubscription] {
        guard !textLines.isEmpty else { return [] }
        let rows = groupIntoRows(textLines)
        return rows.compactMap { row in
            let texts = row.map(\.text)
            let result = extract(lines: texts, presets: presets)
            // Keep candidates with at least *something* — confidence > 0 means
            // we got either a preset hit or a price; an unmatched name on its
            // own (e.g. "Gentler") isn't worth offering.
            if result.confidence == 0 && result.matchedPreset == nil && result.amount == nil {
                return nil
            }
            return result
        }
    }

    /// Cluster `RecognizedTextLine`s into visual rows by Y proximity.
    /// Exposed for tests.
    static func groupIntoRows(_ lines: [RecognizedTextLine]) -> [[RecognizedTextLine]] {
        let sorted = lines.sorted { $0.bounds.midY < $1.bounds.midY }
        var rows: [[RecognizedTextLine]] = []
        var current: [RecognizedTextLine] = []
        var currentBottom: CGFloat = -1
        // Threshold tuned for iOS Subscriptions screenshots: rows are ~280px
        // tall on a ~2800px screenshot, with ~30px padding between cards.
        // 0.012 of image height (~30-40px) is comfortably under one row but
        // safely above intra-row text gaps.
        let gapThreshold: CGFloat = 0.012

        for line in sorted {
            if current.isEmpty {
                current = [line]
                currentBottom = line.bounds.maxY
                continue
            }
            let gap = line.bounds.minY - currentBottom
            if gap > gapThreshold {
                rows.append(current)
                current = [line]
            } else {
                current.append(line)
            }
            currentBottom = max(currentBottom, line.bounds.maxY)
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    // MARK: - Single-row entry point

    /// Top-level entry point. `lines` should be one entry per visual row of the
    /// screenshot (Vision's `VNRecognizedTextObservation` already groups text
    /// this way). Empty input → empty result.
    static func extract(lines: [String], presets: [PresetItem]) -> ExtractedSubscription {
        guard !lines.isEmpty else { return .empty }

        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                           .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return .empty }

        let blob = cleaned.joined(separator: " ")

        let preset = matchPreset(in: cleaned, presets: presets)
        let price  = extractPrice(in: blob)
        let cycle  = extractCycle(in: blob)

        // Currency precedence: explicit OCR'd symbol > preset default.
        let currency = price?.currency ?? preset?.defaultCurrency

        let hasPreset = preset != nil
        let hasPrice  = price != nil
        let confidence: Double = (hasPreset && hasPrice) ? 1.0
                                : (hasPreset || hasPrice) ? 0.5
                                : 0.0

        return ExtractedSubscription(
            amount: price?.amount ?? preset?.defaultAmount,
            currency: currency,
            billingCycle: cycle ?? preset?.defaultCycle,
            matchedPreset: preset,
            inferredName: preset == nil ? inferName(from: cleaned) : nil,
            confidence: confidence
        )
    }

    /// Pick a best-guess subscription name from a row's OCR lines when no
    /// preset matched. Heuristic: longest non-price, non-date, non-plan-noise
    /// line. Returns nil if no good candidate exists.
    static func inferName(from lines: [String]) -> String? {
        let candidates = lines.filter { line in
            // Skip lines that are mostly a price.
            if extractPrice(in: line) != nil { return false }
            // Skip Chinese date / expiry markers.
            let l = line
            if l.contains("续期") || l.contains("到期") || l.contains("将于") { return false }
            // Skip very short / numeric-only lines.
            let alphaCount = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            if alphaCount < 2 { return false }
            return true
        }
        // Longest line wins — usually the bold app title on the iOS
        // Subscriptions card.
        return candidates.max(by: { $0.count < $1.count })
    }

    // MARK: - Name match

    /// Returns the highest-scoring preset whose `name` appears (case-insensitive)
    /// somewhere in the OCR lines. Ties broken by longest name (more specific
    /// match wins — "Apple Music" beats "Apple").
    static func matchPreset(in lines: [String], presets: [PresetItem]) -> PresetItem? {
        let haystack = lines.joined(separator: " ").lowercased()
        guard !haystack.isEmpty else { return nil }

        var best: (preset: PresetItem, score: Int)?
        for preset in presets {
            let needle = preset.name.lowercased()
            guard !needle.isEmpty, haystack.contains(needle) else { continue }
            let score = needle.count
            if best == nil || score > best!.score {
                best = (preset, score)
            }
        }
        return best?.preset
    }

    // MARK: - Price regex

    /// One extracted (amount, currency) tuple from the OCR'd text. `currency`
    /// is an ISO-4217 code resolved from whatever symbol/code appeared inline.
    struct ExtractedPrice: Equatable {
        let amount: Decimal
        let currency: String
    }

    /// Resolves a currency symbol or 3-letter code into an ISO code.
    /// Returns `nil` for things we don't recognize so the caller can fall back
    /// to preset defaults or user input.
    private static func currencyCode(for token: String) -> String? {
        switch token {
        case "$":          return "USD"
        case "US$":        return "USD"
        case "USD":        return "USD"
        case "¥":          return "CNY"   // simplification: ¥ defaults to CNY in our user base
        case "RMB":        return "CNY"
        case "CN¥":        return "CNY"
        case "CNY":        return "CNY"
        case "JPY":        return "JPY"
        case "£":          return "GBP"
        case "GBP":        return "GBP"
        case "€":          return "EUR"
        case "EUR":        return "EUR"
        case "HK$":        return "HKD"
        case "HKD":        return "HKD"
        case "₩":          return "KRW"
        case "KRW":        return "KRW"
        case "C$":         return "CAD"
        case "CAD":        return "CAD"
        case "A$":         return "AUD"
        case "AUD":        return "AUD"
        default:
            // Fall back to a 3-letter all-caps code if it looks plausible.
            if token.count == 3, token.allSatisfy({ $0.isLetter && $0.isUppercase }) {
                return token
            }
            return nil
        }
    }

    /// Pulls the first plausible (amount, currency) pair out of the text. We
    /// scan left-to-right and accept either `<symbol><amount>` (e.g. `$15.49`)
    /// or `<amount> <code>` (e.g. `20.00 USD`).
    static func extractPrice(in text: String) -> ExtractedPrice? {
        // Pattern 1: <symbol_or_code><optional space><amount>
        //   $15.49 | US$15.49 | USD 20.00 | ¥144 | £10.99 | C$9.99
        let leadingPattern = #"(US\$|HK\$|CN¥|C\$|A\$|\$|¥|£|€|₩|USD|CNY|RMB|EUR|GBP|JPY|HKD|KRW|CAD|AUD)\s*([0-9]+(?:[.,][0-9]{1,2})?)"#
        // Pattern 2: <amount><space?><code_only>
        //   20.00 USD | 100 EUR
        let trailingPattern = #"([0-9]+(?:[.,][0-9]{1,2})?)\s*(USD|CNY|RMB|EUR|GBP|JPY|HKD|KRW|CAD|AUD)\b"#

        if let hit = firstMatch(pattern: leadingPattern, in: text),
           hit.captures.count >= 2,
           let amount = parseDecimal(hit.captures[1]),
           let ccy = currencyCode(for: hit.captures[0]) {
            return ExtractedPrice(amount: amount, currency: ccy)
        }
        if let hit = firstMatch(pattern: trailingPattern, in: text),
           hit.captures.count >= 2,
           let amount = parseDecimal(hit.captures[0]),
           let ccy = currencyCode(for: hit.captures[1]) {
            return ExtractedPrice(amount: amount, currency: ccy)
        }
        return nil
    }

    // MARK: - Cycle regex

    /// Detects a billing cycle hint anywhere in the text. Order matters —
    /// "yearly" must be checked before "year" / "ar" wouldn't, but checking
    /// "yearly" first lets "per year" still hit via the "year" branch.
    static func extractCycle(in text: String) -> BillingCycle? {
        let lower = text.lowercased()
        // Chinese hints (token-level, no spaces).
        if lower.contains("每年") || lower.contains("年付") || lower.contains("/年") {
            return .yearly
        }
        if lower.contains("每月") || lower.contains("月付") || lower.contains("/月") {
            return .monthly
        }
        if lower.contains("每周") || lower.contains("/周") {
            return .weekly
        }
        // English — regex handles optional whitespace around the slash.
        if matchesAny([#"\bannual\b"#, #"\byearly\b"#, #"/\s*(year|yr)\b"#,
                       #"per\s+year"#, #"a\s+year\b"#], in: lower) {
            return .yearly
        }
        if matchesAny([#"\bmonthly\b"#, #"/\s*(month|mo)\b"#,
                       #"per\s+month"#, #"a\s+month\b"#], in: lower) {
            return .monthly
        }
        if matchesAny([#"\bweekly\b"#, #"/\s*(week|wk)\b"#,
                       #"per\s+week"#, #"a\s+week\b"#], in: lower) {
            return .weekly
        }
        return nil
    }

    // MARK: - Helpers

    private static func matchesAny(_ patterns: [String], in text: String) -> Bool {
        for p in patterns where firstMatch(pattern: p, in: text) != nil {
            return true
        }
        return false
    }

    private static func parseDecimal(_ s: String) -> Decimal? {
        // OCR + i18n sometimes give us `15,49` instead of `15.49`.
        let normalized = s.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private struct RegexHit {
        let range: Range<String.Index>
        let captures: [String]
    }

    private static func firstMatch(pattern: String, in text: String) -> RegexHit? {
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: [.caseInsensitive]) else {
            return nil
        }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text,
                                            range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        var captures: [String] = []
        // Skip group 0 (full match); collect groups 1...
        for i in 1..<match.numberOfRanges {
            let r = match.range(at: i)
            captures.append(r.location == NSNotFound ? "" : ns.substring(with: r))
        }
        let fullRange = match.range
        guard let swiftRange = Range(fullRange, in: text) else { return nil }
        return RegexHit(range: swiftRange, captures: captures)
    }
}
