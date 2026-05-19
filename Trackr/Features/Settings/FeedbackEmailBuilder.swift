import Foundation

/// Pure builder that produces the `mailto:` URL surfaced by the `EMAIL
/// FEEDBACK` row in Settings.
///
/// Kept as a plain struct (no `UIDevice`/`Bundle` calls inside) so the unit
/// tests can pin down exactly which diagnostic fields land in the email body
/// and prove that none of the forbidden fields (subscription content, OCR
/// text, device model, storefront, timezone) leak in.
struct FeedbackEmailBuilder: Equatable {

    /// `CFBundleShortVersionString` — e.g. `1.0.1`.
    let appVersion: String
    /// `CFBundleVersion` — e.g. `14`.
    let buildNumber: String
    /// `UIDevice.current.systemVersion` — e.g. `18.1`.
    let iOSVersion: String
    /// App's resolved language tag — e.g. `en`, `zh-Hans`.
    let language: String
    /// Current entitlement — rendered as the raw enum value (`free` /
    /// `proLifetime`).
    let proStatus: ProStatus

    /// Default subject line. Public so tests can pin its shape directly.
    var subject: String {
        "PennyLoop Feedback - \(appVersion) (\(buildNumber))"
    }

    /// Body with diagnostic footer. Only the fields enumerated in the PRD's
    /// allow-list appear here; in particular this MUST stay free of any
    /// per-subscription data, OCR text, device model, storefront, or
    /// timezone.
    var body: String {
        """
        Please describe what happened:


        ---
        App: PennyLoop
        Version: \(appVersion)
        Build: \(buildNumber)
        iOS: \(iOSVersion)
        Language: \(language)
        Pro Status: \(proStatus.rawValue)
        """
    }

    /// Renders the final `mailto:` URL. Returns `nil` only when
    /// `URLComponents` refuses to assemble a syntactically-valid URL, which
    /// shouldn't happen for any realistic input — we still surface the
    /// optional so the caller can guard cleanly.
    func mailtoURL(to address: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        // `mailto:` puts the recipient in the path component, not in `host`.
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
