# Milestone 9 — Pre-Launch: Name Lock, Legal, App Store Assets, Beta Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Engineer the swap surface so a human can move "Trackr" from placeholder identifiers to a real-team-prefixed production identity, author the marketing copy + screenshots + release checklist + operational runbook the human needs to ship through App Store Connect, and tag the engineering work as `m9-launch`.

**Architecture:**
- Today the strings `com.placeholder.trackr`, `group.com.placeholder.trackr`, `iCloud.com.placeholder.trackr`, `https://presets.invalid/...`, `https://trackr.placeholder/privacy`, and `https://trackr.placeholder/terms` are scattered across `project.yml`, `Trackr.entitlements`, `Widgets.entitlements`, `Configuration.storekit`, `Trackr/TrackrApp.swift`, and `Trackr/Features/Settings/SettingsView.swift`. M9 introduces `BrandConfig` — a single Swift enum with every deployment-time string the runtime needs. Files outside Swift (`project.yml`, `*.entitlements`, `.storekit`) keep their own copies because their build-time consumers can't read Swift, but a new `docs/release/PRE-LAUNCH.md` lists every site so the human swap is mechanical.
- Marketing copy ships as Markdown in `docs/release/`. English + zh-Hans variants are canonical there; copy-paste into App Store Connect is the last manual step.
- A new `StoreScreenshots_Tests.swift` test class renders the five App Store hero scenes (Home empty, Home populated, Detail, Settings, Paywall) at the iPhone 6.7" frame size (430×932 points). The snapshot library writes those out as 1290×2796 PNGs; the human uploads them to App Store Connect.
- A new `docs/release/RELEASE-CHECKLIST.md` carries the Apple Review Guidelines self-check (privacy nutrition labels, IAP metadata, screenshots, age rating). `docs/release/PRE-LAUNCH.md` is the operational runbook the human follows: trademark / domain search, Apple Developer Program enrollment, App Store Connect record creation, TestFlight upload, beta feedback triage. Neither file contains code that runs — they're human-readable instructions.
- Version is bumped from `0.1.0` to `1.0.0` in `project.yml`; `CURRENT_PROJECT_VERSION` stays at `1` (build number increments per TestFlight upload — the human bumps it).

**Tech Stack:** Swift 5.10+, SwiftUI, XCTest, swift-snapshot-testing. No new third-party deps. The operational sections of M9 (trademark search, ASC web console, TestFlight) involve services external to the codebase; the plan documents them but cannot automate them.

**Out of scope (documented in `PRE-LAUNCH.md`, not coded):**
- Trademark / App Store name availability / domain availability search — done in parallel by a human in business browsers
- Apple Developer Program enrollment ($99/yr) — requires payment + Apple ID verification
- App Store Connect record creation — web console; can't be scripted
- TestFlight build upload — requires real signing identity from ADP
- Beta tester invitations + feedback triage — multi-day human-loop work
- Final pixel app icon art — design work; engineering shipped a placeholder in M8
- Real privacy / terms / catalog host endpoints — legal + ops work; URLs are placeholder until published

---

## File Structure

After M9 the new code looks like this (only new + modified files shown):

```
Trackr/Core/Brand/
└─ BrandConfig.swift                          # NEW — centralized deployment identifiers

Trackr/Features/Settings/SettingsView.swift   # MODIFIED — privacy/terms links via BrandConfig
Trackr/TrackrApp.swift                         # MODIFIED — catalog URL via BrandConfig
project.yml                                    # MODIFIED — version bump to 1.0.0

docs/release/
├─ PRE-LAUNCH.md                              # NEW — operational runbook
├─ RELEASE-CHECKLIST.md                       # NEW — Apple Review self-check
├─ app-store-listing-en.md                    # NEW — English marketing copy
└─ app-store-listing-zh-Hans.md               # NEW — zh-Hans marketing copy

TrackrTests/
├─ BrandConfig_Tests.swift                    # NEW
└─ StoreScreenshots_Tests.swift               # NEW — App Store hero shots
```

---

### Task 1: `BrandConfig` (TDD)

**Files:**
- Create: `Trackr/Core/Brand/BrandConfig.swift`
- Create: `TrackrTests/BrandConfig_Tests.swift`

A single Swift enum exposing every deployment-time string the running app needs. The values stay at their placeholder names today — M9 only introduces the *seam*. The companion `PRE-LAUNCH.md` (Task 9) documents what the human swaps when production identifiers land.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/BrandConfig_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class BrandConfigTests: XCTestCase {

    func test_appDisplayName_isNonEmpty() {
        XCTAssertFalse(BrandConfig.appDisplayName.isEmpty)
    }

    func test_bundleIdentifier_followsReverseDNSShape() {
        let id = BrandConfig.bundleIdentifier
        XCTAssertTrue(id.contains("."), "expected reverse-DNS bundle id, got \(id)")
        XCTAssertGreaterThanOrEqual(id.split(separator: ".").count, 2)
    }

    func test_appGroupIdentifier_startsWithGroupDot() {
        XCTAssertTrue(BrandConfig.appGroupIdentifier.hasPrefix("group."),
                      "app group id must start with 'group.': \(BrandConfig.appGroupIdentifier)")
    }

    func test_cloudKitContainerIdentifier_startsWithICloudDot() {
        XCTAssertTrue(BrandConfig.cloudKitContainerIdentifier.hasPrefix("iCloud."),
                      "CloudKit container id must start with 'iCloud.': \(BrandConfig.cloudKitContainerIdentifier)")
    }

    func test_privacyPolicyURL_isAbsoluteHTTPS() {
        XCTAssertEqual(BrandConfig.privacyPolicyURL.scheme, "https")
        XCTAssertNotNil(BrandConfig.privacyPolicyURL.host)
    }

    func test_termsOfServiceURL_isAbsoluteHTTPS() {
        XCTAssertEqual(BrandConfig.termsOfServiceURL.scheme, "https")
        XCTAssertNotNil(BrandConfig.termsOfServiceURL.host)
    }

    func test_manageSubscriptionURL_pointsAtAppleAccountSettings() {
        XCTAssertEqual(BrandConfig.manageSubscriptionURL.host, "apps.apple.com")
        XCTAssertTrue(BrandConfig.manageSubscriptionURL.path.contains("subscriptions"))
    }

    func test_presetCatalogURL_isAbsoluteHTTPS() {
        XCTAssertEqual(BrandConfig.presetCatalogURL.scheme, "https")
    }
}
```

- [ ] **Step 2: Run, verify build fails**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | tail -10
```

Expected: `cannot find 'BrandConfig' in scope`.

- [ ] **Step 3: Implement `BrandConfig.swift`**

Create `Trackr/Core/Brand/BrandConfig.swift`:
```swift
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
```

- [ ] **Step 4: Run, verify tests pass**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 205 + 8 = 213 tests passing.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Brand/BrandConfig.swift TrackrTests/BrandConfig_Tests.swift
git commit -m "feat(brand): centralize deployment identifiers in BrandConfig"
```

---

### Task 2: Route SettingsView links through `BrandConfig`

**Files:**
- Modify: `Trackr/Features/Settings/SettingsView.swift`

The privacy and terms `Link` destinations and the Manage Subscription link currently hard-code their URLs. Route them through `BrandConfig`.

- [ ] **Step 1: Update `SettingsView.swift`**

Read `Trackr/Features/Settings/SettingsView.swift` to confirm the current shape. Locate the three URL strings:

1. `URL(string: "https://apps.apple.com/account/subscriptions")!` (in `proStatusSection`)
2. `URL(string: "https://trackr.placeholder/privacy")!` (in `linksSection`)
3. `URL(string: "https://trackr.placeholder/terms")!` (in `linksSection`)

Replace each with the corresponding `BrandConfig.*URL`:

```swift
                    Link(destination: BrandConfig.manageSubscriptionURL) {
```
```swift
            Link(destination: BrandConfig.privacyPolicyURL) {
```
```swift
            Link(destination: BrandConfig.termsOfServiceURL) {
```

- [ ] **Step 2: Run full suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 213 tests pass — no behavior change because the URLs match the hard-coded values byte-for-byte. Settings snapshot baselines stay valid.

- [ ] **Step 3: Commit**

```bash
git add Trackr/Features/Settings/SettingsView.swift
git commit -m "refactor(settings): route privacy/terms/manage URLs through BrandConfig"
```

---

### Task 3: Route preset catalog URL through `BrandConfig`

**Files:**
- Modify: `Trackr/TrackrApp.swift`

`TrackrApp.init()` currently constructs `let catalogURL = URL(string: "https://presets.invalid/trackr/v1/presets.json")!`. Replace with `BrandConfig.presetCatalogURL`.

- [ ] **Step 1: Update `TrackrApp.swift`**

Read `Trackr/TrackrApp.swift`. Find the line:
```swift
        let catalogURL = URL(string: "https://presets.invalid/trackr/v1/presets.json")!
```

Replace with:
```swift
        let catalogURL = BrandConfig.presetCatalogURL
```

- [ ] **Step 2: Run full suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 213 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Trackr/TrackrApp.swift
git commit -m "refactor(app): route preset catalog URL through BrandConfig"
```

---

### Task 4: Version bump to 1.0.0

**Files:**
- Modify: `project.yml`

The `MARKETING_VERSION` is currently `0.1.0` (M1's working value). For the release engineering scaffold, bump to `1.0.0`. The `CURRENT_PROJECT_VERSION` stays at `1` — the human increments it per TestFlight upload.

- [ ] **Step 1: Inspect current values**

```bash
grep -nE "MARKETING_VERSION|CURRENT_PROJECT_VERSION" project.yml
```

You should see entries under the project's top-level `settings: base:` or per-target. If the existing setup defines `MARKETING_VERSION: 0.1.0`, swap to `1.0.0`. If the project uses a different mechanism (build settings inheriting from project-level config), apply the same swap there.

- [ ] **Step 2: Edit `project.yml`**

Find the line setting `MARKETING_VERSION` (likely under the project-level `settings: base:` block near the top of the file, or under the `Trackr:` target's `settings: base:`). Change:
```yaml
        MARKETING_VERSION: 0.1.0
```
to:
```yaml
        MARKETING_VERSION: 1.0.0
```

If the field is set as a plist property via `info.properties.CFBundleShortVersionString` instead, update there. Whichever site authors the marketing version, edit it. There should only be one source.

- [ ] **Step 3: Regenerate + verify**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet build 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Both: exit 0; 213 tests pass.

Sanity-check by inspecting the built app's Info.plist:
```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Info.plist"
```

Expected: `1.0.0`.

- [ ] **Step 4: Commit**

```bash
git add project.yml
git commit -m "chore(release): bump MARKETING_VERSION to 1.0.0"
```

---

### Task 5: App Store listing — English

**Files:**
- Create: `docs/release/app-store-listing-en.md`

Canonical English marketing copy: app name, subtitle, description, keywords, promotional text, support URL, marketing URL, "What's New". The human copy-pastes this into App Store Connect.

- [ ] **Step 1: Create `docs/release/app-store-listing-en.md`**

```markdown
# Trackr — App Store Listing (English)

> Canonical English marketing copy. Copy-paste into App Store Connect → App
> Information / App Privacy / Version Release.

## Name

**Trackr** (display name — must also match `BrandConfig.appDisplayName` and
`CFBundleDisplayName`).

## Subtitle (30 chars max)

Track every subscription, never miss a renewal.

## Promotional Text (170 chars max)

See your full monthly subscription bill at a glance. Get notified before every
renewal. Catch price changes the moment they happen.

## Description (4000 chars max)

Trackr keeps every subscription you pay for in one place — Netflix, Spotify,
iCloud+, ChatGPT, your gym, the magazine you forgot you signed up for.

**Why people love Trackr**

• Monthly total at a glance. One number, every currency you pay in, on the
  home screen.
• Reminders before every renewal. Pick how many days ahead — 7, 3, 1 — and
  the time of day. We'll never spam.
• Price-change alerts. When a service quietly raises its price, you see it
  before the charge hits your card.
• Beautiful, pixel-perfect design. The retro typography and FAB take the
  visual noise of a normal subscription tracker and turn it into something
  you actually want to open.
• Built for the long haul. Local-first, syncs through your iCloud (Pro), and
  the price catalog updates from a curated remote source so popular services
  stay accurate.

**Pro features**

• Unlimited subscriptions (free tier: 5)
• Insights dashboard with monthly and yearly totals
• Push notifications on price changes
• iCloud sync across all your devices
• Home-screen widget

Pro is available as a monthly subscription ($2.99/mo) or a one-time
lifetime purchase ($29.99). Cancel anytime. Subscriptions auto-renew unless
turned off in your Apple ID settings at least 24 hours before the period ends.

**Your data is yours**

Subscriptions live on-device in Apple's SwiftData store. Pro users get
end-to-end encrypted sync through their own private iCloud database. We
never see your data, never sell it, never share it.

Privacy policy: https://trackr.placeholder/privacy
Terms of service: https://trackr.placeholder/terms

(Replace placeholder URLs with the real ones before submission — see
`PRE-LAUNCH.md`.)

## Keywords (100 chars max, comma-separated)

subscription,tracker,renewal,reminder,bill,saas,budget,netflix,spotify,icloud,manage,recurring

## Support URL

https://trackr.placeholder/support

## Marketing URL

https://trackr.placeholder

## What's New (Version 1.0.0)

Welcome to Trackr 1.0. Track every subscription, get notified before every
renewal, and see your full monthly bill at a glance. Built for iPhone and
iPad, with a home-screen widget and iCloud sync for Pro users.

## App Privacy — Data Linked to User

The following data is collected and linked to the user:

• Purchases — In-App Purchase history (for entitlement verification only;
  managed entirely by Apple's StoreKit framework)

The following data is collected on-device and NOT linked to the user:

• Subscription names, amounts, billing cycles, and renewal dates — stored
  in Apple's SwiftData/CloudKit container under the user's own Apple ID.
  Never transmitted to any server we operate.

## Age Rating

4+ (no restricted content)

## App Category

Primary: Finance
Secondary: Productivity
```

- [ ] **Step 2: Commit**

```bash
mkdir -p docs/release
git add docs/release/app-store-listing-en.md
git commit -m "docs(release): add English App Store listing copy"
```

---

### Task 6: App Store listing — Simplified Chinese

**Files:**
- Create: `docs/release/app-store-listing-zh-Hans.md`

Equivalent Simplified Chinese listing. Same structure; the copywriter / native speaker polishes from this draft.

- [ ] **Step 1: Create `docs/release/app-store-listing-zh-Hans.md`**

```markdown
# Trackr — App Store 上架文案（简体中文）

> 简体中文上架文案，准备好后从这里复制到 App Store Connect → App 信息 /
> 隐私 / 版本发布。

## 名称

**Trackr**（显示名 — 同时与 `BrandConfig.appDisplayName` 和
`CFBundleDisplayName` 保持一致）。

## 副标题（最多 30 字符）

管好每笔订阅，再无意外扣款。

## 推广文本（最多 170 字符）

一眼看清每月订阅总开销。续费前提前提醒。价格变动第一时间收到。

## 介绍（最多 4000 字符）

Trackr 帮你管好每一笔订阅 —— Netflix、Spotify、iCloud+、ChatGPT、健身房、
那本忘了取消的杂志，统统集中到一个地方。

**为什么大家喜欢 Trackr**

• 每月总开销一目了然。一个数字，按币种汇总，首页直接看到。
• 续费前主动提醒。提前 7 天、3 天还是 1 天？哪个时间点？你定。绝不打扰。
• 价格变动提醒。某项服务悄悄涨价时，扣款前你就会知道。
• 像素风设计。复古字体配大号悬浮按钮，告别杂乱无章的订阅表格，每次打开都想多看两眼。
• 长期主义打造。本地优先存储，Pro 用户通过 iCloud 同步，价格库从精挑细选的远程
  源更新，热门服务始终保持最新。

**Pro 特权**

• 无限订阅条目（免费版上限 5 条）
• 财务洞察面板：月度与年度总览
• 价格变动推送通知
• 全设备 iCloud 同步
• 主屏小组件

Pro 提供月度订阅（¥21/月）或一次性买断（¥208）。可随时取消。订阅会在到期前
24 小时内自动续费，除非在 Apple ID 订阅设置中关闭。

**数据始终在你手里**

订阅数据通过 Apple 的 SwiftData 存储在设备本地。Pro 用户的同步通过 iCloud
端到端加密私有数据库完成。我们看不到你的数据，永远不会出售，永远不会分享。

隐私政策：https://trackr.placeholder/privacy
服务条款：https://trackr.placeholder/terms

（占位 URL 提交前请替换为正式地址 —— 详见 `PRE-LAUNCH.md`。）

## 关键词（最多 100 字符，逗号分隔）

订阅,管理,续费,提醒,账单,记账,预算,saas,netflix,spotify,icloud,自动续费

## 客服 URL

https://trackr.placeholder/support

## 营销 URL

https://trackr.placeholder

## 更新说明（1.0.0 版本）

欢迎使用 Trackr 1.0。管好每一笔订阅，续费前提前提醒，每月总开销一目了然。
适配 iPhone 与 iPad，附带主屏小组件，Pro 用户还可享受 iCloud 同步。

## App 隐私 —— 与用户身份关联的数据

会收集并与用户关联的数据：

• 购买 —— 应用内购买历史（仅用于权益验证，完全由 Apple 的 StoreKit 框架管理）

收集但不与用户关联的数据：

• 订阅名称、金额、计费周期、下次续费日期 —— 通过 Apple 的 SwiftData /
  CloudKit 容器保存在用户的 Apple ID 之下。不会向我方运营的任何服务器传输。

## 年龄分级

4+（无受限内容）

## 应用分类

主分类：财务
副分类：效率
```

- [ ] **Step 2: Commit**

```bash
git add docs/release/app-store-listing-zh-Hans.md
git commit -m "docs(release): add zh-Hans App Store listing copy"
```

---

### Task 7: `StoreScreenshots_Tests` — 5 hero scenes at iPhone 6.7"

**Files:**
- Create: `TrackrTests/StoreScreenshots_Tests.swift`

App Store demands at least one screenshot set sized for the 6.7" iPhone display (430×932 points → 1290×2796 px). We render five canonical scenes via the same snapshot-testing framework we use elsewhere, write them out as PNGs, and document the location in `PRE-LAUNCH.md`. The human uploads them to App Store Connect.

The five scenes:
1. Home — empty state (the hero "manage everything" promise)
2. Home — populated with 3-4 example subscriptions and a non-trivial monthly total
3. Subscription Detail — pause/edit/delete affordances visible
4. Paywall — the upgrade pitch
5. Settings — lead-day chips, hour wheel, language picker

- [ ] **Step 1: Write the test**

Create `TrackrTests/StoreScreenshots_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

/// Renders five App Store hero scenes at iPhone 6.7" frame size (430×932
/// points). The snapshot library writes them to
/// `TrackrTests/__Snapshots__/StoreScreenshots_Tests/` at 3× density
/// (1290×2796 px) — the exact resolution App Store Connect demands for the
/// 6.7" iPhone screenshot set.
///
/// These tests record on first run via `record: .missing`; subsequent runs
/// verify the baselines. When marketing copy / screen layout changes, delete
/// the baselines and re-record.
@MainActor
final class StoreScreenshotsTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    // 6.7" iPhone (e.g., iPhone 16 Pro Max) — 430×932 points.
    private let storeFrameWidth: CGFloat = 430
    private let storeFrameHeight: CGFloat = 932

    private func mount<V: View>(_ view: V) -> some View {
        let client = FakeStoreKitClient()
        client.products = [
            ProProductDisplay(productID: ProProductID.monthly,  priceDisplay: "$2.99"),
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$29.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        return view
            .modelContainer(container)
            .environment(AppDeepLinkRouter())
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .frame(width: storeFrameWidth, height: storeFrameHeight)
            .preferredColorScheme(.dark)
    }

    private func seed(_ rows: [(String, Decimal, BillingCycle, Date)]) throws {
        for (name, amount, cycle, billing) in rows {
            let sub = Subscription(
                name: name,
                amount: amount, currency: "USD",
                billingCycle: cycle,
                nextBillingDate: billing,
                startDate: Date(timeIntervalSince1970: 1_700_000_000),
                category: .media
            )
            container.mainContext.insert(sub)
        }
        try container.mainContext.save()
    }

    func test_store_home_empty() {
        assertSnapshot(of: mount(HomeView()), as: .image)
    }

    func test_store_home_populated() throws {
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        try seed([
            ("Netflix", 15.49, .monthly, base.addingTimeInterval(86_400 * 3)),
            ("Spotify", 10.99, .monthly, base.addingTimeInterval(86_400 * 7)),
            ("iCloud+", 0.99,  .monthly, base.addingTimeInterval(86_400 * 12)),
            ("ChatGPT Plus", 20, .monthly, base.addingTimeInterval(86_400 * 19)),
        ])
        assertSnapshot(of: mount(HomeView()), as: .image)
    }

    func test_store_detail() throws {
        let sub = Subscription(
            name: "Notion", planName: "Personal Pro",
            amount: 8, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .productivity,
            notes: "Switched from the team plan in June."
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()
        assertSnapshot(of: mount(SubscriptionDetailView(subscription: sub)),
                       as: .image)
    }

    func test_store_paywall() async {
        let client = FakeStoreKitClient()
        client.products = [
            ProProductDisplay(productID: ProProductID.monthly,  priceDisplay: "$2.99"),
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$29.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        let view = PaywallView(reason: .subscriptionLimit)
            .modelContainer(container)
            .environment(entitlement)
            .frame(width: storeFrameWidth, height: storeFrameHeight)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    func test_store_settings() throws {
        let settings = try SettingsRepository(context: container.mainContext).currentSettings()
        settings.leadDays = [7, 3, 1]
        settings.notifyHour = 9
        try container.mainContext.save()
        assertSnapshot(of: mount(SettingsView()), as: .image)
    }
}
```

- [ ] **Step 2: Record snapshots twice (record + verify)**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/StoreScreenshotsTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/StoreScreenshotsTests 2>&1 | tail -3
```

Second run: 5 tests pass.

- [ ] **Step 3: Inspect the recorded PNGs**

```bash
ls -lh TrackrTests/__Snapshots__/StoreScreenshots_Tests/
file TrackrTests/__Snapshots__/StoreScreenshots_Tests/*.png
```

Confirm each is `PNG image data, 1290 x 2796`. App Store Connect's 6.7" slot expects this exact resolution.

- [ ] **Step 4: Run the full suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 213 + 5 = 218 tests.

- [ ] **Step 5: Commit**

```bash
git add TrackrTests/StoreScreenshots_Tests.swift \
        TrackrTests/__Snapshots__/StoreScreenshots_Tests
git commit -m "test(release): record 5 App Store hero screenshots at iPhone 6.7\""
```

---

### Task 8: `RELEASE-CHECKLIST.md` — Apple Review self-check

**Files:**
- Create: `docs/release/RELEASE-CHECKLIST.md`

A pre-submission checklist mapping every Apple App Review Guideline that's likely to come up against Trackr's behavior. The human walks this list before clicking Submit.

- [ ] **Step 1: Create `docs/release/RELEASE-CHECKLIST.md`**

```markdown
# Trackr — Release Checklist

> Walk this end-to-end before clicking **Submit for Review**. Every box must
> be checked or have a documented waiver.

## 1. Identity & metadata

- [ ] `BrandConfig.appDisplayName` matches the App Store Connect "Name" field
- [ ] `BrandConfig.bundleIdentifier` matches `PRODUCT_BUNDLE_IDENTIFIER` in
      `project.yml` and the ASC record's bundle ID
- [ ] App Store Connect bundle ID is on the production Apple Developer team
      (not a personal team)
- [ ] `MARKETING_VERSION` (in `project.yml`) is `1.0.0`
- [ ] `CURRENT_PROJECT_VERSION` is greater than every previously-uploaded
      TestFlight build for this version (Apple rejects re-uses)
- [ ] App icon: `Trackr/Assets.xcassets/AppIcon.appiconset/icon-1024.png` is
      the FINAL pixel art (not the M8 engineering placeholder)
- [ ] No `placeholder` substring appears anywhere in build settings, source,
      entitlements, or `Configuration.storekit` (see "Placeholder Swap" below)

## 2. Privacy

- [ ] Privacy Policy URL (`BrandConfig.privacyPolicyURL`) returns 200 and is
      hosted on a stable domain
- [ ] Privacy Policy is available in **English** AND **Simplified Chinese**
- [ ] Terms of Service URL (`BrandConfig.termsOfServiceURL`) returns 200
- [ ] App Privacy nutrition labels in App Store Connect match the
      "App Privacy" section in `app-store-listing-en.md`
- [ ] No third-party SDK collects PII (Trackr has zero third-party SDKs)
- [ ] CloudKit private-database sync is the only network egress the app
      performs; no analytics, no crash reporters, no ad networks

## 3. In-App Purchase

- [ ] `Configuration.storekit` product IDs match production ASC IAP records
      one-for-one
- [ ] Monthly auto-renewing subscription record exists, is "Ready to Submit",
      and has localized display names + descriptions in English + Simplified
      Chinese
- [ ] Lifetime non-consumable record exists, "Ready to Submit", same locales
- [ ] Subscription group name + summary localized in both languages
- [ ] App Review notes describe how to test Pro: paste a sandbox tester
      Apple ID and explain that the StoreKit configuration ships with the
      production product IDs

## 4. Notifications

- [ ] First-launch onboarding asks for notification permission with
      user-visible justification copy
- [ ] No notifications fire before the user creates their first subscription
- [ ] Pro-only push (price-change notification) gates on
      `FeatureGate.pricePushNotifications` — free users see in-app banner
      only

## 5. Widget + iCloud

- [ ] Widget extension target builds and signs with the same team prefix as
      the host app
- [ ] App Group `BrandConfig.appGroupIdentifier` exists in the Developer
      portal and is enabled for both targets
- [ ] CloudKit container `BrandConfig.cloudKitContainerIdentifier` exists in
      the CloudKit dashboard with Default Zone deployed to Production
- [ ] Sync verification: signed in to the same iCloud account on two
      simulator instances, edits propagate within 10 seconds

## 6. Localization

- [ ] `Localizable.xcstrings` source language is `en`
- [ ] All onboarding, settings, paywall, empty-state strings have a `zh-Hans`
      translation (`extractionState: translated`, not `new`)
- [ ] Language switcher in Settings flips the UI without restart
- [ ] App Store Connect listing has both English and Simplified Chinese
      filled in (from `app-store-listing-en.md` and `app-store-listing-zh-Hans.md`)

## 7. Screenshots

- [ ] 6.7" iPhone screenshot set (5 images) generated by
      `StoreScreenshotsTests` and uploaded to ASC
- [ ] (Optional, recommended) 6.5" iPhone screenshot set — record by editing
      `StoreScreenshotsTests` to use `frame(width: 414, height: 896)` and
      re-recording
- [ ] (Optional) iPad screenshot set if shipping the iPad family
- [ ] Each screenshot has both English and Simplified Chinese variants OR
      a single screenshot set is used across both locales (acceptable if
      visible text is minimal)

## 8. App Review Guidelines self-check

- [ ] **2.1 Performance** — App launches without crashes in cold + warm
      states on the lowest-supported device (iPhone 11 / iOS 17)
- [ ] **3.1.1 In-App Purchase** — All Pro-gated features prompt the user to
      purchase via StoreKit, never an external link
- [ ] **3.1.2 Subscriptions** — Auto-renewing terms disclosed in the paywall
      with monthly price + renewal terms + link to manage subscriptions
- [ ] **4.2 Minimum Functionality** — App provides real value without
      requiring a Pro purchase (free tier supports 5 subs, full CRUD,
      reminders, in-app banner for price changes)
- [ ] **5.1.1 Data Collection** — Privacy nutrition labels accurate, privacy
      policy URL works
- [ ] **5.1.2 Data Use & Sharing** — Trackr collects no PII off-device;
      label accordingly

## 9. TestFlight

- [ ] Internal testing group created with at least one tester per spoken
      language (en + zh-Hans speakers)
- [ ] Beta build uploaded; "What to Test" notes filled in
- [ ] At least one round of beta testing completed; critical-priority
      feedback resolved
- [ ] No `assertionFailure` / `fatalError` paths reachable in production
      flow during beta testing

## Placeholder Swap — files to verify before submission

A grep for `placeholder` should produce ZERO hits in these files before
final submission:

- `Trackr/Core/Brand/BrandConfig.swift`
- `project.yml`
- `Trackr.entitlements`
- `Widgets.entitlements`
- `Configuration.storekit`
- `Trackr/Features/Settings/SettingsView.swift` (defensive — should pull
  through BrandConfig already)

Run:
```bash
grep -rn 'placeholder' Trackr.entitlements Widgets.entitlements project.yml \
    Configuration.storekit Trackr/Core/Brand/BrandConfig.swift
```

Expect: no output. (If output appears, fix before submitting.)
```

- [ ] **Step 2: Commit**

```bash
git add docs/release/RELEASE-CHECKLIST.md
git commit -m "docs(release): add Apple Review self-check before submission"
```

---

### Task 9: `PRE-LAUNCH.md` — operational runbook

**Files:**
- Create: `docs/release/PRE-LAUNCH.md`

The human-facing step-by-step for what happens between "engineering tagged m9-launch" and "first user downloads from App Store".

- [ ] **Step 1: Create `docs/release/PRE-LAUNCH.md`**

```markdown
# Trackr — Pre-Launch Operational Runbook

> Steps the human owner runs after `m9-launch` is tagged. Each section is an
> independent track and they overlap in time. Engineering is done; this is
> business / ops / legal work.

## Sequence

```
Week 0 (M9 engineering tagged)
  ├── Track A: Name lock (trademark, App Store search, domain)
  ├── Track B: Apple Developer Program enrollment
  ├── Track C: Legal — privacy + terms drafted + hosted
  └── Track D: Marketing — screenshots polished, copy reviewed

Week 1
  ├── A → finalize name; if changed, run "Name Swap" below
  ├── B → real Team ID acquired; run "Identifier Swap" below
  ├── C → publish privacy + terms; update BrandConfig URLs
  └── D → upload screenshots to ASC

Week 2
  ├── App Store Connect record created with all metadata
  ├── TestFlight build uploaded
  └── Internal beta starts

Week 3
  ├── Beta feedback triage
  └── Critical bug fixes

Week 4
  └── Submit for Review
```

## Track A — Name lock

Currently the app is built as "Trackr". Verify in parallel:

1. **USPTO trademark search** — https://tmsearch.uspto.gov/ — look for
   live registrations / pending applications on "Trackr" (and variants
   "Trakr", "Trackrr", "TrackrApp") in classes 9 (downloadable software)
   and 42 (SaaS).
2. **App Store search** — App Store app on iPhone + https://www.apple.com/app-store/
   — type "Trackr" and confirm no popular existing app holds the name.
3. **Domain check** — `trackr.app`, `trackr.io`, `gettrackr.com` — register
   whichever variant is available via Namecheap / Cloudflare.
4. **China region** — additional check via 中国商标网 (https://sbj.cnipa.gov.cn/)
   if planning a China region App Store release.

**If the name needs to change**, follow "Name Swap" below.

### Name Swap (only if step A1-A4 reveals a conflict)

If the final name differs from "Trackr", edit these files (Swift first, then
the build-time duplicates):

1. `Trackr/Core/Brand/BrandConfig.swift` — `appDisplayName`
2. `project.yml` — `CFBundleDisplayName` in both `Trackr:` and `Widgets:`
   target `info.properties` blocks
3. `docs/release/app-store-listing-en.md` and `app-store-listing-zh-Hans.md` —
   replace every "Trackr" with the new name
4. `docs/release/RELEASE-CHECKLIST.md` — same
5. (Cosmetic) repo and folder renames — defer until after submission

Run `xcodegen generate` + the full test suite. Snapshot baselines will
regenerate the next time `StoreScreenshotsTests` runs.

## Track B — Apple Developer Program

1. Enroll at https://developer.apple.com/programs/ ($99/yr individual,
   or $99/yr organization with D-U-N-S verification).
2. Once approved, the Team ID is a 10-char prefix like `A1B2C3D4E5`.
3. Apple-controlled identifiers (App ID, App Group, CloudKit) all live
   under that Team ID.

### Identifier Swap (when the Team ID is known)

The placeholder identifiers across the project need a one-time substitution.
Let `TEAM = A1B2C3D4E5` and (assuming the name stays "Trackr") let the new
identifiers be:

- Bundle ID: `app.trackr.ios`  *(or whatever rDNS root you registered)*
- Widget bundle ID: `app.trackr.ios.widgets`
- App Group: `group.app.trackr.ios`
- CloudKit container: `iCloud.app.trackr.ios`

Edit:

1. **`Trackr/Core/Brand/BrandConfig.swift`** — update all 4 constants:
   `bundleIdentifier`, `appGroupIdentifier`, `cloudKitContainerIdentifier`
   (the BrandConfig tests assert shape, not exact value, so they keep passing)
2. **`project.yml`** — three `PRODUCT_BUNDLE_IDENTIFIER` lines under
   `Trackr:`, `TrackrTests:`, `Widgets:` targets
3. **`Trackr.entitlements`** — `com.apple.security.application-groups` array
   and `com.apple.developer.icloud-container-identifiers` array
4. **`Widgets.entitlements`** — `com.apple.security.application-groups`
5. **`Configuration.storekit`** — both `productID` fields:
   `app.trackr.ios.pro.monthly` and `app.trackr.ios.pro.lifetime`
6. **App Store Connect** — create matching IAP product records with the new
   IDs and approve them for sale

Then in the Developer portal:
- Register the App ID(s) with the team prefix
- Register the App Group identifier
- Register the iCloud Container identifier
- Re-generate provisioning profiles (or rely on Xcode automatic signing)

Re-run the full suite + a clean build to confirm:
```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr clean build
xcodebuild -project Trackr.xcodeproj -scheme Trackr test
```

## Track C — Legal

1. **Privacy policy** — drafted to cover: data collected (none off-device),
   third-party services used (none), Apple StoreKit / CloudKit role,
   children's privacy (compliant — no behavioral data collection), retention,
   user rights (data is on-device so user controls deletion via Settings →
   Apple ID → iCloud), contact email. Translate to Simplified Chinese.
2. **Terms of service** — license to use the app, IAP terms (auto-renewing
   subscription disclosure, refund policy via Apple), limitations of
   liability, governing law, contact. Translate to Simplified Chinese.
3. **Host both** at stable HTTPS URLs (GitHub Pages on a custom domain is
   fine; Cloudflare Pages is fine). Both URLs must return 200 with the
   right `Content-Type: text/html` and remain valid for the life of the app.
4. **Update `BrandConfig.privacyPolicyURL` and `BrandConfig.termsOfServiceURL`**
   to the published URLs. The `BrandConfig_Tests.test_privacyPolicyURL_isAbsoluteHTTPS`
   and `test_termsOfServiceURL_isAbsoluteHTTPS` tests assert shape; they
   pass with any HTTPS URL.

## Track D — Marketing assets

1. **Screenshots** — start from
   `TrackrTests/__Snapshots__/StoreScreenshots_Tests/*.png` (1290×2796 each,
   recorded by `StoreScreenshotsTests`). The designer can either:
   (a) upload as-is for the first version, or
   (b) wrap each in a marketing frame (device bezels, headline copy) before
       upload.
2. **App Store Connect upload** — App Store Connect → Trackr → Version 1.0.0
   → Screenshots → drag in the 6.7" set first, then any other supported
   sizes.
3. **Localized listings** — paste
   `docs/release/app-store-listing-en.md` into the English locale fields
   and `app-store-listing-zh-Hans.md` into the Simplified Chinese locale
   fields. App Store Connect treats each locale's fields independently.
4. **Promo art (optional)** — App Store now supports a promotional video
   per locale; out of scope for v1.

## Preset catalog hosting

Until a real CDN endpoint is wired up, `BrandConfig.presetCatalogURL` points
at `https://presets.invalid/...` — every fetch fails and the bundled
`presets.bundled.json` drives the LIBRARY tab. To enable remote price-change
detection in production:

1. Stand up a static-file host (S3 + CloudFront, Cloudflare R2 + Workers,
   or GitHub Pages) serving JSON over HTTPS.
2. Author the real catalog (60+ items per M5 spec) following the schema in
   `Trackr/Resources/presets.bundled.json`. The remote payload must match
   the `PresetCatalog` Codable shape (`version` + `items`).
3. Update `BrandConfig.presetCatalogURL` to the live URL. No code change
   beyond that constant.
4. Verify on-device: install the production build, wait for `PresetSync.run`
   to fire on `HomeView.task`, confirm `PresetCache.version` matches the
   remote.

## TestFlight rollout

1. Archive a release build in Xcode (Product → Archive).
2. Validate the archive (Window → Organizer → Validate App).
3. Upload to App Store Connect (Window → Organizer → Distribute App →
   App Store Connect).
4. Once processing completes (15-30 min), the build appears under
   App Store Connect → TestFlight.
5. Add an Internal Testing group; invite up to 100 internal testers
   (Apple Developer Program team members) via email.
6. Tester acceptance is one-click via the TestFlight iOS app.

## Beta loop

1. Internal beta: 1 week minimum.
2. Track issues in any tracker (Linear, GitHub Issues, plain text in this
   repo). Pri-1 = block submission; Pri-2 = block release; Pri-3 = fix
   post-launch.
3. Address all Pri-1 issues; re-upload; new build to TestFlight; testers
   reverify.
4. Once Pri-1 list is empty AND every line in
   `docs/release/RELEASE-CHECKLIST.md` is checked, submit for review.

## Submit for Review

1. App Store Connect → Trackr → Version 1.0.0 → "Submit for Review".
2. App Review notes: include the sandbox Apple ID for the IAP test path
   and a quick "how to reach Pro features" guide.
3. Typical review turnaround: 24-48 hours.
4. On approval: choose manual release (the safer option for a first
   launch) so you can flip the switch at a chosen moment.
```

- [ ] **Step 2: Commit**

```bash
git add docs/release/PRE-LAUNCH.md
git commit -m "docs(release): add pre-launch operational runbook"
```

---

### Task 10: E2E + acceptance + tag

**Files:** none — verification only.

- [ ] **Step 1: Clean build**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  clean build 2>&1 | tail -3
```

Exit 0.

- [ ] **Step 2: Full test suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 218 tests, **TEST SUCCEEDED**.

- [ ] **Step 3: Sanity-check the bundle metadata**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Info.plist"
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Info.plist"
```

Expected:
- `CFBundleShortVersionString`: `1.0.0`
- `CFBundleIdentifier`: `com.placeholder.trackr` (the placeholder swap is a human follow-up per `PRE-LAUNCH.md`)

- [ ] **Step 4: Tag**

```bash
git tag m9-launch
git tag --list 'm*'
git show m9-launch --stat --no-patch
```

Expected tags: `m1-foundation`, `m2-data`, `m3-crud-ui`, `m4-notifications`, `m5-presets`, `m6-iap`, `m7-widget-sync`, `m8-polish`, `m9-launch`.

- [ ] **Step 5: Acceptance inventory**

```bash
echo '=== M9 new core files ==='
git ls-files Trackr/Core/Brand
echo
echo '=== Release docs ==='
git ls-files docs/release
echo
echo '=== Screenshot baselines ==='
ls TrackrTests/__Snapshots__/StoreScreenshots_Tests/
echo
echo '=== Test files added since m8-polish ==='
git diff --name-only --diff-filter=A m8-polish HEAD -- TrackrTests | sort
echo
echo '=== Commit count m8-polish..HEAD ==='
git rev-list m8-polish..HEAD --count
```

- [ ] **Step 6: Final placeholder grep (engineering snapshot — not a release gate)**

```bash
grep -rn 'placeholder' Trackr.entitlements Widgets.entitlements project.yml \
    Configuration.storekit Trackr/Core/Brand/BrandConfig.swift 2>/dev/null
```

This WILL produce output (the placeholder swap is documented as a human follow-up). The expected output is several lines — they're what `PRE-LAUNCH.md → Identifier Swap` instructs the human to replace. The test count + tag is the engineering acceptance; placeholder removal is operational.

---

## M9 Acceptance Summary

- `BrandConfig` (pure Swift enum, 8 tests) centralizes the runtime-readable deployment identifiers.
- `SettingsView` and `TrackrApp` route their hard-coded URLs through `BrandConfig`.
- `MARKETING_VERSION` bumped from `0.1.0` to `1.0.0`.
- App Store marketing copy authored in both `en` and `zh-Hans` Markdown files.
- `StoreScreenshotsTests` records 5 hero scenes at iPhone 6.7" frame size (1290×2796 px PNGs ready to upload).
- `RELEASE-CHECKLIST.md` carries the Apple Review self-check; `PRE-LAUNCH.md` carries the operational runbook covering name lock, identifier swap, legal hosting, screenshot polish, TestFlight, and submission.
- 13 net new tests (8 BrandConfig + 5 StoreScreenshots) → **218 total, 0 failures**.

**Engineering acceptance:** `git tag m9-launch` set; clean build green; full suite green.

**Operational acceptance (out of M9's coding scope; tracked in PRE-LAUNCH.md):**
- Trademark / App Store name / domain availability search complete
- Real Apple Developer Team ID acquired and substituted into bundle / App Group / CloudKit / `.storekit` identifiers
- Privacy policy + Terms of Service published at stable HTTPS URLs (and `BrandConfig` updated to point at them)
- App Store Connect record created with both locales filled in from the Markdown listings
- TestFlight build uploaded; internal beta completed with all Pri-1 issues resolved
- "Submit for Review" clicked

When all operational items above are also done, Trackr 1.0 is ready to ship.
