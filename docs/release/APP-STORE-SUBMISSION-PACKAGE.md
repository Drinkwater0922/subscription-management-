# PennyLoop — App Store Submission Package

Last checked: 2026-05-19.

This file is the operational source for copying metadata into App Store Connect. Use `app-store-listing-en.md` for English fields and `app-store-listing-zh-Hans.md` for Simplified Chinese fields.

## Required App Information

| App Store Connect Field | Value |
|---|---|
| App Name | PennyLoop |
| Bundle ID | `com.jingxue.pennyloop` |
| SKU | `pennyloop-ios-001` |
| Apple Developer Team ID | `Y5NK4T6CXG` |
| Version | `1.0.0` |
| Build | `13` |
| Primary Language | English (U.S.) |
| Primary Category | Finance |
| Secondary Category | Productivity |
| Age Rating | 4+ |
| Made for Kids | No |
| Copyright | `2026 Jingxue` for an individual developer account, or `2026 <legal company name>` if submitting under a company account. Do not include `©`; Apple adds it automatically. |
| License Agreement | Apple standard EULA |
| Export Compliance | Uses only exempt Apple/URLSession HTTPS encryption; `ITSAppUsesNonExemptEncryption=false` is already set. |
| Content Rights | No third-party content requiring separate rights. User-entered names and service icons are used only for identification. |
| Routing App Coverage File | Leave blank. PennyLoop is not a Maps routing/navigation app and the binary does not declare routing support. |

## Required URLs

| Field | URL | Status |
|---|---|---|
| Privacy Policy URL | https://drinkwater0922.github.io/subscription-management-/legal/privacy/ | Verified HTTP 200 on 2026-05-19 |
| Terms URL | https://drinkwater0922.github.io/subscription-management-/legal/terms/ | Verified HTTP 200 on 2026-05-19 |
| Support URL | https://drinkwater0922.github.io/subscription-management-/support/ | Dedicated support page; publish `docs/support.md` to GitHub Pages before submission |
| Marketing URL | https://drinkwater0922.github.io/subscription-management-/ | Usable for launch |

## Required Localized Metadata

| Locale | Source File |
|---|---|
| English (U.S.) | `docs/release/app-store-listing-en.md` |
| Chinese Simplified | `docs/release/app-store-listing-zh-Hans.md` |

Each locale includes:

- Name
- Subtitle
- Promotional text
- Description
- Keywords
- Support URL
- Marketing URL
- What's New
- App Privacy notes
- Review notes

## Screenshots and App Previews

App preview videos are optional for v1. Submit screenshots only.

Current screenshot set:

| Slot | File | Size |
|---|---|---|
| Home populated | `TrackrTests/__Snapshots__/StoreScreenshots_Tests/test_store_home_populated.1.png` | 1284 x 2778 |
| Detail / renewal | `TrackrTests/__Snapshots__/StoreScreenshots_Tests/test_store_detail.1.png` | 1284 x 2778 |
| Insights | `TrackrTests/__Snapshots__/StoreScreenshots_Tests/test_store_insights.1.png` | 1284 x 2778 |
| Paywall | `TrackrTests/__Snapshots__/StoreScreenshots_Tests/test_store_paywall.1.png` | 1284 x 2778 |
| Settings | `TrackrTests/__Snapshots__/StoreScreenshots_Tests/test_store_settings.1.png` | 1284 x 2778 |

These are valid for Apple's iPhone 6.5-inch display class. Apple's current screenshot table also lists a newer 6.9-inch class; App Store Connect accepts a 6.5-inch set when 6.9-inch screenshots are not provided.

Recommended upload order:

1. `test_store_home_populated.1.png`
2. `test_store_detail.1.png`
3. `test_store_insights.1.png`
4. `test_store_paywall.1.png`
5. `test_store_settings.1.png`

## In-App Purchase

| Field | Value |
|---|---|
| Type | Non-consumable |
| Reference Name | `PennyLoop Pro Lifetime` |
| Product ID | `com.jingxue.pennyloop.pro.lifetime` |
| Display Name | PennyLoop Pro |
| Price | Tier 8 / $7.99 USD / approx. CNY 58 |
| Family Sharing | Enabled |
| Review Screenshot | `docs/release/iap-paywall-screenshot.png` |

Review notes and localized IAP descriptions are in `docs/release/IAP-SETUP.md`.

## App Privacy

Fill App Privacy conservatively:

- Tracking: No
- Third-party advertising: No
- Analytics SDK: No
- Crash reporting SDK: No
- Data linked to the user: Purchases, only for StoreKit entitlement verification
- Developer-collected user content: No
- User subscription data: Stored locally, or in the user's private iCloud account when Pro sync is enabled
- Screenshot import: On-device Apple Vision OCR; images are not uploaded
- Network calls: Apple StoreKit, Apple CloudKit, FX-rate lookup, optional static preset catalog

## App Review Notes

Paste the localized review note from the listing file and add the sandbox tester credentials manually in App Store Connect. Do not commit the sandbox tester password to this repository.

Minimum review path:

1. Add five subscriptions.
2. Try to add a sixth subscription.
3. Paywall appears.
4. Buy PennyLoop Pro with sandbox account.
5. Sixth subscription saves.
6. Settings shows `PRO LIFETIME`.
7. Restore purchases is available from the paywall and settings.

## Final Pre-Submit Checks

- Privacy and Terms URLs return HTTP 200.
- Support URL contains a real way to contact support.
- IAP product is `Ready to Submit` and attached to the version.
- Sandbox tester can complete the lifetime purchase in TestFlight.
- Screenshots upload successfully for the iPhone screenshot slot.
- `CURRENT_PROJECT_VERSION` is higher than the latest uploaded build.
- No visible app copy implies a recurring subscription; Pro is a one-time lifetime purchase.
- App Review notes include the purchase test path and sandbox account.
