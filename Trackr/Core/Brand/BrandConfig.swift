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
    static let appDisplayName = "Trackr"

    /// Reverse-DNS bundle identifier. Must match `PRODUCT_BUNDLE_IDENTIFIER`
    /// in `project.yml`.
    static let bundleIdentifier = "com.placeholder.trackr"

    /// App Group container shared between the app and the widget extension.
    /// Must match the `com.apple.security.application-groups` array in both
    /// `Trackr.entitlements` and `Widgets.entitlements`.
    static let appGroupIdentifier = "group.com.placeholder.trackr"

    /// CloudKit container identifier. Must match the
    /// `com.apple.developer.icloud-container-identifiers` array in
    /// `Trackr.entitlements`.
    static let cloudKitContainerIdentifier = "iCloud.com.placeholder.trackr"

    /// Public privacy policy URL — surfaced in Settings.
    static let privacyPolicyURL = URL(string: "https://trackr.placeholder/privacy")!

    /// Public terms of service URL — surfaced in Settings.
    static let termsOfServiceURL = URL(string: "https://trackr.placeholder/terms")!

    /// Apple-hosted subscription management page — deep-links into the user's
    /// Apple ID subscriptions on iOS.
    static let manageSubscriptionURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    /// Remote preset catalog endpoint. Production swaps the host once the CDN
    /// is provisioned; until then `presets.invalid` makes every fetch fail and
    /// the bundled seed drives the LIBRARY tab.
    static let presetCatalogURL = URL(string: "https://presets.invalid/trackr/v1/presets.json")!
}
