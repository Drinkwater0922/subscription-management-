# Milestone 5 — Preset Library + Price-Change Alerts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A bundled preset catalog and remote-fetch pipeline that (a) lets the user one-tap pre-fill the Add Subscription form from a known SaaS list, and (b) surfaces a banner on the Detail screen whenever the remote catalog reports a price change for a preset the user is tracking.

**Architecture:**
- Pure-Codable `PresetItem` / `PresetCatalog` types describe the JSON contract; `presets.bundled.json` ships in the app bundle as the seed. `PresetBundleLoader` reads it, `PresetFetcher` (protocol + URLSession impl + test fake) talks to the remote endpoint. All of this is pure I/O — no SwiftData.
- `PriceChangeDiffer` is a pure function: given the previously-cached catalog, the freshly-fetched one, and the user's subscriptions, it returns the `[PriceChangeAlert]` rows the alert repo should persist. `PresetSync` is the orchestrator that wires the loader/fetcher/differ together and writes through to `PresetCache` + `AlertRepository`.
- The Add Subscription sheet gains a `CUSTOM | LIBRARY` segmented picker. The LIBRARY tab is a searchable, category-grouped list rendered from the bundled catalog. Tapping a row converts the preset into a `SubscriptionDraft`, flips the tab back to CUSTOM so the user can adjust the prefilled values, and lets the existing save path do the rest.
- The Detail screen grows a `PriceChangeBanner` component: when the displayed subscription has a `presetId` and there's an unseen `PriceChangeAlert` for that preset, the banner renders at the top of the read body. Tapping it marks the alert seen and the banner disappears.
- Push notifications for price changes are M6 (Pro-only); M5 only shows the in-app banner.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData (iOS 17), `URLSession`, XCTest, swift-snapshot-testing. No new third-party deps.

---

## File Structure

After M5 the new code looks like this (only new + modified files shown):

```
Trackr/
├─ Resources/
│  └─ presets.bundled.json                       # NEW — seed catalog
├─ Core/
│  └─ Presets/
│     ├─ PresetItem.swift                         # NEW — Codable item + toDraft helper
│     ├─ PresetCatalog.swift                      # NEW — Codable envelope
│     ├─ PresetBundleLoader.swift                 # NEW — reads presets.bundled.json
│     ├─ PresetFetcher.swift                      # NEW — protocol + URLSession impl
│     ├─ PriceChangeDiffer.swift                  # NEW — pure diff function
│     └─ PresetSync.swift                         # NEW — orchestrator
└─ Features/
   ├─ AddSubscription/
   │  ├─ AddSubscriptionSheet.swift               # MODIFIED — tab picker
   │  └─ PresetLibraryView.swift                  # NEW — LIBRARY tab
   └─ Detail/
      ├─ SubscriptionDetailView.swift             # MODIFIED — alert banner
      └─ PriceChangeBanner.swift                  # NEW — inline banner component

Trackr/TrackrApp.swift                            # MODIFIED — kicks off PresetSync on launch

TrackrTests/
├─ FakePresetFetcher.swift                        # NEW — test fake (no `_Tests` suffix)
├─ PresetItem_Tests.swift
├─ PresetCatalog_Tests.swift
├─ PresetBundleLoader_Tests.swift
├─ PresetFetcher_Tests.swift
├─ PriceChangeDiffer_Tests.swift
├─ PresetSync_Tests.swift
├─ PresetLibraryView_Snapshot_Tests.swift
├─ AddSubscriptionSheet_TabSwitch_Tests.swift
└─ PriceChangeBanner_Snapshot_Tests.swift
```

The bundled JSON ships under `Trackr/Resources/`. The `project.yml` already globs `Trackr/**`, so xcodegen picks up the new directory automatically; the JSON file just needs to be copied into the app bundle. We'll add a `resources:` directive to keep that explicit.

---

### Task 1: `PresetItem` Codable type + `toDraft` helper (TDD)

**Files:**
- Create: `Trackr/Core/Presets/PresetItem.swift`
- Create: `TrackrTests/PresetItem_Tests.swift`

Plain Codable struct mirroring the JSON schema for one library entry. `toDraft` converts it into a `SubscriptionDraft` so the LIBRARY tap handler is a one-liner.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/PresetItem_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class PresetItemTests: XCTestCase {

    private let json = #"""
    {
      "id": "netflix.standard",
      "name": "Netflix",
      "defaultPlanName": "Standard",
      "defaultAmount": "15.49",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "media",
      "iconRef": "preset:netflix.standard"
    }
    """#

    func test_decode_parsesAllFields() throws {
        let item = try JSONDecoder().decode(PresetItem.self,
                                            from: Data(json.utf8))
        XCTAssertEqual(item.id, "netflix.standard")
        XCTAssertEqual(item.name, "Netflix")
        XCTAssertEqual(item.defaultPlanName, "Standard")
        XCTAssertEqual(item.defaultAmount, Decimal(string: "15.49"))
        XCTAssertEqual(item.defaultCurrency, "USD")
        XCTAssertEqual(item.defaultCycle, .monthly)
        XCTAssertEqual(item.category, .media)
        XCTAssertEqual(item.iconRef, "preset:netflix.standard")
    }

    func test_decode_yearly_yearlyCycle() throws {
        let yearlyJSON = json.replacingOccurrences(of: "\"monthly\"", with: "\"yearly\"")
        let item = try JSONDecoder().decode(PresetItem.self, from: Data(yearlyJSON.utf8))
        XCTAssertEqual(item.defaultCycle, .yearly)
    }

    func test_decode_weekly_weeklyCycle() throws {
        let weeklyJSON = json.replacingOccurrences(of: "\"monthly\"", with: "\"weekly\"")
        let item = try JSONDecoder().decode(PresetItem.self, from: Data(weeklyJSON.utf8))
        XCTAssertEqual(item.defaultCycle, .weekly)
    }

    func test_toDraft_populatesAllFields() throws {
        let item = try JSONDecoder().decode(PresetItem.self, from: Data(json.utf8))
        let draft = item.toDraft(defaultStart: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(draft.name, "Netflix")
        XCTAssertEqual(draft.planName, "Standard")
        XCTAssertEqual(draft.amountString, "15.49")
        XCTAssertEqual(draft.currency, "USD")
        XCTAssertEqual(draft.billingCycle, .monthly)
        XCTAssertEqual(draft.category, .media)
        XCTAssertEqual(draft.startDate, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func test_toDraft_buildsSubscriptionWithPresetId() throws {
        let item = try JSONDecoder().decode(PresetItem.self, from: Data(json.utf8))
        let draft = item.toDraft(defaultStart: .distantPast)
        let sub = try draft.makeSubscription()
        // makeSubscription does NOT set presetId (the draft doesn't carry it);
        // PresetSync will need to stamp it separately on the new Subscription.
        // We verify the draft's fields here and leave presetId stamping to Task 7.
        XCTAssertEqual(sub.name, "Netflix")
        XCTAssertEqual(sub.amount, Decimal(string: "15.49"))
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
Expected: `cannot find 'PresetItem' in scope`.

- [ ] **Step 3: Implement `PresetItem.swift`**

Create `Trackr/Core/Presets/PresetItem.swift`:
```swift
import Foundation

/// One entry in the preset library. Mirrors the JSON schema of
/// `presets.bundled.json` / the remote catalog. `defaultAmount` is decoded
/// from a String to preserve `Decimal` precision (JSON numbers round-trip
/// through `Double` otherwise).
struct PresetItem: Codable, Equatable, Hashable {
    let id: String
    let name: String
    let defaultPlanName: String
    let defaultAmount: Decimal
    let defaultCurrency: String
    let defaultCycle: BillingCycle
    let category: Category
    let iconRef: String

    enum CodingKeys: String, CodingKey {
        case id, name, defaultPlanName, defaultAmount, defaultCurrency,
             defaultCycle, category, iconRef
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.defaultPlanName = try c.decode(String.self, forKey: .defaultPlanName)

        let amountString = try c.decode(String.self, forKey: .defaultAmount)
        guard let amount = Decimal(string: amountString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .defaultAmount, in: c,
                debugDescription: "Expected Decimal-parsable string, got \(amountString)"
            )
        }
        self.defaultAmount = amount

        self.defaultCurrency = try c.decode(String.self, forKey: .defaultCurrency)

        let cycleString = try c.decode(String.self, forKey: .defaultCycle)
        switch cycleString {
        case "monthly": self.defaultCycle = .monthly
        case "yearly":  self.defaultCycle = .yearly
        case "weekly":  self.defaultCycle = .weekly
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .defaultCycle, in: c,
                debugDescription: "Unknown cycle \(cycleString) — M5 doesn't ship customDays presets"
            )
        }

        let categoryString = try c.decode(String.self, forKey: .category)
        guard let cat = Category(rawValue: categoryString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .category, in: c,
                debugDescription: "Unknown category \(categoryString)"
            )
        }
        self.category = cat

        self.iconRef = try c.decode(String.self, forKey: .iconRef)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(defaultPlanName, forKey: .defaultPlanName)
        try c.encode("\(defaultAmount)", forKey: .defaultAmount)
        try c.encode(defaultCurrency, forKey: .defaultCurrency)
        let cycleString: String
        switch defaultCycle {
        case .monthly:           cycleString = "monthly"
        case .yearly:            cycleString = "yearly"
        case .weekly:            cycleString = "weekly"
        case .customDays:        cycleString = "monthly" // not exported in M5
        }
        try c.encode(cycleString, forKey: .defaultCycle)
        try c.encode(category.rawValue, forKey: .category)
        try c.encode(iconRef, forKey: .iconRef)
    }

    /// Convert the preset into a `SubscriptionDraft` so the Add form can render
    /// the user's tweaks before they hit SAVE.
    func toDraft(defaultStart: Date = .now) -> SubscriptionDraft {
        SubscriptionDraft(
            name: name,
            planName: defaultPlanName,
            amountString: "\(defaultAmount)",
            currency: defaultCurrency,
            billingCycle: defaultCycle,
            customDays: 30,
            startDate: defaultStart,
            category: category,
            notes: "",
            urlString: ""
        )
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```
Expected: 134 + 5 = 139 tests, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Presets/PresetItem.swift TrackrTests/PresetItem_Tests.swift
git commit -m "feat(presets): add PresetItem Codable with toDraft helper"
```

---

### Task 2: `PresetCatalog` + bundled JSON + `PresetBundleLoader` (TDD)

**Files:**
- Create: `Trackr/Core/Presets/PresetCatalog.swift`
- Create: `Trackr/Core/Presets/PresetBundleLoader.swift`
- Create: `Trackr/Resources/presets.bundled.json`
- Modify: `project.yml` (add the new resource to the Trackr target)
- Create: `TrackrTests/PresetCatalog_Tests.swift`
- Create: `TrackrTests/PresetBundleLoader_Tests.swift`

The envelope: `{ "version": "1.0.0", "items": [...] }`. Versioned with a string so we don't risk semver math during a sync.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/PresetCatalog_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class PresetCatalogTests: XCTestCase {

    private let json = #"""
    {
      "version": "1.0.0",
      "items": [
        {
          "id": "netflix.standard",
          "name": "Netflix",
          "defaultPlanName": "Standard",
          "defaultAmount": "15.49",
          "defaultCurrency": "USD",
          "defaultCycle": "monthly",
          "category": "media",
          "iconRef": "preset:netflix.standard"
        }
      ]
    }
    """#

    func test_decode_versionAndItems() throws {
        let catalog = try JSONDecoder().decode(PresetCatalog.self,
                                               from: Data(json.utf8))
        XCTAssertEqual(catalog.version, "1.0.0")
        XCTAssertEqual(catalog.items.count, 1)
        XCTAssertEqual(catalog.items.first?.id, "netflix.standard")
    }

    func test_lookupById_returnsItem() throws {
        let catalog = try JSONDecoder().decode(PresetCatalog.self,
                                               from: Data(json.utf8))
        XCTAssertEqual(catalog.item(withID: "netflix.standard")?.name, "Netflix")
        XCTAssertNil(catalog.item(withID: "nope"))
    }
}
```

Create `TrackrTests/PresetBundleLoader_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class PresetBundleLoaderTests: XCTestCase {

    func test_loadBundledCatalog_succeedsAndHasItems() throws {
        let catalog = try PresetBundleLoader.loadBundled()
        XCTAssertFalse(catalog.version.isEmpty)
        XCTAssertGreaterThanOrEqual(catalog.items.count, 5,
                                    "bundled catalog should ship at least the M5 seed list")
    }

    func test_loadBundledCatalog_versionMatchesSeed() throws {
        let catalog = try PresetBundleLoader.loadBundled()
        XCTAssertEqual(catalog.version, "1.0.0",
                       "seed catalog version is pinned in M5; bump deliberately")
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'PresetCatalog' / 'PresetBundleLoader'`.

- [ ] **Step 3: Implement `PresetCatalog.swift`**

Create `Trackr/Core/Presets/PresetCatalog.swift`:
```swift
import Foundation

/// JSON envelope around `[PresetItem]`. `version` is a plain string —
/// `PresetSync` only compares it for equality, never parses semver.
struct PresetCatalog: Codable, Equatable {
    let version: String
    let items: [PresetItem]

    func item(withID id: String) -> PresetItem? {
        items.first { $0.id == id }
    }
}
```

- [ ] **Step 4: Implement `PresetBundleLoader.swift`**

Create `Trackr/Core/Presets/PresetBundleLoader.swift`:
```swift
import Foundation

/// Reads `presets.bundled.json` out of the main bundle and decodes it into a
/// `PresetCatalog`. Crashes the app at launch if the file is missing or invalid
/// — that's a programmer error caught long before App Store review.
enum PresetBundleLoader {

    enum LoaderError: Error {
        case missingFile
    }

    static func loadBundled(bundle: Bundle = .main) throws -> PresetCatalog {
        guard let url = bundle.url(forResource: "presets.bundled",
                                   withExtension: "json") else {
            throw LoaderError.missingFile
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PresetCatalog.self, from: data)
    }
}
```

- [ ] **Step 5: Create the bundled JSON file**

Create `Trackr/Resources/presets.bundled.json`:
```json
{
  "version": "1.0.0",
  "items": [
    {
      "id": "chatgpt.plus",
      "name": "ChatGPT Plus",
      "defaultPlanName": "Plus",
      "defaultAmount": "20.00",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "ai",
      "iconRef": "preset:chatgpt.plus"
    },
    {
      "id": "claude.pro",
      "name": "Claude",
      "defaultPlanName": "Pro",
      "defaultAmount": "20.00",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "ai",
      "iconRef": "preset:claude.pro"
    },
    {
      "id": "github.copilot",
      "name": "GitHub Copilot",
      "defaultPlanName": "Individual",
      "defaultAmount": "10.00",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "dev",
      "iconRef": "preset:github.copilot"
    },
    {
      "id": "netflix.standard",
      "name": "Netflix",
      "defaultPlanName": "Standard",
      "defaultAmount": "15.49",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "media",
      "iconRef": "preset:netflix.standard"
    },
    {
      "id": "spotify.premium",
      "name": "Spotify",
      "defaultPlanName": "Premium",
      "defaultAmount": "10.99",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "media",
      "iconRef": "preset:spotify.premium"
    },
    {
      "id": "apple.music",
      "name": "Apple Music",
      "defaultPlanName": "Individual",
      "defaultAmount": "10.99",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "media",
      "iconRef": "preset:apple.music"
    },
    {
      "id": "icloud.50",
      "name": "iCloud+",
      "defaultPlanName": "50GB",
      "defaultAmount": "0.99",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "cloud",
      "iconRef": "preset:icloud.50"
    },
    {
      "id": "notion.pro",
      "name": "Notion",
      "defaultPlanName": "Personal Pro",
      "defaultAmount": "8.00",
      "defaultCurrency": "USD",
      "defaultCycle": "monthly",
      "category": "productivity",
      "iconRef": "preset:notion.pro"
    }
  ]
}
```

8 seed items across 5 categories. The "~60 items" goal from the roadmap is content curation; engineering ships the pipeline.

- [ ] **Step 6: Wire the JSON file into the app bundle**

Open `/Users/jingxue/Downloads/CC/subscription/project.yml`. Find the `Trackr:` target block (the one with `type: application`). Below the `sources:` block add an explicit `resources:` block so the file is copied:

```yaml
  Trackr:
    type: application
    platform: iOS
    sources:
      - path: Trackr
    resources:
      - path: Trackr/Resources/presets.bundled.json
```

Note: if `xcodegen` already picks the JSON up via the `sources: - path: Trackr` glob (it does — but as a "source" not a "resource"), you may see a build warning or the file may not land in the bundle. The explicit `resources:` entry is the safe path. After editing the YAML, run `xcodegen generate` and confirm the JSON appears in the project navigator under a Resources group.

- [ ] **Step 7: Run, verify tests pass**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 139 + 2 + 2 = 143 tests.

- [ ] **Step 8: Commit**

```bash
git add Trackr/Core/Presets/PresetCatalog.swift \
        Trackr/Core/Presets/PresetBundleLoader.swift \
        Trackr/Resources/presets.bundled.json \
        project.yml \
        TrackrTests/PresetCatalog_Tests.swift \
        TrackrTests/PresetBundleLoader_Tests.swift
git commit -m "feat(presets): add PresetCatalog, bundled seed JSON, bundle loader"
```

---

### Task 3: `PresetFetcher` protocol + URLSession impl + test fake (TDD)

**Files:**
- Create: `Trackr/Core/Presets/PresetFetcher.swift`
- Create: `TrackrTests/FakePresetFetcher.swift`
- Create: `TrackrTests/PresetFetcher_Tests.swift`

Narrow protocol the orchestrator depends on. Real implementation hits an HTTPS URL via `URLSession.shared`. The fake returns canned data and records the URL it was asked to fetch.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/PresetFetcher_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class PresetFetcherTests: XCTestCase {

    func test_urlSessionFetcher_holdsConfiguredURL() {
        let url = URL(string: "https://example.com/presets.json")!
        let fetcher = URLSessionPresetFetcher(catalogURL: url)
        XCTAssertEqual(fetcher.catalogURL, url)
    }
}
```

Create `TrackrTests/FakePresetFetcher.swift`:
```swift
import Foundation
@testable import Trackr

/// In-memory `PresetFetcher` for tests. Set `result` to the catalog you want
/// returned (or `error` to throw). `fetchedURL` is captured for assertion.
final class FakePresetFetcher: PresetFetcher {

    var result: PresetCatalog?
    var error: Error?
    private(set) var fetchCallCount = 0

    func fetch() async throws -> PresetCatalog {
        fetchCallCount += 1
        if let error { throw error }
        guard let result else {
            struct Unconfigured: Error {}
            throw Unconfigured()
        }
        return result
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'PresetFetcher' / 'URLSessionPresetFetcher'`.

- [ ] **Step 3: Implement `PresetFetcher.swift`**

Create `Trackr/Core/Presets/PresetFetcher.swift`:
```swift
import Foundation

/// Narrow seam for fetching `PresetCatalog` from a remote source. Tests inject
/// `FakePresetFetcher`; production wires `URLSessionPresetFetcher`.
protocol PresetFetcher: AnyObject {
    func fetch() async throws -> PresetCatalog
}

/// Hits an HTTPS URL via `URLSession.shared`. The URL is injected at construction
/// time so tests / config flips can point at staging.
final class URLSessionPresetFetcher: PresetFetcher {

    let catalogURL: URL
    private let session: URLSession

    init(catalogURL: URL, session: URLSession = .shared) {
        self.catalogURL = catalogURL
        self.session = session
    }

    enum FetchError: Error {
        case badResponse(Int)
    }

    func fetch() async throws -> PresetCatalog {
        let (data, response) = try await session.data(from: catalogURL)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.badResponse(http.statusCode)
        }
        return try JSONDecoder().decode(PresetCatalog.self, from: data)
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 143 + 1 = 144 tests. The `FakePresetFetcher` adds zero tests on its own (Task 5 exercises it).

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Presets/PresetFetcher.swift \
        TrackrTests/FakePresetFetcher.swift \
        TrackrTests/PresetFetcher_Tests.swift
git commit -m "feat(presets): add PresetFetcher protocol with URLSession impl and test fake"
```

---

### Task 4: `PriceChangeDiffer` (TDD)

**Files:**
- Create: `Trackr/Core/Presets/PriceChangeDiffer.swift`
- Create: `TrackrTests/PriceChangeDiffer_Tests.swift`

Pure function: `diff(old:, new:, subscriptions:, now:) -> [PriceChangeAlert]`. For each `presetId` that exists in both catalogs and whose `defaultAmount` differs, emit one `PriceChangeAlert` per active subscription tracking that preset.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/PriceChangeDiffer_Tests.swift`:
```swift
import XCTest
@testable import Trackr

@MainActor
final class PriceChangeDifferTests: XCTestCase {

    private func item(id: String, amount: String, plan: String = "Standard") -> PresetItem {
        let json = #"""
        {
          "id": "\#(id)",
          "name": "\#(id)",
          "defaultPlanName": "\#(plan)",
          "defaultAmount": "\#(amount)",
          "defaultCurrency": "USD",
          "defaultCycle": "monthly",
          "category": "media",
          "iconRef": "preset:\#(id)"
        }
        """#
        return try! JSONDecoder().decode(PresetItem.self, from: Data(json.utf8))
    }

    private func sub(presetId: String?) -> Subscription {
        Subscription(
            name: presetId ?? "X",
            amount: 0,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture,
            startDate: .now,
            category: .media,
            presetId: presetId
        )
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func test_noChange_returnsEmpty() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "10")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result, [])
    }

    func test_amountChange_emitsOneAlertPerSubscription() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "12")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a"),
                                                            sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.oldAmount, 10)
        XCTAssertEqual(result.first?.newAmount, 12)
        XCTAssertEqual(result.first?.presetId, "a")
    }

    func test_newPresetAdded_noAlert() {
        let old = PresetCatalog(version: "1", items: [])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "10")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result, [])
    }

    func test_presetRemoved_noAlert() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result, [])
    }

    func test_subscriptionWithoutPresetId_isIgnored() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "12")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: nil)],
                                            now: now)
        XCTAssertEqual(result, [])
    }

    func test_alertCarriesEnglishAndChineseMessages() {
        let old = PresetCatalog(version: "1", items: [item(id: "a", amount: "10")])
        let new = PresetCatalog(version: "2", items: [item(id: "a", amount: "12")])
        let result = PriceChangeDiffer.diff(old: old, new: new,
                                            subscriptions: [sub(presetId: "a")],
                                            now: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].messageEn.contains("10"),
                      "en message: \(result[0].messageEn)")
        XCTAssertTrue(result[0].messageEn.contains("12"),
                      "en message: \(result[0].messageEn)")
        XCTAssertFalse(result[0].messageZh.isEmpty)
    }
}
```

`PriceChangeAlert` is an `@Model` (reference type). Equating two model instances with `XCTAssertEqual(result, [])` would compare references and likely "succeed" on empty arrays but fail elsewhere — for `result.count` / `XCTAssertEqual(result.first?.oldAmount, ...)` we read field by field, which is correct. The `XCTAssertEqual(result, [])` lines only assert that the count is 0 (an empty array compares to an empty array regardless of element identity).

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'PriceChangeDiffer'`.

- [ ] **Step 3: Implement `PriceChangeDiffer.swift`**

Create `Trackr/Core/Presets/PriceChangeDiffer.swift`:
```swift
import Foundation

/// Pure function: compares two catalogs against the user's subscriptions and
/// emits the `PriceChangeAlert` rows that should be persisted. The orchestrator
/// (`PresetSync`) is responsible for writing them through `AlertRepository`.
enum PriceChangeDiffer {

    static func diff(
        old: PresetCatalog,
        new: PresetCatalog,
        subscriptions: [Subscription],
        now: Date = .now
    ) -> [PriceChangeAlert] {
        let oldByID = Dictionary(uniqueKeysWithValues: old.items.map { ($0.id, $0) })

        var alerts: [PriceChangeAlert] = []
        for newItem in new.items {
            guard let oldItem = oldByID[newItem.id] else { continue }
            guard oldItem.defaultAmount != newItem.defaultAmount else { continue }

            for sub in subscriptions where sub.presetId == newItem.id {
                alerts.append(PriceChangeAlert(
                    presetId: newItem.id,
                    planKey: newItem.defaultPlanName,
                    oldAmount: oldItem.defaultAmount,
                    newAmount: newItem.defaultAmount,
                    currency: newItem.defaultCurrency,
                    effectiveDate: now,
                    messageEn: enMessage(item: newItem,
                                         oldAmount: oldItem.defaultAmount,
                                         newAmount: newItem.defaultAmount),
                    messageZh: zhMessage(item: newItem,
                                         oldAmount: oldItem.defaultAmount,
                                         newAmount: newItem.defaultAmount),
                    seenAt: nil,
                    createdAt: now
                ))
            }
        }
        return alerts
    }

    private static func enMessage(item: PresetItem,
                                  oldAmount: Decimal,
                                  newAmount: Decimal) -> String {
        let oldStr = AmountFormatter.format(oldAmount, currency: item.defaultCurrency)
        let newStr = AmountFormatter.format(newAmount, currency: item.defaultCurrency)
        let direction = newAmount > oldAmount ? "raised" : "lowered"
        return "\(item.name) \(direction) its \(item.defaultPlanName) price from \(oldStr) to \(newStr)."
    }

    private static func zhMessage(item: PresetItem,
                                  oldAmount: Decimal,
                                  newAmount: Decimal) -> String {
        let oldStr = AmountFormatter.format(oldAmount, currency: item.defaultCurrency)
        let newStr = AmountFormatter.format(newAmount, currency: item.defaultCurrency)
        let direction = newAmount > oldAmount ? "上调" : "下调"
        return "\(item.name) \(item.defaultPlanName) 价格已\(direction)，由 \(oldStr) 变为 \(newStr)。"
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 144 + 6 = 150 tests.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Presets/PriceChangeDiffer.swift \
        TrackrTests/PriceChangeDiffer_Tests.swift
git commit -m "feat(presets): add PriceChangeDiffer with TDD"
```

---

### Task 5: `PresetSync` orchestrator (TDD)

**Files:**
- Create: `Trackr/Core/Presets/PresetSync.swift`
- Create: `TrackrTests/PresetSync_Tests.swift`

`run()` is the single entry point. Behavior:
1. Load the previous `PresetCache` row (if any). If absent, seed from `PresetBundleLoader.loadBundled()` and write that to the cache.
2. Fetch the remote catalog via the injected `PresetFetcher`.
3. If `remote.version == cached.version` → no-op return.
4. Else → run `PriceChangeDiffer.diff(old: cached, new: remote, subscriptions:)` and persist via `AlertRepository.insert(_:)`; then overwrite the `PresetCache` row with the new catalog bytes + version.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/PresetSync_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class PresetSyncTests: XCTestCase {

    private var container: ModelContainer!
    private var fetcher: FakePresetFetcher!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        fetcher = FakePresetFetcher()
    }

    override func tearDownWithError() throws {
        fetcher = nil
        container = nil
        try super.tearDownWithError()
    }

    private func catalog(version: String, amountForA: String = "10") throws -> PresetCatalog {
        let json = #"""
        {
          "version": "\#(version)",
          "items": [
            {
              "id": "a",
              "name": "Service A",
              "defaultPlanName": "Standard",
              "defaultAmount": "\#(amountForA)",
              "defaultCurrency": "USD",
              "defaultCycle": "monthly",
              "category": "media",
              "iconRef": "preset:a"
            }
          ]
        }
        """#
        return try JSONDecoder().decode(PresetCatalog.self, from: Data(json.utf8))
    }

    private func seedSubscription(presetId: String) throws {
        let sub = Subscription(
            name: "X", amount: 10, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now,
            category: .media,
            presetId: presetId
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()
    }

    func test_firstRun_seedsCacheFromRemote_andEmitsNoAlerts() async throws {
        fetcher.result = try catalog(version: "1.0.0")
        let sync = PresetSync(fetcher: fetcher, container: container)

        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        let cached = try container.mainContext.fetch(FetchDescriptor<PresetCache>())
        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(cached.first?.version, "1.0.0")
        let alerts = try AlertRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(alerts.count, 0,
                       "first run has no previous cache → no diff possible")
    }

    func test_sameVersion_noOp() async throws {
        // Seed the cache to look like a previous run.
        let initial = try catalog(version: "1.0.0")
        let payload = try JSONEncoder().encode(initial)
        let cache = PresetCache(version: "1.0.0", fetchedAt: .now, data: payload)
        container.mainContext.insert(cache)
        try container.mainContext.save()

        fetcher.result = try catalog(version: "1.0.0", amountForA: "999")
        // Even though the remote has a different amount, the version matches so
        // we skip the diff entirely.

        try seedSubscription(presetId: "a")
        let sync = PresetSync(fetcher: fetcher, container: container)

        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        let alerts = try AlertRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(alerts.count, 0,
                       "version match short-circuits the diff path")
    }

    func test_versionBumpWithAmountChange_emitsAlertAndUpdatesCache() async throws {
        let initial = try catalog(version: "1.0.0", amountForA: "10")
        let payload = try JSONEncoder().encode(initial)
        let cache = PresetCache(version: "1.0.0", fetchedAt: .now, data: payload)
        container.mainContext.insert(cache)
        try seedSubscription(presetId: "a")
        try container.mainContext.save()

        fetcher.result = try catalog(version: "1.1.0", amountForA: "12")
        let sync = PresetSync(fetcher: fetcher, container: container)

        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        let alerts = try AlertRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.presetId, "a")
        XCTAssertEqual(alerts.first?.oldAmount, 10)
        XCTAssertEqual(alerts.first?.newAmount, 12)

        let cached = try container.mainContext.fetch(FetchDescriptor<PresetCache>())
        XCTAssertEqual(cached.count, 1, "cache stays a singleton")
        XCTAssertEqual(cached.first?.version, "1.1.0",
                       "cache version flips to the freshly-fetched one")
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'PresetSync'`.

- [ ] **Step 3: Implement `PresetSync.swift`**

Create `Trackr/Core/Presets/PresetSync.swift`:
```swift
import Foundation
import SwiftData

/// Orchestrates the preset library lifecycle:
///   1. Seed `PresetCache` from the bundled catalog on first launch.
///   2. Fetch the remote catalog.
///   3. If the remote version differs from the cached version, run
///      `PriceChangeDiffer` over the user's subscriptions, persist the new
///      alerts, and overwrite the cache.
@MainActor
final class PresetSync {

    private let fetcher: PresetFetcher
    private let container: ModelContainer
    private let bundle: Bundle

    init(fetcher: PresetFetcher,
         container: ModelContainer,
         bundle: Bundle = .main) {
        self.fetcher = fetcher
        self.container = container
        self.bundle = bundle
    }

    func run(now: Date = .now) async throws {
        let context = container.mainContext

        // 1. Load / seed the cache.
        let cacheRow = try context.fetch(FetchDescriptor<PresetCache>()).first
        let cachedCatalog: PresetCatalog
        if let cacheRow {
            cachedCatalog = (try? JSONDecoder().decode(PresetCatalog.self, from: cacheRow.data))
                ?? PresetCatalog(version: cacheRow.version, items: [])
        } else {
            cachedCatalog = (try? PresetBundleLoader.loadBundled(bundle: bundle))
                ?? PresetCatalog(version: "0.0.0", items: [])
            let seedPayload = (try? JSONEncoder().encode(cachedCatalog)) ?? Data()
            let seed = PresetCache(version: cachedCatalog.version,
                                   fetchedAt: now,
                                   data: seedPayload)
            context.insert(seed)
            try context.save()
        }

        // 2. Fetch remote.
        let remote = try await fetcher.fetch()

        // 3. Short-circuit on matching version.
        guard remote.version != cachedCatalog.version else { return }

        // 4. Diff against the user's subscriptions and persist new alerts.
        let subs = try context.fetch(FetchDescriptor<Subscription>())
        let alerts = PriceChangeDiffer.diff(old: cachedCatalog,
                                             new: remote,
                                             subscriptions: subs,
                                             now: now)
        let alertRepo = AlertRepository(context: context)
        for alert in alerts { try alertRepo.insert(alert) }

        // 5. Overwrite the cache row with the remote payload.
        let row = try context.fetch(FetchDescriptor<PresetCache>()).first
        let payload = (try? JSONEncoder().encode(remote)) ?? Data()
        if let row {
            row.version = remote.version
            row.fetchedAt = now
            row.data = payload
        } else {
            context.insert(PresetCache(version: remote.version, fetchedAt: now, data: payload))
        }
        try context.save()
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 150 + 3 = 153 tests.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Presets/PresetSync.swift TrackrTests/PresetSync_Tests.swift
git commit -m "feat(presets): add PresetSync orchestrator with TDD"
```

---

### Task 6: Wire `PresetSync` into `TrackrApp` on launch

**Files:**
- Modify: `Trackr/TrackrApp.swift`
- Modify: `Trackr/Features/Home/HomeView.swift` (kick off sync via `.task`)

We hold one `PresetSync` instance in `TrackrApp`. On `HomeView`'s `.task` (which fires once when the scene attaches), we run the sync as a fire-and-forget — failures (offline, server down) just leave the existing cache in place.

For M5 the remote URL is a placeholder pointing at an unreachable endpoint, so production runs will fail silently. That's fine: the seed catalog from the bundle still drives the LIBRARY tab. M9 swaps the URL to the live host.

- [ ] **Step 1: Modify `TrackrApp.swift`**

Open `/Users/jingxue/Downloads/CC/subscription/Trackr/TrackrApp.swift`. Add `presetSync` alongside the existing properties, instantiate it in `init`, and inject it into the environment.

Add an environment key — append at the bottom of `Trackr/Features/Routing/AppDeepLinkRouter.swift` (the same file that hosts `NotificationCoordinatorKey`):

```swift
private struct PresetSyncKey: EnvironmentKey {
    static let defaultValue: PresetSync? = nil
}

extension EnvironmentValues {
    var presetSync: PresetSync? {
        get { self[PresetSyncKey.self] }
        set { self[PresetSyncKey.self] = newValue }
    }
}
```

Then in `TrackrApp.swift`, replace the file content with:
```swift
import SwiftUI
import SwiftData
import UserNotifications

@main
struct TrackrApp: App {

    private let container: ModelContainer
    private let router: AppDeepLinkRouter
    private let coordinator: NotificationCoordinator
    private let notificationDelegate: TrackrNotificationDelegate
    private let presetSync: PresetSync

    init() {
        do {
            self.container = try ModelContainerConfig.makeAppContainer()
        } catch {
            fatalError("Failed to construct ModelContainer: \(error)")
        }
        self.router = AppDeepLinkRouter()
        self.coordinator = NotificationCoordinator(
            scheduler: LocalNotificationScheduler(center: SystemNotificationCenter()),
            container: container
        )
        self.notificationDelegate = TrackrNotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // M5: the live host lands in M9. Until then we point at a placeholder
        // that fails on every device — the bundled seed catalog drives LIBRARY.
        let catalogURL = URL(string: "https://presets.invalid/trackr/v1/presets.json")!
        self.presetSync = PresetSync(
            fetcher: URLSessionPresetFetcher(catalogURL: catalogURL),
            container: container
        )
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(router)
                .environment(\.notificationCoordinator, coordinator)
                .environment(\.presetSync, presetSync)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: Kick the sync off from `HomeView`**

In `Trackr/Features/Home/HomeView.swift`:

(a) Add an environment property:
```swift
    @Environment(\.presetSync) private var presetSync
```

(b) At the end of the outermost `ZStack` (alongside `.sheet` and `.onChange`), append:
```swift
        .task {
            try? await presetSync?.run()
        }
```

- [ ] **Step 3: Re-record affected snapshot baselines**

`.task` modifiers don't render anything — the snapshots should be byte-identical. Still, the SwiftData fetch inside `PresetSync.run` may insert a `PresetCache` row when the snapshot test's in-memory container has none, which doesn't affect the rendered pixels but does briefly populate state. The existing HomeView snapshots inject `AppDeepLinkRouter()` but no `presetSync` — so `try? await presetSync?.run()` is a no-op when nil. No baseline changes needed.

Run the full suite to confirm:
```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 153 tests, **TEST SUCCEEDED** (no net new tests for Task 6 — it's wiring).

- [ ] **Step 4: Commit**

```bash
git add Trackr/TrackrApp.swift \
        Trackr/Features/Home/HomeView.swift \
        Trackr/Features/Routing/AppDeepLinkRouter.swift
git commit -m "feat(presets): install PresetSync and run on HomeView .task"
```

---

### Task 7: `PresetLibraryView` — search + category-grouped list (snapshot)

**Files:**
- Create: `Trackr/Features/AddSubscription/PresetLibraryView.swift`
- Create: `TrackrTests/PresetLibraryView_Snapshot_Tests.swift`

The new LIBRARY tab. Receives `items: [PresetItem]` and a `onSelect: (PresetItem) -> Void` callback. Top: a search `TextField` (case-insensitive `name.contains`). Body: a `List` (or `ScrollView` + `LazyVStack`) grouped by `Category.displayName`. Each row: monogram-icon · name + plan · default price.

- [ ] **Step 1: Write the failing snapshot tests**

Create `TrackrTests/PresetLibraryView_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class PresetLibraryViewSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func items() throws -> [PresetItem] {
        try PresetBundleLoader.loadBundled().items
    }

    private func host(items: [PresetItem], query: String = "") -> some View {
        PresetLibraryView(items: items,
                          searchQuery: .constant(query),
                          onSelect: { _ in })
            .frame(width: 390, height: 700)
            .preferredColorScheme(.dark)
    }

    func test_fullList_render() throws {
        assertSnapshot(of: host(items: try items()), as: .image)
    }

    func test_searchFiltered_render() throws {
        assertSnapshot(of: host(items: try items(), query: "net"), as: .image)
    }
}
```

- [ ] **Step 2: Run, expect build failure / baseline missing**

Expected: `cannot find 'PresetLibraryView'`.

- [ ] **Step 3: Implement `PresetLibraryView.swift`**

Create `Trackr/Features/AddSubscription/PresetLibraryView.swift`:
```swift
import SwiftUI

/// LIBRARY tab inside the Add Subscription sheet. Pure presentation — receives
/// the catalog items and a callback; never touches SwiftData.
struct PresetLibraryView: View {

    let items: [PresetItem]
    @Binding var searchQuery: String
    let onSelect: (PresetItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            DashedDivider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedKeys, id: \.self) { category in
                        section(for: category)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            PixelText("🔍", size: 14, color: TrackrColors.fg2, tracking: 0)
            TextField("Search library", text: $searchQuery)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var filtered: [PresetItem] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0.name.lowercased().contains(q) }
    }

    private var grouped: [Category: [PresetItem]] {
        Dictionary(grouping: filtered, by: \.category)
    }

    private var groupedKeys: [Category] {
        Category.allCases.filter { grouped[$0] != nil }
    }

    @ViewBuilder
    private func section(for category: Category) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PixelText(category.displayName.uppercased(),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            ForEach(grouped[category] ?? [], id: \.id) { item in
                Button { onSelect(item) } label: { row(item) }
                .buttonStyle(.plain)
                DashedDivider()
            }
        }
    }

    @ViewBuilder
    private func row(_ item: PresetItem) -> some View {
        HStack(spacing: 12) {
            MonoSquareIcon(name: item.name)
            VStack(alignment: .leading, spacing: 2) {
                PixelText(item.name.uppercased(),
                          size: TrackrTypography.Scale.value, tracking: 1.5)
                PixelText(item.defaultPlanName.uppercased(),
                          size: TrackrTypography.Scale.sectionLabel,
                          color: TrackrColors.fg2, tracking: 1.5)
            }
            Spacer()
            PixelText(AmountFormatter.format(item.defaultAmount,
                                              currency: item.defaultCurrency),
                      size: TrackrTypography.Scale.value, tracking: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
```

- [ ] **Step 4: Build + record snapshots twice**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/PresetLibraryViewSnapshotTests 2>&1 | tail -5
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/PresetLibraryViewSnapshotTests 2>&1 | tail -5
```

Second run: 2 tests pass.

- [ ] **Step 5: Confirm baselines + full suite**

```bash
ls TrackrTests/__Snapshots__/PresetLibraryView_Snapshot_Tests/ 2>/dev/null
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 153 + 2 = 155 tests; 2 baseline PNGs.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/AddSubscription/PresetLibraryView.swift \
        TrackrTests/PresetLibraryView_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/PresetLibraryView_Snapshot_Tests
git commit -m "feat(presets): add PresetLibraryView with search and category grouping"
```

---

### Task 8: AddSubscriptionSheet — `CUSTOM | LIBRARY` segmented picker

**Files:**
- Modify: `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift`
- Modify: `TrackrTests/AddSubscriptionSheet_Snapshot_Tests.swift` (delete stale baselines so they re-record)
- Create: `TrackrTests/AddSubscriptionSheet_TabSwitch_Tests.swift`

The sheet grows a `selectedTab` state and renders either the existing form (CUSTOM) or `PresetLibraryView` (LIBRARY). Tapping a preset row populates `draft`, stamps `pendingPresetId` so the `submit` path can write it onto the resulting `Subscription`, and flips the tab back to CUSTOM. The user sees the form pre-filled and can SAVE as usual.

- [ ] **Step 1: Write the failing tab-switch tests**

Create `TrackrTests/AddSubscriptionSheet_TabSwitch_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class AddSubscriptionSheetTabSwitchTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_submitFromPreset_stampsPresetIdOnSubscription() async throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Netflix"
        draft.amountString = "15.49"

        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: "netflix.standard",
            context: container.mainContext,
            coordinator: nil,
            onDismiss: {}
        )
        XCTAssertNil(result)

        let saved = try SubscriptionRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(saved.first?.presetId, "netflix.standard")
    }

    func test_submitWithoutPreset_leavesPresetIdNil() async throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Manual"
        draft.amountString = "5"

        _ = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: nil,
            context: container.mainContext,
            coordinator: nil,
            onDismiss: {}
        )
        let saved = try SubscriptionRepository(context: container.mainContext).fetchAll()
        XCTAssertNil(saved.first?.presetId)
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `submit` doesn't accept `presetId` yet — compile error.

- [ ] **Step 3: Update `AddSubscriptionSheet.swift`**

Open `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift`. Apply these targeted edits:

(a) Add a `Tab` enum and a `selectedTab` state, plus a `pendingPresetId` state, alongside the existing `@State` properties:
```swift
    private enum Tab: Hashable { case custom, library }
    @State private var selectedTab: Tab = .custom
    @State private var pendingPresetId: String?
    @State private var presetItems: [PresetItem] = []
    @State private var presetSearch: String = ""
```

(b) At the top of `body`, before the existing `header`, replace the outer `VStack` with one that has the tab picker as its first child:
```swift
    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                tabPicker
                Divider().background(TrackrColors.border)
                ScrollView {
                    Group {
                        if selectedTab == .custom {
                            customForm
                        } else {
                            PresetLibraryView(items: presetItems,
                                              searchQuery: $presetSearch,
                                              onSelect: selectPreset)
                        }
                    }
                    .padding(selectedTab == .custom ? 20 : 0)
                }
                if selectedTab == .custom { footer }
            }
        }
        .onAppear {
            guard !hasResolvedDefaultCurrency else { return }
            hasResolvedDefaultCurrency = true
            if draft.currency.isEmpty {
                draft = SubscriptionDraft.empty(
                    defaultCurrency: (try? SettingsRepository(context: context).currentSettings().defaultCurrency) ?? "USD"
                )
            }
            if presetItems.isEmpty {
                presetItems = (try? PresetBundleLoader.loadBundled().items) ?? []
            }
        }
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text("CUSTOM").tag(Tab.custom)
            Text("LIBRARY").tag(Tab.library)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var customForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            nameField
            amountAndCurrency
            cycleField
            startDateField
            categoryField
            planNameField
            notesField
            urlField
            if let errorMessage {
                PixelText(errorMessage.uppercased(),
                          size: TrackrTypography.Scale.caption,
                          color: TrackrColors.warn,
                          tracking: 1.5)
            }
        }
    }

    private func selectPreset(_ item: PresetItem) {
        draft = item.toDraft(defaultStart: draft.startDate)
        pendingPresetId = item.id
        selectedTab = .custom
    }
```

(c) Replace `attemptSave` to forward the `pendingPresetId`:
```swift
    private func attemptSave() {
        Task {
            if let msg = await Self.submit(draft: draft,
                                            presetId: pendingPresetId,
                                            context: context,
                                            coordinator: coordinator,
                                            onDismiss: { dismiss() }) {
                errorMessage = msg
            } else {
                errorMessage = nil
            }
        }
    }
```

(d) Replace the existing static `submit(draft:context:coordinator:onDismiss:)` with the new signature that takes an optional `presetId`:
```swift
    @discardableResult
    static func submit(draft: SubscriptionDraft,
                       presetId: String? = nil,
                       context: ModelContext,
                       coordinator: NotificationCoordinator? = nil,
                       onDismiss: () -> Void) async -> String? {
        do {
            let sub = try draft.makeSubscription()
            if let presetId { sub.presetId = presetId }
            try SubscriptionRepository(context: context).insert(sub)
            if let coordinator {
                try? await coordinator.refresh()
            }
            onDismiss()
            return nil
        } catch SubscriptionDraft.ValidationError.emptyName {
            return "Name is required"
        } catch SubscriptionDraft.ValidationError.invalidAmount {
            return "Enter a valid amount"
        } catch SubscriptionDraft.ValidationError.invalidCustomDays {
            return "Custom cycle days must be > 0"
        } catch {
            return "Could not save: \(error.localizedDescription)"
        }
    }
```

- [ ] **Step 4: Update the existing M3/M4 tests for `submit`**

In `TrackrTests/AddSubscriptionSheet_Submit_Tests.swift` and `TrackrTests/NotificationWriteHooks_Tests.swift`, every call to `AddSubscriptionSheet.submit(...)` uses keyword arguments. Insert `presetId: nil,` between `draft:` and `context:` at each call site.

- [ ] **Step 5: Re-record the existing AddSubscriptionSheet snapshots**

```bash
rm TrackrTests/__Snapshots__/AddSubscriptionSheet_Snapshot_Tests/*.png
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/AddSubscriptionSheetSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/AddSubscriptionSheetSnapshotTests 2>&1 | tail -3
```

Second run: 2 tests pass with the new baseline (form now starts with the CUSTOM | LIBRARY picker on top).

- [ ] **Step 6: Run full suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 155 + 2 = 157 tests, **TEST SUCCEEDED**.

- [ ] **Step 7: Commit**

```bash
git add Trackr/Features/AddSubscription/AddSubscriptionSheet.swift \
        TrackrTests/AddSubscriptionSheet_TabSwitch_Tests.swift \
        TrackrTests/AddSubscriptionSheet_Submit_Tests.swift \
        TrackrTests/NotificationWriteHooks_Tests.swift \
        TrackrTests/__Snapshots__/AddSubscriptionSheet_Snapshot_Tests
git commit -m "feat(presets): add CUSTOM/LIBRARY tab picker to Add Subscription sheet"
```

---

### Task 9: `PriceChangeBanner` + Detail integration

**Files:**
- Create: `Trackr/Features/Detail/PriceChangeBanner.swift`
- Create: `TrackrTests/PriceChangeBanner_Snapshot_Tests.swift`
- Modify: `Trackr/Features/Detail/SubscriptionDetailView.swift`
- Modify: `TrackrTests/SubscriptionDetailView_Snapshot_Tests.swift` (delete stale baselines)

The banner sits above the read body when there's an unseen alert. Tapping it calls `AlertRepository.markSeen` and the banner disappears.

- [ ] **Step 1: Implement the banner component (snapshot test first)**

Create `TrackrTests/PriceChangeBanner_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class PriceChangeBannerSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    func test_priceIncrease_render() {
        let banner = PriceChangeBanner(
            message: "Netflix raised its Standard price from $15.49 to $17.99.",
            onDismiss: {}
        )
        .frame(width: 360, height: 80)
        .preferredColorScheme(.dark)
        assertSnapshot(of: banner, as: .image)
    }
}
```

Create `Trackr/Features/Detail/PriceChangeBanner.swift`:
```swift
import SwiftUI

/// Inline price-change notification shown at the top of the Detail screen
/// when the displayed subscription has an unseen `PriceChangeAlert`.
struct PriceChangeBanner: View {

    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle().fill(TrackrColors.warn).frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                PixelText("PRICE CHANGE",
                          size: TrackrTypography.Scale.sectionLabel,
                          color: TrackrColors.warn,
                          tracking: 2)
                Text(message)
                    .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                    .foregroundStyle(TrackrColors.fg)
            }
            Spacer()
            Button(action: onDismiss) {
                PixelText("✕",
                          size: TrackrTypography.Scale.value,
                          color: TrackrColors.fg2,
                          tracking: 0)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .overlay(Rectangle().stroke(TrackrColors.warn.opacity(0.4), lineWidth: 1))
    }
}
```

Run the banner snapshot test twice to record + verify:
```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/PriceChangeBannerSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/PriceChangeBannerSnapshotTests 2>&1 | tail -3
```

Second run: 1 test passes.

- [ ] **Step 2: Wire the banner into `SubscriptionDetailView`**

In `Trackr/Features/Detail/SubscriptionDetailView.swift`, add a computed property near the other helpers:

```swift
    private var unseenAlert: PriceChangeAlert? {
        guard let presetId = subscription.presetId else { return nil }
        return try? AlertRepository(context: context)
            .fetch(forPresetId: presetId)
            .first(where: { $0.seenAt == nil })
    }
```

Then at the top of `readingBody` (just before `heroAmount`), insert:

```swift
            if let alert = unseenAlert {
                PriceChangeBanner(message: alert.messageEn) {
                    try? AlertRepository(context: context).markSeen(alert)
                }
            }
```

When `markSeen` writes through to SwiftData, the parent `@Query` observers re-render `Detail`, `unseenAlert` returns `nil`, and the banner disappears. No extra `@State` needed.

- [ ] **Step 3: Update the SubscriptionDetailView snapshot tests**

In `TrackrTests/SubscriptionDetailView_Snapshot_Tests.swift`, add a third snapshot case that seeds an unseen alert and verifies the banner appears:

```swift
    func test_priceChangeBanner_render() throws {
        let sub = Subscription(
            name: "Netflix",
            planName: "Standard",
            amount: 17.99,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .media,
            presetId: "netflix.standard"
        )
        container.mainContext.insert(sub)
        let alert = PriceChangeAlert(
            presetId: "netflix.standard",
            planKey: "Standard",
            oldAmount: 15.49,
            newAmount: 17.99,
            currency: "USD",
            effectiveDate: Date(timeIntervalSince1970: 1_750_000_000),
            messageEn: "Netflix raised its Standard price from $15.49 to $17.99.",
            messageZh: "Netflix Standard 价格已上调，由 $15.49 变为 $17.99。"
        )
        container.mainContext.insert(alert)
        try container.mainContext.save()

        let host = SubscriptionDetailView(subscription: sub)
            .modelContainer(container)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: host, as: .image)
    }
```

The existing two `test_active_render` / `test_paused_render` baselines stay valid because their subs have no `presetId` — the banner is invisible.

- [ ] **Step 4: Build + record the new banner-on-detail snapshot twice**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SubscriptionDetailViewSnapshotTests/test_priceChangeBanner_render 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SubscriptionDetailViewSnapshotTests/test_priceChangeBanner_render 2>&1 | tail -3
```

Second run: passes.

- [ ] **Step 5: Run full suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 157 + 1 + 1 = 159 tests, **TEST SUCCEEDED**.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Detail/PriceChangeBanner.swift \
        Trackr/Features/Detail/SubscriptionDetailView.swift \
        TrackrTests/PriceChangeBanner_Snapshot_Tests.swift \
        TrackrTests/SubscriptionDetailView_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/PriceChangeBanner_Snapshot_Tests \
        TrackrTests/__Snapshots__/SubscriptionDetailView_Snapshot_Tests
git commit -m "feat(presets): add PriceChangeBanner and surface unseen alerts on Detail"
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

Expected: 159 tests, **TEST SUCCEEDED**.

- [ ] **Step 3: Manual smoke run in the simulator**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
xcrun simctl boot 'iPhone 16' 2>/dev/null || true
xcrun simctl uninstall booted com.placeholder.trackr 2>/dev/null || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.placeholder.trackr
sleep 2
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m5-home.png
```

Then in the simulator, by hand:
1. Tap FAB → Add Subscription sheet opens with CUSTOM | LIBRARY picker at the top.
2. Tap LIBRARY. Search list of 8 seed items grouped by category renders. Type "net" — list narrows to Netflix only.
3. Tap Netflix. Tab snaps back to CUSTOM with name/amount/category prefilled to "Netflix / 15.49 / media".
4. Tap SAVE. Home shows the new sub.
5. Tap the row to open Detail. No banner (no alert yet).
6. Optional: drop into the SwiftData store (or use the in-memory simulator hack of relaunching with `PRESET_BUMP_FOR_DEMO=1` ENV) to inject a PriceChangeAlert. M5 doesn't ship a debug toggle; the banner-on-detail snapshot test (Task 9) is the authoritative acceptance for "banner renders when alert exists".

Take a final screenshot:
```bash
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m5-library.png
```

- [ ] **Step 4: Tag**

```bash
git tag m5-presets
git tag --list 'm*'
git show m5-presets --stat --no-patch
```

Expected tags: `m1-foundation`, `m2-data`, `m3-crud-ui`, `m4-notifications`, `m5-presets`.

- [ ] **Step 5: Acceptance inventory**

```bash
echo '=== M5 new core files ==='
git ls-files Trackr/Core/Presets Trackr/Resources
echo
echo '=== M5 new feature files ==='
git diff --name-only m4-notifications HEAD -- Trackr/Features
echo
echo '=== Test files added since m4-notifications ==='
git diff --name-only m4-notifications HEAD -- TrackrTests | sort
echo
echo '=== Commit count m4-notifications..HEAD ==='
git rev-list m4-notifications..HEAD --count
```

---

## M5 Acceptance Summary

- 6 pure-logic types under `Trackr/Core/Presets/` carry the catalog pipeline: `PresetItem`, `PresetCatalog`, `PresetBundleLoader`, `PresetFetcher` (protocol + URLSession impl + `FakePresetFetcher`), `PriceChangeDiffer`, `PresetSync`. All TDD'd.
- `presets.bundled.json` ships 8 seed items across 5 categories.
- LIBRARY tab in Add Subscription sheet: searchable, category-grouped, taps pre-fill the existing form and stamp `presetId` on save.
- Detail screen surfaces unseen `PriceChangeAlert` rows via a `PriceChangeBanner`; tapping ✕ marks the alert seen via `AlertRepository`.
- `PresetSync` runs once on `HomeView.task`; production URL is intentionally unreachable until M9, so the bundled seed drives LIBRARY.
- Net new tests: 25 (5 PresetItem + 2 PresetCatalog + 2 PresetBundleLoader + 1 PresetFetcher + 6 PriceChangeDiffer + 3 PresetSync + 2 PresetLibraryView snapshot + 2 AddSubscriptionSheet tab-switch + 1 PriceChangeBanner snapshot + 1 Detail banner snapshot). Total: **159 tests, 0 failures**.
- `git tag m5-presets` set. Ready to scope M6 (IAP / paywall / free-vs-Pro gating).
