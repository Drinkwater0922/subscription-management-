# Subscription Tracker iOS App — Design Spec

- **Date:** 2026-05-14
- **Status:** Draft, pending user review
- **Working name:** TRACKR _(placeholder; final name TBD after trademark/App Store/domain check)_

---

## 1. Overview

An iOS app that helps users track recurring subscriptions (especially AI / developer tools) and warns them before each charge. Differentiated against existing subscription trackers (Bobby, Subby, Notch, Orbit) by being purpose-built for the AI / developer niche: a curated preset library of AI tools and proactive alerts when those tools change their prices.

**Positioning:** "The AI subscription tracker for developers." Looks and feels like a hardware control panel (dot-matrix typography, monochrome with one accent color) — visually distinct from every existing competitor in the category.

**Distribution:** App Store launch (commercial product).

---

## 2. Target user & differentiation

**Primary user:** Developers, indie hackers, AI power users who pay for 3+ AI tools at once (e.g. an AI chat plan, a code editor plan, a design generator, an API platform). They have high subscription density, dislike subscription fatigue, and are sensitive to the "subscription manager app is itself a subscription" anti-pattern.

**Differentiation vs existing trackers:**

1. **AI-first preset library.** 60+ curated AI products at launch with logos, plan tiers, and prices already populated. Add a subscription in 3 taps total (FAB → tap preset → save).
2. **AI price-change alerts.** When a tracked AI tool raises (or drops) its price, the user gets a push notification. No existing tracker does this today. This is the recurring "wow" that pulls users back to the app and acts as the social-sharing hook.
3. **Renewal reminders** (table stakes for the category — must-have but not differentiating).

**Anti-features (explicitly out of scope to keep focus):**

- Bank-account linking / Plaid integration (Rocket Money's territory — different product)
- Receipt-scanning OCR (Orbit's "Magic Import" — heavy to build, off-niche for AI tools that arrive via email or in-product upgrade)
- Family expense splitting / shared subs (V2)
- Token-usage / API-spend tracking (V2; AI-API spend is variable, not "subscription")

---

## 3. MVP scope (V1)

**Required for launch:**

- Add subscription (from preset library OR custom manual entry)
- Subscription list view (sorted by next renewal)
- Edit / pause / cancel / delete a subscription
- Local push notification N days before each renewal (default 3 + 1 days, configurable)
- Monthly & yearly spend totals
- iCloud sync via CloudKit
- Multi-currency (at least USD + CNY, with multi-currency aggregation to user's default)
- Onboarding (3 screens) + paywall (post-trigger)
- Free / Pro tier with StoreKit 2 IAP
- Home-screen Widget (Small + Medium)
- URL + notes fields on each subscription
- Localization: zh-Hans + en

**Explicit V1 candidates rejected (defer to V2):**

- Custom lists / categories / groups
- Per-charge price history (just store renewal events; user-edited price history table is V2)
- Detailed monthly trend charts (V1 ships totals only; full Insights view with charts ships in V2)
- Payment-method tags
- Face ID app lock
- CSV / JSON export

---

## 4. Information architecture

**No tab bar.** Single primary screen with modals / sheets for secondary surfaces. Rationale: minimal chrome fits the design aesthetic; user's primary action ("show me what's due") happens on the home screen.

**Screens:**

1. **Home** — hero monthly total (oversized dot-matrix number), subscription list sorted by next renewal date, FAB to add. Right-side icons in top bar open Insights and Settings.
2. **Add Subscription** (sheet) — segmented control: `LIBRARY` (default) / `CUSTOM`. Library is a searchable grid of preset cells grouped by category. Custom is a manual form.
3. **Confirm Form** — same sheet, second step after a preset is selected. Pre-filled plan, amount, currency, cycle; user picks next billing date and confirms.
4. **Subscription Detail** — large countdown, renewal history timeline, optional inline price-change alert, actions (edit / pause / cancel / delete / open URL).
5. **Insights** — accessed from Home top-right. V1 shows monthly + yearly totals only. (V2 adds category breakdown and trend charts; this screen exists as Pro-gated value in V1 but content is minimal.)
6. **Settings** — notification preferences (lead days, hour), default currency, iCloud sync status, language, Pro status / upgrade entry, About / privacy / terms links.
7. **Paywall** (modal sheet) — triggered, not shown unsolicited. Two CTAs: monthly subscription and lifetime one-time purchase.
8. **Onboarding** (full-screen cover, first launch only) — 3 screens: brand splash → value pitch → notification permission request. Lands on empty Home.

---

## 5. Visual system

**Aesthetic school:** Hardware control panel / LCD-display feel. Dot-matrix typography for all numeric and heading text; clean sans-serif for body. High contrast monochrome with a single accent color used sparingly.

**Color tokens:**

| Token | Hex | Use |
|---|---|---|
| `bg` | `#000000` | App background |
| `bg-2` | `#0E0E10` | Subtle panel background |
| `bg-3` | `#1A1A1D` | Mono-square icon background |
| `border` | `#2A2A2D` | Hairline borders and dashed dividers |
| `fg` | `#F5F5F7` | Primary text |
| `fg-2` | `#8A8A8D` | Secondary text |
| `fg-3` | `#4A4A4D` | Tertiary / disabled |
| `accent` | `#C7F284` | Brand primary; FAB, CTAs, highlights, "due soon" countdowns |
| `warn` | `#A8453D` | True-warning only: overdue subs, price-increase alerts |

**No light mode in V1.** The design depends on a black canvas — adding light mode doubles the design surface and dilutes brand. Reconsider in V2.

**Typography:**

- **Pixel font:** VT323 (Google Fonts, OFL license, free commercial use). Used for digits, dates, all-caps labels, and large headings. Embedded in app bundle.
- **Sans font:** SF Pro (system). Used for body copy, button labels, form input text.
- **Type scale:** Hero number 68pt VT323, section labels 13pt VT323 with 2px letter-spacing, body 13–15pt SF Pro, secondary 11pt SF Pro.

**Components & patterns:**

- **Mono-square icons.** Subscription icons rendered as 36×36 dark squares with a 2-letter monogram in pixel font. Custom tinted backgrounds per category. Real product logos populate from the preset bundle; fallback for custom entries is an emoji picker.
- **Dashed dividers** (1px dashed, `border` color) as primary section separator. Conveys "schematic / blueprint" feel.
- **Cards have hairline borders, no shadows, no rounded corners** (except phone-itself rounding). Reinforces the hardware aesthetic.
- **"Due soon" highlight:** subscriptions ≤3 days from renewal get a 4px left edge in `accent` plus an `accent`-colored countdown label. Subscriptions overdue (rare — should be cancelled) get `warn` instead.

---

## 6. Data model

SwiftData entities. Synced via CloudKit (Pro feature; free users get local-only persistence).

```
Subscription
├─ id: UUID                              // primary key
├─ name: String                          // e.g. "AI Chat Pro"
├─ planName: String?                     // e.g. "Individual" / "Team" / "Pro"
├─ amount: Decimal                       // billed amount per cycle
├─ currency: String                      // ISO 4217, e.g. "USD" / "CNY"
├─ billingCycle: BillingCycle            // .monthly / .yearly / .weekly / .customDays(Int)
├─ nextBillingDate: Date                 // recomputed after each renewal event
├─ startDate: Date                       // anchor for cycle math (prevents date drift)
├─ category: Category                    // .ai / .dev / .media / .cloud / .productivity / .other
├─ paymentMethod: String?                // free-form short string
├─ notes: String?
├─ url: URL?
├─ iconRef: String                       // "preset:<id>" or "custom:emoji:<emoji>"
├─ presetId: String?                     // links to PresetItem.id, enables price-change matching
├─ isActive: Bool                        // false when paused or cancelled
├─ pausedUntil: Date?                    // optional pause window
├─ createdAt: Date
├─ updatedAt: Date

RenewalEvent                              // one record per actual billing occurrence
├─ id: UUID
├─ subscriptionId: UUID                  // FK
├─ date: Date
├─ amount: Decimal                       // captured at time of renewal (handles price drift)
├─ currency: String
├─ status: RenewalStatus                 // .scheduled / .paid / .skipped

PriceChangeAlert                          // generated by preset-sync diff
├─ id: UUID
├─ presetId: String                      // FK to PresetItem.id
├─ planKey: String                       // which plan tier changed
├─ oldAmount: Decimal
├─ newAmount: Decimal
├─ currency: String
├─ effectiveDate: Date
├─ message: LocalizedString              // structured: { "zh-Hans": "...", "en": "..." }
├─ seenAt: Date?                         // nil until user dismisses
├─ createdAt: Date

PresetCache                              // singleton; mirror of remote presets.json
├─ version: String                       // e.g. "2026.05.14"
├─ fetchedAt: Date
├─ data: Data                            // serialised PresetItem array

UserSettings                             // singleton
├─ defaultCurrency: String
├─ leadDays: [Int]                       // default [3, 1]
├─ notifyHour: Int                       // 0..23, default 9
├─ language: String                      // "zh-Hans" | "en" | "auto"
├─ biometricLockEnabled: Bool            // V2 feature, field reserved
├─ proStatus: ProStatus                  // .free / .proMonthly / .proLifetime
├─ proExpiresAt: Date?
├─ onboardingCompletedAt: Date?
```

**CloudKit notes:** Pro users get `.private` database sync. Free users skip CloudKit entirely. Switching free → Pro triggers an initial upload of all local Subscriptions; downgrading or refund leaves local data intact, just stops syncing.

---

## 7. Core flows

### 7.1 Onboarding (first launch only)

`AppLaunch → check UserSettings.onboardingCompletedAt == nil → fullScreenCover(Onboarding)`

1. Brand splash — logo + tagline, 1-tap continue
2. Value pitch — "100+ AI tools preset, price-change alerts"
3. Notification permission — calls `UNUserNotificationCenter.requestAuthorization`; deny is recoverable from Settings later
4. Write `UserSettings` record (proStatus: .free, defaultCurrency from `Locale.current`, leadDays: [3,1], notifyHour: 9) → dismiss → land on empty Home

### 7.2 Add subscription (from library) — the differentiating flow

`Home FAB → AddSheet → LIBRARY tab (default) → grid of preset cells`

1. Tap FAB → present sheet
2. Browse / search the preset library (grouped by category)
3. Tap a preset cell → green border indicates selection → auto-advance to confirm step
4. Confirm form: plan, amount, cycle, currency all pre-filled from the preset; user only picks `nextBillingDate` and confirms
5. Save → insert `Subscription` → schedule local notifications for each `leadDay` → CloudKit sync queued automatically (Pro) → modal dismisses → Home re-renders with new row pulsing briefly in `accent`

**Total taps from FAB to saved sub: 3** (FAB → preset cell → save).

### 7.3 Add subscription (custom)

`AddSheet → CUSTOM tab → manual form`

1. User enters name, amount, cycle, etc. manually; picks emoji as icon
2. Save behaves identically to the library flow, except `presetId` is `nil` (so this subscription never matches price-change alerts — by design)

### 7.4 Renewal reminder

No server. Notifications are scheduled at save / edit time and delivered by iOS.

1. On `Subscription.save`: for each `leadDay` in `UserSettings.leadDays`, schedule a `UNNotificationRequest` with trigger date = `nextBillingDate - leadDays` at `notifyHour`. Identifier = `"\(sub.id)-\(leadDay)"` so we can cancel/replace on edit.
2. iOS delivers the notification at the scheduled time
3. User taps → app routes via `UNNotificationResponse.userInfo["subId"]` to `SubscriptionDetailView`. If cold-start, the deep link is resolved after SwiftData boots.

**Same-day aggregation:** if multiple subs renew the same day, the scheduler bundles them into one notification ("Today: 3 subscriptions renewing — $52 total") instead of N separate pings. Implementation: dedupe by trigger date at scheduling time.

### 7.5 Price-change alert (the differentiating push)

1. App enters foreground; if `PresetCache.fetchedAt > 24h ago`, fetch `presets.json` from remote URL
2. Compare remote `version` with local cache version; if newer, replace cache and diff `items[].plans[].amount` between old and new
3. For each price change, find any user `Subscription` where `presetId` matches → generate a `PriceChangeAlert` record
4. **Pro users:** schedule an immediate `UNNotificationRequest` for each alert
5. **Free users:** alert is stored but not pushed; surfaces only as in-app banner on the relevant `SubscriptionDetailView` (this asymmetry is part of the Pro value pitch)
6. User can dismiss the alert (writes `seenAt`), tap to open the product URL, or open the related subscription detail

### 7.6 Free → Pro upgrade

**Paywall triggers (any of):**

- User attempts to add a 6th subscription
- User taps Insights from Home (Free users see paywall preview before entering)
- User configures a Widget (intercept in WidgetConfigurationIntent)
- User taps "Upgrade" in Settings

**Flow:**

1. Trigger event → `PaywallTriggerCoordinator` presents `PaywallView` as modal sheet
2. View loads `Product.products(for: ["trackr.pro.monthly", "trackr.pro.lifetime"])` via StoreKit 2
3. User picks a product → `product.purchase()` → on success, `Transaction.currentEntitlements` async stream observed; `UserSettings.proStatus` flipped → all gated views re-render via `@Observable`
4. Originally-blocked action completes automatically (e.g. the 6th subscription save proceeds)

---

## 8. Free vs Pro

| Feature | Free | Pro |
|---|---|---|
| Subscriptions tracked | ≤ 5 | Unlimited |
| Manual add / custom icon | ✓ | ✓ |
| AI preset library browsing | ✓ | ✓ |
| Renewal reminders (local notification) | ✓ | ✓ |
| Home — monthly total in default currency | ✓ | ✓ |
| Home — yearly total + "next 7 days" stat | — | ✓ |
| Insights screen (V1: monthly + yearly totals only; charts ship in V2) | — | ✓ |
| Price-change in-app banner on detail screen | ✓ | ✓ |
| **Price-change local notification** | — | **✓** |
| Home-screen Widget (Small + Medium) | — | ✓ |
| iCloud sync (CloudKit) | — | ✓ |
| Multi-currency: aggregate into default currency | Free user sees each currency as a separate total row | Single converted total |
| Export (CSV / JSON) — _V2_ | — | ✓ |

**StoreKit 2 products:** _(IDs use the placeholder `trackr` prefix; rename after final app name is chosen — the bundle identifier and product IDs typically share the same root)_

- `trackr.pro.monthly` — auto-renewing subscription, monthly, base price `$1.99`
- `trackr.pro.lifetime` — non-consumable, one-time, base price `$14.99`
- Both products have Family Sharing enabled by default
- No free trial in V1 (the 5-sub free tier acts as the trial)

**Launch pricing:**

- First 7 days post-launch: lifetime price set to `$9.99` ("Early Bird") via App Store Connect introductory offer or temp price change
- Day 8 onward: standard `$14.99`
- No "limited time 50% off" sales after launch — preserve price integrity

**Compliance checklist (must-have for App Store submission):**

- Privacy policy URL (template-based, no PII collected, no third-party tracking)
- Terms of service URL
- Subscription auto-renewal disclosure below paywall CTAs (StoreKit requires this verbatim)
- App Tracking Transparency: we do not track → no ATT prompt → this is also an ASO talking point
- iOS 17 Privacy Manifest declaring API categories used (no network tracking, no fingerprinting)

---

## 9. Technical architecture

**Stack:** SwiftUI · SwiftData · CloudKit · StoreKit 2 · WidgetKit · UserNotifications · Charts (system). No third-party dependencies — minimises review risk, easier to debug, no version-lock liabilities.

**Minimum iOS:** 17.0. Trade ~5% device coverage for SwiftData, modern Widget APIs, and `@Observable`. The target audience skews to newer devices anyway.

**Platform scope:** iPhone primary. iPad gets free responsive layout from SwiftUI — we do not specifically design split-view. Mac Catalyst is out of scope for V1.

**Module / folder structure:**

```
TrackrApp (main target)
├─ Features/
│  ├─ Onboarding/          OnboardingView, OnboardingViewModel
│  ├─ Home/                HomeView, HomeViewModel, SubRowView
│  ├─ AddSubscription/     AddSubView, PresetPickerView, ConfirmFormView
│  ├─ Detail/              SubDetailView, RenewalHistoryView, PriceAlertBanner
│  ├─ Insights/            InsightsView, ChartViews (V2-heavy; V1 placeholder)
│  ├─ Settings/            SettingsView, NotificationPrefsView, AboutView
│  └─ Paywall/             PaywallView, PaywallTriggerCoordinator
├─ Core/
│  ├─ Models/              Subscription, RenewalEvent, PriceChangeAlert, UserSettings, PresetItem
│  ├─ Storage/             ModelContainer config, CloudKit container wiring
│  ├─ Repositories/        SubscriptionRepository, PresetRepository, AlertRepository
│  ├─ Notifications/       LocalNotificationScheduler (wraps UNUserNotificationCenter)
│  ├─ PresetSync/          PresetFetcher (URLSession + diff), PriceChangeDiffer
│  ├─ Money/               CurrencyConverter, AmountFormatter
│  └─ Pro/                 ProEntitlement (StoreKit 2 wrapper), FeatureGate
├─ DesignSystem/
│  ├─ Colors.swift         (named tokens)
│  ├─ Typography.swift     (pixelFont, sansFont, scale)
│  ├─ Components/          TrackrButton, MonoSquareIcon, PixelText, DashedDivider
│  └─ Resources/           VT323-Regular.ttf
├─ Widgets/                Widget extension target (separate)
└─ Resources/
   ├─ presets.bundled.json (seed file, ~60 items at launch)
   ├─ Localizable.strings  (zh-Hans, en)
   └─ Assets.xcassets      (app icon, preset logos)
```

**Module boundaries (the units that should be independently understandable and testable):**

- `Repositories/*` — sole gateway between Features and Storage. Features never touch SwiftData directly. This makes feature views unit-testable with in-memory repos.
- `LocalNotificationScheduler` — single responsibility: given a Subscription, schedule / cancel its notifications. Hides `UNUserNotificationCenter` boilerplate.
- `PresetSync/*` — pure logic: fetch, parse, diff, emit `PriceChangeAlert`s. Has no UI dependency; tested with fixture JSON files.
- `ProEntitlement` — exposes `@Observable` `currentStatus`. `FeatureGate` is a simple struct that maps a feature key to whether `currentStatus` permits it. Paywall trigger logic lives in coordinator, not in feature views.

---

## 10. presets.json schema

```json
{
  "version": "2026.05.14",
  "updatedAt": "2026-05-14T08:00:00Z",
  "items": [
    {
      "id": "vendor.product",
      "name": "Product Name",
      "category": "ai-chat | ai-code | ai-image | ai-video | ai-search | api-platform | dev-tools | cloud | other",
      "tags": ["ai", "chat"],
      "iconAsset": "vendor.product",
      "homepageURL": "https://example.com",
      "plans": [
        {
          "key": "plus",
          "label": "Plus",
          "amount": 20.0,
          "currency": "USD",
          "cycle": "monthly",
          "perSeat": false
        }
      ],
      "lastPriceChange": {
        "planKey": "plus",
        "oldAmount": 18.0,
        "newAmount": 20.0,
        "effectiveDate": "2026-04-01",
        "messageZh": "...",
        "messageEn": "..."
      }
    }
  ]
}
```

**Hosting:**

- URL: `https://<our-domain>/presets/v1/presets.json` (version path locks the schema; breaking changes ship as `/v2/`)
- Host: GitHub Pages + Cloudflare (or Cloudflare R2 directly). Both free at our scale.
- The path-versioning contract is permanent: old app builds always get a working `v1` even after we ship `v2`.

**Maintenance workflow (separate repo):**

- `trackr-presets` GitHub repo, private
- Source of truth: `data/items/<id>.yaml` (human-friendly editing)
- CI compiles YAML → `presets.json` → publishes to Pages
- Updating a price: edit the YAML's `plans[].amount`, append a `lastPriceChange` block with effective date and message → commit → CI publishes
- Cadence: scheduled weekly check; community-reported price changes accepted via issue template

**Cache invalidation in-app:**

- App fetches at most once per 24h on foreground
- Compare top-level `version`; identical → skip diff
- Fetch failure → silent retry next foreground; never block user

---

## 11. Notifications strategy

**All notifications are local.** No remote push, no APNs entitlement needed in V1.

**Renewal reminders:**

- Scheduled at `Subscription.save` and re-scheduled on edit
- One `UNNotificationRequest` per `leadDay` in `UserSettings.leadDays` (default [3, 1])
- Trigger time: `nextBillingDate - leadDays` at `notifyHour` (user's local timezone)
- Identifier convention: `"\(sub.id)-\(leadDay)"` enables clean cancel/replace
- Same-day aggregation: subs with the same trigger date bundle into one notification

**Price-change alerts:**

- Generated by `PresetSync` diff on app foreground (max once per 24h)
- Pro users get an immediate `UNNotificationRequest` per match
- Free users do not; alert surfaces only as in-app banner

**Cycle math (critical for correctness):**

- Monthly cycle: next date = `startDate + N months` where N is the count of cycles since start. Avoid the naive "add 1 month to last date" approach which drifts (e.g. 31 Jan → 28 Feb → permanently 28 thereafter).
- Yearly: same pattern, anchored to `startDate`.
- Custom days: simple `startDate + N × days`.

---

## 12. Risks & open questions

**Risks:**

- **Preset library maintenance cost.** A weekly 30-min curation cadence is feasible solo but becomes a bottleneck if the library grows past ~200 items. Mitigation: accept community-submitted price updates via issue template; future automation to scrape known product pages (compliance permitting).
- **iOS 17 minimum cuts ~5% of installable devices.** Acceptable for the target audience; revisit if launch metrics suggest otherwise.
- **No light mode** may polarise. Reviewers occasionally one-star for "no light mode." Acceptable cost; revisit in V2.
- **Pro-only price-change push** could feel mean. Tested mitigations: in-app banner is always available; the push is framed as "real-time" not "exclusive" in App Store copy.

**Open questions (resolve during implementation, not blocking spec approval):**

1. **App name.** TRACKR is a placeholder. Final name needs USPTO Class 9 + Class 42 trademark check, App Store name search, and `.app` or `.com` domain availability before commit.
2. **App icon direction.** Pixel-monogram style consistent with the in-app aesthetic. Specific symbol TBD.
3. **Preset library launch curation.** Exact list of ~60 AI products to ship at launch; curate during implementation phase.
4. **Privacy policy and ToS exact text.** Template-based, no PII collected. Use standard indie-iOS template, no lawyer needed for V1.

---

## Out of scope (V2 candidates, captured for tracking)

- Custom lists / groups (work / personal / family separation)
- Detailed Insights: category breakdown, monthly trend charts, "most expensive subscription" rankings
- Per-charge price history (editable, not just renewal events)
- Payment-method tags
- Face ID / biometric app lock
- CSV / JSON export
- Light mode
- Mac Catalyst / iPad-specific split view
- Family sub splitting & expense settling
- Token / usage tracking for variable-cost AI subscriptions
- iPad app
- Watch complication

---

## Approval

Pending user review of this spec. On approval, the next step is to invoke the `writing-plans` skill to produce a phased implementation plan.
