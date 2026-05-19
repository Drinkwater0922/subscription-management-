import Foundation

/// Single source of truth for every deployment-time identifier the running app
/// reads. Files outside Swift (`project.yml`, `Trackr.entitlements`,
/// `Widgets.entitlements`, `Configuration.storekit`) carry their own copies —
/// the human runbook (`docs/release/PRE-LAUNCH.md`) lists every site.
///
/// M9 keeps values at their placeholder names; a future production swap edits
/// the constants here AND the file-level duplicates listed in PRE-LAUNCH.md.
enum BrandConfig {

    /// Display name shown on the home-screen icon and in onboarding.
    static let appDisplayName = "PennyLoop"

    /// Reverse-DNS bundle identifier. Must match `PRODUCT_BUNDLE_IDENTIFIER`
    /// in `project.yml`.
    static let bundleIdentifier = "com.jingxue.pennyloop"

    /// App Group container shared between the app and the widget extension.
    /// Must match the `com.apple.security.application-groups` array in both
    /// `Trackr.entitlements` and `Widgets.entitlements`.
    static let appGroupIdentifier = "group.com.jingxue.pennyloop"

    /// CloudKit container identifier. Must match the
    /// `com.apple.developer.icloud-container-identifiers` array in
    /// `Trackr.entitlements`.
    static let cloudKitContainerIdentifier = "iCloud.com.jingxue.pennyloop"

    /// Public privacy policy URL — surfaced in Settings. Hosted on GitHub
    /// Pages out of the `docs/` folder of the project repo. Source lives at
    /// `docs/legal/privacy.md`; swap to a vanity domain later by updating
    /// this constant only.
    static let privacyPolicyURL = URL(string: "https://drinkwater0922.github.io/subscription-management-/legal/privacy/")!

    /// Public terms of service URL — surfaced in Settings. Hosted on GitHub
    /// Pages alongside the privacy policy.
    static let termsOfServiceURL = URL(string: "https://drinkwater0922.github.io/subscription-management-/legal/terms/")!

    /// Apple-hosted subscription management page — deep-links into the user's
    /// Apple ID subscriptions on iOS.
    static let manageSubscriptionURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    /// Public support page — hosted on GitHub Pages alongside the legal docs.
    /// Currently a static page that points users at email / App Store rating /
    /// GitHub issue. The v1.0.1 Settings UI surfaces those three channels
    /// directly, so this constant exists mainly for external linking.
    static let supportURL = URL(string: "https://drinkwater0922.github.io/subscription-management-/support/")!

    /// Direct link to the GitHub issue creation form — the technical-fallback
    /// feedback channel. Avoids dragging Chinese users without a GitHub
    /// account through the support page just to file a bug.
    static let supportIssueURL = URL(string: "https://github.com/Drinkwater0922/subscription-management-/issues/new")!

    /// Inbox monitored by the maintainer for `EMAIL FEEDBACK` mailto: links
    /// surfaced in Settings. Must be a real, monitored mailbox — the
    /// BrandConfig test suite refuses to ship a `TODO_`-prefixed placeholder.
    static let supportEmail = "pennyloop0708@gmail.com"

    /// Remote preset catalog endpoint. Production swaps the host once the CDN
    /// is provisioned; until then `presets.invalid` makes every fetch fail and
    /// the bundled seed drives the LIBRARY tab.
    static let presetCatalogURL = URL(string: "https://presets.invalid/trackr/v1/presets.json")!
}
