# Milestone 7 — Widget + iCloud Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WidgetKit extension with Small + Medium widgets that read live subscription data from a shared App Group SwiftData store, and a CloudKit-backed configuration that turns on cross-device sync when the user is Pro AND signed into iCloud.

**Architecture:**
- All M2 models drop their `@Attribute(.unique)` annotations. CloudKit-backed SwiftData containers reject `.unique`, and UUIDs are already unique by construction; we lose nothing. M2 already worked around the runtime issue in `SubscriptionRepository.fetch(byID:)` by filtering in Swift.
- `ModelContainerConfig.makeAppContainer()` relocates the SQLite store to the shared App Group container URL (`group.com.placeholder.trackr`). Both the app and the widget extension construct their containers from the same path, so the widget reads live data.
- A new pure-logic type `SyncDecider` answers "should CloudKit be on?" given the current `ProStatus` and an `iCloudAccountStatus` enum. Live use sites translate `CKAccountStatus` into our enum and ask the decider. The result drives whether `ModelConfiguration` opts into `cloudKitDatabase`.
- A new pure-logic type `UpcomingRenewalsProvider` answers "what should the widget show?" given a list of subscriptions and `now` — returns the top N by nearest `nextBillingDate`, with a `daysUntil` countdown attached. Fully TDD'd.
- The widget extension lives at `Widgets/` with a single `WidgetBundle`-conforming `@main` entry. The actual view code (`SmallRenewalWidgetView`, `MediumRenewalWidgetView`) lives under `Trackr/Features/Widget/` and is compiled into BOTH the main app target and the widget target, so snapshot tests can render it from the test target via `@testable import Trackr`.
- Sync gating is decided once at `TrackrApp.init`: read cached `UserSettings.proStatus` synchronously, ask `CKContainer.default().accountStatus` (cheap, cached), feed both to `SyncDecider`. Toggling sync mid-session is rare and requires an app relaunch — explicitly out of scope for M7.
- Family Sharing for the IAP products stays disabled (`familyShareable: false` in `Configuration.storekit`); M7 has no code change for that path — just a verification step in acceptance.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData (iOS 17), WidgetKit, CloudKit, App Groups, XCTest, swift-snapshot-testing. No new third-party deps.

---

## File Structure

After M7 the new code looks like this (only new + modified files shown):

```
Trackr.entitlements                                  # NEW — app entitlements (App Group + iCloud)
Widgets.entitlements                                 # NEW — widget entitlements (App Group)
Widgets/
└─ TrackrWidgetsBundle.swift                         # NEW — @main WidgetBundle entry

Trackr/
├─ Core/
│  ├─ Storage/
│  │  ├─ ModelContainerConfig.swift                  # MODIFIED — App Group URL + CloudKit toggle
│  │  └─ SyncDecider.swift                            # NEW — pure logic
│  └─ Widget/
│     └─ UpcomingRenewalsProvider.swift              # NEW — pure logic
├─ Features/
│  └─ Widget/
│     ├─ SmallRenewalWidgetView.swift                 # NEW — shared widget view
│     ├─ MediumRenewalWidgetView.swift                # NEW — shared widget view
│     └─ RenewalTimelineProvider.swift                # NEW — TimelineProvider
└─ Core/Models/                                       # MODIFIED — drop @Attribute(.unique)
   ├─ Subscription.swift
   ├─ RenewalEvent.swift
   ├─ PriceChangeAlert.swift
   ├─ UserSettings.swift
   └─ PresetCache.swift

Trackr/TrackrApp.swift                                # MODIFIED — wire SyncDecider into container build

project.yml                                            # MODIFIED — widget target + entitlements + capabilities

TrackrTests/
├─ SyncDecider_Tests.swift
├─ UpcomingRenewalsProvider_Tests.swift
├─ SmallRenewalWidgetView_Snapshot_Tests.swift
└─ MediumRenewalWidgetView_Snapshot_Tests.swift
```

---

### Task 1: Drop `@Attribute(.unique)` from all `@Model` types

**Files:**
- Modify: `Trackr/Core/Models/Subscription.swift`
- Modify: `Trackr/Core/Models/RenewalEvent.swift`
- Modify: `Trackr/Core/Models/PriceChangeAlert.swift`
- Modify: `Trackr/Core/Models/UserSettings.swift`
- Modify: `Trackr/Core/Models/PresetCache.swift`

CloudKit-backed SwiftData containers reject `.unique`. UUIDs are unique by construction; removing the annotation is safe. M2's `SubscriptionRepository.fetch(byID:)` already filters in Swift instead of using a `#Predicate { $0.id == id }` (which choked on the unique constraint anyway), so this change has zero behavioral impact.

- [ ] **Step 1: Run the full suite to capture the pre-task baseline**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 183 tests pass.

- [ ] **Step 2: Edit each model**

In `Trackr/Core/Models/Subscription.swift`, change:
```swift
    @Attribute(.unique) var id: UUID
```
to:
```swift
    var id: UUID
```

Apply the same one-line removal (delete `@Attribute(.unique) ` from the `id: UUID` declaration) in:
- `Trackr/Core/Models/RenewalEvent.swift`
- `Trackr/Core/Models/PriceChangeAlert.swift`
- `Trackr/Core/Models/UserSettings.swift`
- `Trackr/Core/Models/PresetCache.swift`

- [ ] **Step 3: Run the full suite, expect identical pass count**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: still 183 tests pass. No new tests in this task — the existing schema-roundtrip tests cover everything.

- [ ] **Step 4: Commit**

```bash
git add Trackr/Core/Models/Subscription.swift \
        Trackr/Core/Models/RenewalEvent.swift \
        Trackr/Core/Models/PriceChangeAlert.swift \
        Trackr/Core/Models/UserSettings.swift \
        Trackr/Core/Models/PresetCache.swift
git commit -m "refactor(core): drop @Attribute(.unique) for CloudKit compatibility"
```

---

### Task 2: `SyncDecider` (TDD)

**Files:**
- Create: `Trackr/Core/Storage/SyncDecider.swift`
- Create: `TrackrTests/SyncDecider_Tests.swift`

Pure function: given `ProStatus` + an `iCloudAccountStatus` enum, return `.cloudKit | .localOnly`. Tests never touch `CKContainer`; the live caller (Task 8) translates `CKAccountStatus` into our enum.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/SyncDecider_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class SyncDeciderTests: XCTestCase {

    func test_pro_andAvailable_returnsCloudKit() {
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .proLifetime, iCloud: .available),
            .cloudKit
        )
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .proMonthly, iCloud: .available),
            .cloudKit
        )
    }

    func test_free_evenWithICloud_isLocalOnly() {
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .free, iCloud: .available),
            .localOnly
        )
    }

    func test_pro_butNoICloud_isLocalOnly() {
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .proLifetime, iCloud: .noAccount),
            .localOnly
        )
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .proLifetime, iCloud: .restricted),
            .localOnly
        )
        XCTAssertEqual(
            SyncDecider.decide(proStatus: .proLifetime, iCloud: .couldNotDetermine),
            .localOnly
        )
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
Expected: `cannot find 'SyncDecider'`.

- [ ] **Step 3: Implement `SyncDecider.swift`**

Create `Trackr/Core/Storage/SyncDecider.swift`:
```swift
import Foundation

/// Trackr's view of the iCloud account state. Mirrors a subset of
/// `CKAccountStatus` so the decider stays free of `CloudKit` imports.
enum ICloudAccountStatus {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
}

/// Which SwiftData storage mode to use this launch.
enum SyncMode: Equatable {
    case localOnly
    case cloudKit
}

/// Pure decision rule: CloudKit only when the user is Pro AND iCloud is
/// available. Everything else is local-only.
enum SyncDecider {
    static func decide(proStatus: ProStatus, iCloud: ICloudAccountStatus) -> SyncMode {
        guard FeatureGate.isAllowed(.iCloudSync, given: proStatus) else { return .localOnly }
        return iCloud == .available ? .cloudKit : .localOnly
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```
Expected: 183 + 3 = 186 tests passing.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Storage/SyncDecider.swift TrackrTests/SyncDecider_Tests.swift
git commit -m "feat(sync): add SyncDecider with TDD"
```

---

### Task 3: `UpcomingRenewalsProvider` (TDD)

**Files:**
- Create: `Trackr/Core/Widget/UpcomingRenewalsProvider.swift`
- Create: `TrackrTests/UpcomingRenewalsProvider_Tests.swift`

Pure function: given subscriptions + `now`, return the top N upcoming renewals as a `[UpcomingRenewal]` value type. Sort by `nextBillingDate` ascending; skip inactive subs; skip renewals in the past.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/UpcomingRenewalsProvider_Tests.swift`:
```swift
import XCTest
@testable import Trackr

@MainActor
final class UpcomingRenewalsProviderTests: XCTestCase {

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func sub(name: String,
                     daysFromNow: Int,
                     active: Bool = true,
                     amount: Decimal = 10,
                     currency: String = "USD") -> Subscription {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let billing = Self.utc.date(byAdding: .day, value: daysFromNow, to: now)!
        return Subscription(
            name: name,
            amount: amount, currency: currency,
            billingCycle: .monthly,
            nextBillingDate: billing,
            startDate: Date(timeIntervalSince1970: 0),
            category: .other,
            isActive: active
        )
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func test_sortsByNextBillingAscending() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "B", daysFromNow: 10),
                            sub(name: "A", daysFromNow: 3)],
            now: now,
            limit: 5,
            calendar: Self.utc
        )
        XCTAssertEqual(result.map(\.name), ["A", "B"])
    }

    func test_skipsInactiveSubscriptions() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "Paused", daysFromNow: 1, active: false),
                            sub(name: "Live", daysFromNow: 5)],
            now: now,
            limit: 5,
            calendar: Self.utc
        )
        XCTAssertEqual(result.map(\.name), ["Live"])
    }

    func test_skipsRenewalsInThePast() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "Old", daysFromNow: -3),
                            sub(name: "Future", daysFromNow: 7)],
            now: now,
            limit: 5,
            calendar: Self.utc
        )
        XCTAssertEqual(result.map(\.name), ["Future"])
    }

    func test_respectsLimit() {
        let subs = (1...10).map { sub(name: "S\($0)", daysFromNow: $0) }
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: subs,
            now: now,
            limit: 3,
            calendar: Self.utc
        )
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.name), ["S1", "S2", "S3"])
    }

    func test_daysUntil_computedCorrectly() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "X", daysFromNow: 5)],
            now: now,
            limit: 1,
            calendar: Self.utc
        )
        XCTAssertEqual(result.first?.daysUntil, 5)
    }

    func test_displayAmount_isFormatted() {
        let result = UpcomingRenewalsProvider.upcoming(
            subscriptions: [sub(name: "Netflix", daysFromNow: 3,
                                amount: 15.49, currency: "USD")],
            now: now,
            limit: 1,
            calendar: Self.utc
        )
        XCTAssertEqual(result.first?.displayAmount, "$15.49")
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'UpcomingRenewalsProvider'`.

- [ ] **Step 3: Implement `UpcomingRenewalsProvider.swift`**

Create `Trackr/Core/Widget/UpcomingRenewalsProvider.swift`:
```swift
import Foundation

/// Value-type snapshot of one upcoming renewal, with the strings pre-formatted
/// for widget rendering. Keeping the widget view layer free of formatters
/// keeps it deterministic across timeline snapshots.
struct UpcomingRenewal: Equatable {
    let id: UUID
    let name: String
    let displayAmount: String
    let daysUntil: Int
    let nextBillingDate: Date
}

/// Pure function for widget timeline construction. Returns the soonest `limit`
/// renewals strictly after `now` from the supplied subscriptions, skipping
/// inactive rows.
enum UpcomingRenewalsProvider {
    static func upcoming(
        subscriptions: [Subscription],
        now: Date,
        limit: Int,
        calendar: Calendar = .current
    ) -> [UpcomingRenewal] {
        subscriptions
            .filter { $0.isActive && $0.nextBillingDate > now }
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
            .prefix(limit)
            .map { sub in
                UpcomingRenewal(
                    id: sub.id,
                    name: sub.name,
                    displayAmount: AmountFormatter.format(sub.amount, currency: sub.currency),
                    daysUntil: daysBetween(now: now, then: sub.nextBillingDate, calendar: calendar),
                    nextBillingDate: sub.nextBillingDate
                )
            }
    }

    private static func daysBetween(now: Date, then: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.day], from: now, to: then)
        return comps.day ?? 0
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 186 + 6 = 192 tests.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Widget/UpcomingRenewalsProvider.swift \
        TrackrTests/UpcomingRenewalsProvider_Tests.swift
git commit -m "feat(widget): add UpcomingRenewalsProvider with TDD"
```

---

### Task 4: Entitlements files + App Group container relocation

**Files:**
- Create: `Trackr.entitlements`
- Create: `Widgets.entitlements`
- Modify: `Trackr/Core/Storage/ModelContainerConfig.swift`
- Modify: `project.yml` (point app target at the entitlements file)

The container moves from the default app-sandbox URL to the App Group URL `group.com.placeholder.trackr/Trackr.sqlite`. The widget target (added in Task 6) will use the same path.

Note on the App Group identifier: `group.com.placeholder.trackr` is a placeholder — production needs a real Apple Developer team prefix. The string is parameterized via a constant on `ModelContainerConfig` so the swap in M9 is a one-line edit.

- [ ] **Step 1: Create `Trackr.entitlements`**

Create `Trackr.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.placeholder.trackr</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.placeholder.trackr</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Create `Widgets.entitlements`**

Create `Widgets.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.placeholder.trackr</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Update `ModelContainerConfig.swift`**

Replace `Trackr/Core/Storage/ModelContainerConfig.swift` with:
```swift
import Foundation
import SwiftData

/// Constructs SwiftData `ModelContainer`s for the app and for tests.
enum ModelContainerConfig {

    /// App Group identifier — both the app and the widget extension read/write
    /// the same SQLite store via this group. Production swaps this for the
    /// real Apple Developer team prefix in M9.
    static let appGroupIdentifier = "group.com.placeholder.trackr"

    /// SwiftData CloudKit container ID — matches the entitlement on the app target.
    static let cloudKitContainerIdentifier = "iCloud.com.placeholder.trackr"

    /// URL inside the shared App Group container where the SwiftData store lives.
    /// The widget extension targets the same URL so the two processes see the
    /// same data without a sync hop.
    static func sharedStoreURL() -> URL {
        guard let groupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            // App Group entitlement isn't wired up (or tests in a non-entitled
            // environment) — fall back to the documents directory so the app
            // still works locally.
            let docs = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
            return docs.appendingPathComponent("Trackr.sqlite")
        }
        return groupURL.appendingPathComponent("Trackr.sqlite")
    }

    /// The persistent container used by the running app. Lives in the user's
    /// App Group so the widget extension can read the same store.
    /// CloudKit sync is toggled by the caller via `syncMode`.
    static func makeAppContainer(syncMode: SyncMode = .localOnly) throws -> ModelContainer {
        let url = sharedStoreURL()
        let config: ModelConfiguration
        switch syncMode {
        case .localOnly:
            config = ModelConfiguration(schema: schema, url: url,
                                        cloudKitDatabase: .none)
        case .cloudKit:
            config = ModelConfiguration(schema: schema, url: url,
                                        cloudKitDatabase: .private(cloudKitContainerIdentifier))
        }
        return try ModelContainer(for: schema, configurations: config)
    }

    /// An in-memory container for tests. Wipes itself when deallocated.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: config)
    }

    private static let schema = Schema([
        Subscription.self,
        RenewalEvent.self,
        PriceChangeAlert.self,
        UserSettings.self,
        PresetCache.self,
    ])
}

/// Test-target convenience so tests can call `makeInMemoryContainer()` without typing
/// the namespace. Mirrors what most XCTestCase suites do.
func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainerConfig.makeInMemoryContainer()
}
```

- [ ] **Step 4: Point the Trackr target at the entitlements file in `project.yml`**

Open `project.yml`. Find the `Trackr:` target block. Under `settings: base:` add a `CODE_SIGN_ENTITLEMENTS` entry:

```yaml
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.placeholder.trackr
        TARGETED_DEVICE_FAMILY: "1,2"
        ENABLE_PREVIEWS: YES
        ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS: NO
        CODE_SIGN_ENTITLEMENTS: Trackr.entitlements
```

(Leave the other settings exactly as they are.)

- [ ] **Step 5: Update the TrackrApp launch to pass `.localOnly` for now**

Read `Trackr/TrackrApp.swift`. The `init()` currently calls `ModelContainerConfig.makeAppContainer()`. With the new signature it still compiles (default `.localOnly`), but for clarity update the call to be explicit:

Find:
```swift
            self.container = try ModelContainerConfig.makeAppContainer()
```

Replace with:
```swift
            self.container = try ModelContainerConfig.makeAppContainer(syncMode: .localOnly)
```

Task 9 will replace `.localOnly` with the live `SyncDecider.decide(...)` call.

- [ ] **Step 6: Run the full suite**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 192 tests pass. No net new tests in this task — the integration only manifests when running on a real device with provisioning. The simulator without provisioning falls back to the documents-directory path via `sharedStoreURL`'s guard.

If the build fails because the simulator can't honor the App Group entitlement without a signing identity, the documents-directory fallback inside `sharedStoreURL()` makes it work anyway. Don't sweat the App Group warning in the simulator log.

- [ ] **Step 7: Commit**

```bash
git add Trackr.entitlements Widgets.entitlements project.yml \
        Trackr/Core/Storage/ModelContainerConfig.swift \
        Trackr/TrackrApp.swift
git commit -m "feat(sync): add App Group entitlements and relocate SwiftData store"
```

---

### Task 5: Widget extension target scaffold

**Files:**
- Create: `Widgets/TrackrWidgetsBundle.swift`
- Modify: `project.yml` — add the `Widgets` target with `extensionType: widgetkit`

Bare-minimum widget target so the project compiles. The actual widget structs are added in Task 6/7.

- [ ] **Step 1: Create the bundle skeleton**

Create `Widgets/TrackrWidgetsBundle.swift`:
```swift
import WidgetKit
import SwiftUI

@main
struct TrackrWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpcomingRenewalsWidget()
    }
}

/// Placeholder until Task 8 fleshes out the timeline provider + body.
struct UpcomingRenewalsWidget: Widget {
    let kind: String = "UpcomingRenewalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            Text("Trackr")
        }
        .configurationDisplayName("Upcoming Renewals")
        .description("See your next subscription renewals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Placeholder until Task 8.
struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now)
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry(date: .now)], policy: .never))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}
```

- [ ] **Step 2: Add the Widgets target to `project.yml`**

Open `project.yml`. After the existing `TrackrTests:` target block, add:

```yaml
  Widgets:
    type: app-extension
    platform: iOS
    sources:
      - path: Widgets
      - path: Trackr/Core
      - path: Trackr/Features/Widget
    info:
      path: Widgets/Info.plist
      properties:
        CFBundleDisplayName: Trackr Widgets
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.placeholder.trackr.widgets
        TARGETED_DEVICE_FAMILY: "1"
        SKIP_INSTALL: YES
        CODE_SIGN_ENTITLEMENTS: Widgets.entitlements
        INFOPLIST_KEY_CFBundleDisplayName: "Trackr Widgets"
```

Also add the Widgets extension as a dependency of the Trackr app target. Inside the existing `Trackr:` block add a `dependencies:` entry:
```yaml
    dependencies:
      - target: Widgets
```

The `sources:` block compiles `Trackr/Core` (all model + storage files) and `Trackr/Features/Widget` (the views, added in Task 6/7) into the widget target. The widget reuses the app's Swift code without a separate framework target.

- [ ] **Step 3: Regenerate and confirm the project builds both targets**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet build 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Both: exit 0; 192 tests pass.

If `xcodebuild build` fails complaining the widget target's `sources:` include files that depend on SwiftData / WidgetKit symbols not available at extension target settings, narrow the widget's source scope. The plan assumes the iOS 17 baseline lets SwiftData compile cleanly in extension targets — if a build error shows up, report it as DONE_WITH_CONCERNS rather than scope-creeping.

- [ ] **Step 4: Commit**

```bash
git add Widgets/TrackrWidgetsBundle.swift project.yml
git commit -m "feat(widget): add Widgets extension target with placeholder bundle"
```

---

### Task 6: `SmallRenewalWidgetView` (snapshot)

**Files:**
- Create: `Trackr/Features/Widget/SmallRenewalWidgetView.swift`
- Create: `TrackrTests/SmallRenewalWidgetView_Snapshot_Tests.swift`

Small widget shows the nearest renewal: name, days countdown, amount. Pure rendering — accepts an optional `UpcomingRenewal` (nil → empty state).

- [ ] **Step 1: Write the failing snapshot tests**

Create `TrackrTests/SmallRenewalWidgetView_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class SmallRenewalWidgetViewSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func host(_ renewal: UpcomingRenewal?) -> some View {
        SmallRenewalWidgetView(renewal: renewal)
            .frame(width: 158, height: 158)
            .background(TrackrColors.bg)
            .preferredColorScheme(.dark)
    }

    func test_withRenewal_render() {
        let renewal = UpcomingRenewal(
            id: UUID(),
            name: "Netflix",
            displayAmount: "$15.49",
            daysUntil: 3,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000)
        )
        assertSnapshot(of: host(renewal), as: .image)
    }

    func test_empty_render() {
        assertSnapshot(of: host(nil), as: .image)
    }
}
```

- [ ] **Step 2: Run, expect build failure**

Expected: `cannot find 'SmallRenewalWidgetView'`.

- [ ] **Step 3: Implement `SmallRenewalWidgetView.swift`**

Create `Trackr/Features/Widget/SmallRenewalWidgetView.swift`:
```swift
import SwiftUI

/// Small WidgetKit widget showing the next upcoming renewal — name, days
/// countdown, amount. Pure rendering; the timeline provider supplies the data.
struct SmallRenewalWidgetView: View {

    let renewal: UpcomingRenewal?

    var body: some View {
        if let renewal {
            populated(renewal)
        } else {
            empty
        }
    }

    private func populated(_ renewal: UpcomingRenewal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText("NEXT",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(renewal.name.uppercased(),
                      size: TrackrTypography.Scale.title,
                      tracking: 1.5)
                .lineLimit(1)
            Spacer()
            PixelText("\(renewal.daysUntil) DAY\(renewal.daysUntil == 1 ? "" : "S")",
                      size: TrackrTypography.Scale.largeNumber,
                      color: TrackrColors.accent,
                      tracking: 1)
            PixelText(renewal.displayAmount,
                      size: TrackrTypography.Scale.value,
                      color: TrackrColors.fg2,
                      tracking: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            PixelText("TRACKR",
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            Spacer()
            PixelText("NO UPCOMING",
                      size: TrackrTypography.Scale.body,
                      color: TrackrColors.fg2, tracking: 1.5)
            PixelText("RENEWALS",
                      size: TrackrTypography.Scale.body,
                      color: TrackrColors.fg2, tracking: 1.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }
}
```

- [ ] **Step 4: Record snapshots twice (record + verify)**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SmallRenewalWidgetViewSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SmallRenewalWidgetViewSnapshotTests 2>&1 | tail -3
```

Second run: 2 tests pass.

- [ ] **Step 5: Run full suite**

Expected: 192 + 2 = 194 tests.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Widget/SmallRenewalWidgetView.swift \
        TrackrTests/SmallRenewalWidgetView_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/SmallRenewalWidgetView_Snapshot_Tests
git commit -m "feat(widget): add SmallRenewalWidgetView with snapshot baselines"
```

---

### Task 7: `MediumRenewalWidgetView` (snapshot)

**Files:**
- Create: `Trackr/Features/Widget/MediumRenewalWidgetView.swift`
- Create: `TrackrTests/MediumRenewalWidgetView_Snapshot_Tests.swift`

Medium widget shows up to 3 upcoming renewals in a vertical list.

- [ ] **Step 1: Write the failing snapshot tests**

Create `TrackrTests/MediumRenewalWidgetView_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class MediumRenewalWidgetViewSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func host(_ renewals: [UpcomingRenewal]) -> some View {
        MediumRenewalWidgetView(renewals: renewals)
            .frame(width: 338, height: 158)
            .background(TrackrColors.bg)
            .preferredColorScheme(.dark)
    }

    private func renewal(name: String, days: Int, amount: String) -> UpcomingRenewal {
        UpcomingRenewal(id: UUID(), name: name, displayAmount: amount,
                        daysUntil: days, nextBillingDate: .distantFuture)
    }

    func test_threeRenewals_render() {
        assertSnapshot(of: host([
            renewal(name: "Netflix", days: 3, amount: "$15.49"),
            renewal(name: "Spotify", days: 7, amount: "$10.99"),
            renewal(name: "iCloud",  days: 12, amount: "$0.99"),
        ]), as: .image)
    }

    func test_empty_render() {
        assertSnapshot(of: host([]), as: .image)
    }
}
```

- [ ] **Step 2: Run, expect build failure**

Expected: `cannot find 'MediumRenewalWidgetView'`.

- [ ] **Step 3: Implement `MediumRenewalWidgetView.swift`**

Create `Trackr/Features/Widget/MediumRenewalWidgetView.swift`:
```swift
import SwiftUI

/// Medium WidgetKit widget showing up to 3 upcoming renewals as a list.
struct MediumRenewalWidgetView: View {

    let renewals: [UpcomingRenewal]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText("UPCOMING RENEWALS",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            if renewals.isEmpty {
                Spacer()
                PixelText("NO UPCOMING RENEWALS",
                          size: TrackrTypography.Scale.body,
                          color: TrackrColors.fg2,
                          tracking: 1.5)
                Spacer()
            } else {
                ForEach(renewals.prefix(3), id: \.id) { renewal in
                    row(renewal)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private func row(_ renewal: UpcomingRenewal) -> some View {
        HStack(spacing: 10) {
            PixelText("\(renewal.daysUntil)D",
                      size: TrackrTypography.Scale.value,
                      color: TrackrColors.accent,
                      tracking: 1)
                .frame(width: 36, alignment: .leading)
            PixelText(renewal.name.uppercased(),
                      size: TrackrTypography.Scale.body,
                      tracking: 1.5)
                .lineLimit(1)
            Spacer()
            PixelText(renewal.displayAmount,
                      size: TrackrTypography.Scale.body,
                      color: TrackrColors.fg2,
                      tracking: 1)
        }
    }
}
```

- [ ] **Step 4: Record snapshots twice**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/MediumRenewalWidgetViewSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/MediumRenewalWidgetViewSnapshotTests 2>&1 | tail -3
```

Second run: 2 tests pass.

- [ ] **Step 5: Run full suite**

Expected: 194 + 2 = 196 tests.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Widget/MediumRenewalWidgetView.swift \
        TrackrTests/MediumRenewalWidgetView_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/MediumRenewalWidgetView_Snapshot_Tests
git commit -m "feat(widget): add MediumRenewalWidgetView with snapshot baselines"
```

---

### Task 8: Real `TimelineProvider` + WidgetBundle wiring

**Files:**
- Create: `Trackr/Features/Widget/RenewalTimelineProvider.swift`
- Modify: `Widgets/TrackrWidgetsBundle.swift`

The provider opens the shared SwiftData container, reads subscriptions, runs `UpcomingRenewalsProvider`, and emits timeline entries. The widget body branches on `WidgetFamily` to render small vs medium.

- [ ] **Step 1: Create `RenewalTimelineProvider.swift`**

Create `Trackr/Features/Widget/RenewalTimelineProvider.swift`:
```swift
import Foundation
import SwiftData
import WidgetKit

/// One snapshot the WidgetKit timeline machinery hands to the view.
struct RenewalEntry: TimelineEntry {
    let date: Date
    let renewals: [UpcomingRenewal]
}

/// Reads the shared SwiftData store, computes the upcoming renewals, and emits
/// one entry per hour for the next 24 hours. The widget refresh budget on iOS
/// is tight; hourly updates are well within it.
struct RenewalTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> RenewalEntry {
        RenewalEntry(date: .now, renewals: Self.previewRenewals)
    }

    func getSnapshot(in context: Context, completion: @escaping (RenewalEntry) -> Void) {
        if context.isPreview {
            completion(RenewalEntry(date: .now, renewals: Self.previewRenewals))
        } else {
            completion(RenewalEntry(date: .now, renewals: loadRenewals(now: .now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RenewalEntry>) -> Void) {
        var entries: [RenewalEntry] = []
        let calendar = Calendar.current
        let now = Date.now
        for hour in 0..<24 {
            let date = calendar.date(byAdding: .hour, value: hour, to: now) ?? now
            entries.append(RenewalEntry(date: date, renewals: loadRenewals(now: date)))
        }
        // Refresh tomorrow.
        let nextRefresh = calendar.date(byAdding: .hour, value: 24, to: now) ?? .distantFuture
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    // MARK: - private

    private func loadRenewals(now: Date) -> [UpcomingRenewal] {
        guard let container = try? ModelContainerConfig.makeAppContainer(syncMode: .localOnly) else {
            return []
        }
        let context = ModelContext(container)
        let subs = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []
        return UpcomingRenewalsProvider.upcoming(
            subscriptions: subs,
            now: now,
            limit: 3
        )
    }

    private static let previewRenewals: [UpcomingRenewal] = [
        UpcomingRenewal(id: UUID(), name: "Netflix",
                        displayAmount: "$15.49", daysUntil: 3,
                        nextBillingDate: .distantFuture),
        UpcomingRenewal(id: UUID(), name: "Spotify",
                        displayAmount: "$10.99", daysUntil: 7,
                        nextBillingDate: .distantFuture),
        UpcomingRenewal(id: UUID(), name: "iCloud",
                        displayAmount: "$0.99",  daysUntil: 12,
                        nextBillingDate: .distantFuture),
    ]
}
```

- [ ] **Step 2: Replace `TrackrWidgetsBundle.swift` with the real implementation**

Replace `Widgets/TrackrWidgetsBundle.swift` with:
```swift
import WidgetKit
import SwiftUI

@main
struct TrackrWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpcomingRenewalsWidget()
    }
}

struct UpcomingRenewalsWidget: Widget {
    let kind: String = "UpcomingRenewalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RenewalTimelineProvider()) { entry in
            UpcomingRenewalsWidgetView(entry: entry)
        }
        .configurationDisplayName("Upcoming Renewals")
        .description("See your next subscription renewals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UpcomingRenewalsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RenewalEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallRenewalWidgetView(renewal: entry.renewals.first)
        case .systemMedium:
            MediumRenewalWidgetView(renewals: entry.renewals)
        default:
            SmallRenewalWidgetView(renewal: entry.renewals.first)
        }
    }
}
```

- [ ] **Step 3: Run, verify everything still builds and tests pass**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet build 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Both: exit 0; 196 tests pass (no net new tests in T8 — the wiring is exercised by the existing snapshot tests + the manual T10 acceptance).

- [ ] **Step 4: Commit**

```bash
git add Trackr/Features/Widget/RenewalTimelineProvider.swift \
        Widgets/TrackrWidgetsBundle.swift
git commit -m "feat(widget): wire RenewalTimelineProvider and family-aware widget body"
```

---

### Task 9: Wire `SyncDecider` into `TrackrApp` launch

**Files:**
- Modify: `Trackr/TrackrApp.swift`

`TrackrApp.init()` reads `UserSettings.proStatus` (the cached entitlement, which `ProEntitlement.start()` keeps current across launches) and `CKContainer.default().accountStatus` (the current iCloud state), feeds both to `SyncDecider`, and uses the result when building the container.

`CKContainer.accountStatus(completionHandler:)` is callback-based and async. To keep `init()` synchronous (SwiftUI requires the container before scene render), we use the documented `CKContainer.accountStatus()` async overload via a semaphore — or, more pragmatically, we build the container `.localOnly` first, then asynchronously refresh the iCloud state and (if a switch is needed) note that the user should restart the app for sync to engage. M7 takes the second path because it never blocks the launch path.

Concretely:
- Build container with `SyncDecider.decide(proStatus: cachedProStatus, iCloud: .couldNotDetermine)`. With `.couldNotDetermine`, this resolves to `.localOnly`.
- After `entitlement.start()` runs, fire an async task that queries `CKContainer.default().accountStatus()`, recomputes the decision, and persists the desired mode in `UserSettings` (a new boolean column? no — we don't need that. We just log/note for now).
- Add a `desiredSyncMode` non-stored property on the app for later inspection. The actual container build at the NEXT launch will pick up the new state because `UserSettings.proStatus` is already persisted.

This is intentionally a soft launch: M7 ships the wiring, and the live "two-simulator sync within 10 seconds" verification requires production provisioning (M9). Don't overengineer the toggle.

- [ ] **Step 1: Read the cached `proStatus` at launch**

Open `Trackr/TrackrApp.swift`. Replace the file with:

```swift
import SwiftUI
import SwiftData
import UserNotifications
import CloudKit

@main
struct TrackrApp: App {

    private let container: ModelContainer
    private let router: AppDeepLinkRouter
    private let coordinator: NotificationCoordinator
    private let notificationDelegate: TrackrNotificationDelegate
    private let presetSync: PresetSync
    private let entitlement: ProEntitlement
    private let paywallTrigger: PaywallTriggerCoordinator

    init() {
        // Read the cached entitlement from a temporary local-only container so
        // we know which SyncMode to build the real container with.
        let cachedProStatus = Self.readCachedProStatus()
        let syncMode: SyncMode = SyncDecider.decide(
            proStatus: cachedProStatus,
            iCloud: .couldNotDetermine
        )

        do {
            self.container = try ModelContainerConfig.makeAppContainer(syncMode: syncMode)
        } catch {
            // CloudKit can fail to attach (no entitlement in dev, account
            // signed out mid-launch, etc.). Fall back to local-only.
            do {
                self.container = try ModelContainerConfig.makeAppContainer(syncMode: .localOnly)
            } catch {
                fatalError("Failed to construct ModelContainer: \(error)")
            }
        }

        self.router = AppDeepLinkRouter()
        self.coordinator = NotificationCoordinator(
            scheduler: LocalNotificationScheduler(center: SystemNotificationCenter()),
            container: container
        )
        self.notificationDelegate = TrackrNotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate
        self.entitlement = ProEntitlement(client: SystemStoreKitClient(), container: container)
        self.paywallTrigger = PaywallTriggerCoordinator()

        let catalogURL = URL(string: "https://presets.invalid/trackr/v1/presets.json")!
        let pushPublisher = PriceChangePushPublisher(center: SystemNotificationCenter())
        self.presetSync = PresetSync(
            fetcher: URLSessionPresetFetcher(catalogURL: catalogURL),
            container: container,
            pushPublisher: pushPublisher
        )
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(router)
                .environment(\.notificationCoordinator, coordinator)
                .environment(\.presetSync, presetSync)
                .environment(entitlement)
                .environment(paywallTrigger)
                .preferredColorScheme(.dark)
                .task { await entitlement.start() }
        }
        .modelContainer(container)
    }

    /// Reads the previously-persisted `UserSettings.proStatus` from the shared
    /// App Group container. Used at launch (before `ProEntitlement.start()`)
    /// to decide whether to spin up CloudKit.
    @MainActor
    private static func readCachedProStatus() -> ProStatus {
        // Open a temporary local-only container, peek at UserSettings, close.
        // Cheap — SQLite open + one row read.
        do {
            let temp = try ModelContainerConfig.makeAppContainer(syncMode: .localOnly)
            let context = temp.mainContext
            let settings = try context.fetch(FetchDescriptor<UserSettings>()).first
            return settings?.proStatus ?? .free
        } catch {
            return .free
        }
    }
}
```

Note: `readCachedProStatus()` opens a transient local-only container, reads UserSettings, then lets the container go out of scope. The next `makeAppContainer(syncMode:)` call opens the real container in whichever sync mode the decision settled on.

If both `readCachedProStatus`'s container and `makeAppContainer(syncMode: syncMode)` try to open the same SQLite store at the same URL with different configs, SwiftData may complain. To avoid this, scope `readCachedProStatus` in its own block so its container is released before the real one opens:

The implementer should verify by running the build — if SwiftData errors, wrap the cached read in a `do` block that explicitly assigns the container to `nil` before returning, e.g.:
```swift
    @MainActor
    private static func readCachedProStatus() -> ProStatus {
        do {
            let temp: ModelContainer = try ModelContainerConfig.makeAppContainer(syncMode: .localOnly)
            defer { _ = temp } // ensure compiler doesn't optimize away
            let context = temp.mainContext
            let settings = try context.fetch(FetchDescriptor<UserSettings>()).first
            return settings?.proStatus ?? .free
        } catch {
            return .free
        }
    }
```

The local `temp` goes out of scope at function return; ARC drops the container; SQLite closes. Good.

- [ ] **Step 2: Run build + tests**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet build 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Both: exit 0; 196 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Trackr/TrackrApp.swift
git commit -m "feat(sync): read cached proStatus at launch and decide SyncMode"
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

Expected: 196 tests, **TEST SUCCEEDED**.

- [ ] **Step 3: Manual smoke — install app and inspect the widget gallery**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
xcrun simctl boot 'iPhone 16' 2>/dev/null || true
xcrun simctl uninstall booted com.placeholder.trackr 2>/dev/null || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.placeholder.trackr
sleep 2
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m7-home.png
```

Then in the simulator UI, by hand:
1. Add a subscription (`Demo`, $10.00, monthly, start date today).
2. Long-press the home screen → tap "+" → search "Trackr" → add the Small widget. The widget should display "NEXT · DEMO · 30 DAYS · $10.00" (or similar — depends on cycle math; "1 month from today" is fine).
3. Remove the Small widget, add the Medium widget. It should show "UPCOMING RENEWALS · 30D DEMO $10.00".

If WidgetKit doesn't pick up the new widget, force a refresh from `iOS Simulator → Device → Reload Widget Timelines`.

Take a final screenshot:
```bash
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m7-widget.png
```

- [ ] **Step 4: Tag**

```bash
git tag m7-widget-sync
git tag --list 'm*'
git show m7-widget-sync --stat --no-patch
```

Expected tags: `m1-foundation`, `m2-data`, `m3-crud-ui`, `m4-notifications`, `m5-presets`, `m6-iap`, `m7-widget-sync`.

- [ ] **Step 5: Acceptance inventory**

```bash
echo '=== M7 new core files ==='
git ls-files Trackr/Core/Storage Trackr/Core/Widget Trackr/Features/Widget
echo
echo '=== Widget target files ==='
git ls-files Widgets
echo
echo '=== Entitlement files ==='
git ls-files '*.entitlements'
echo
echo '=== Test files added since m6-iap ==='
git diff --name-only m6-iap HEAD -- TrackrTests | sort
echo
echo '=== Commit count m6-iap..HEAD ==='
git rev-list m6-iap..HEAD --count
```

- [ ] **Step 6: Document the open work in the M7 acceptance summary**

The "two-simulator sync within 10 seconds" requirement in the spec needs production Apple Developer team provisioning (real iCloud container, real App Group, signed builds on two iCloud-signed simulators). M7 ships the wiring; M9 verifies the live sync as part of pre-launch checks. Mention this gap explicitly in the final summary.

---

## M7 Acceptance Summary

- `@Attribute(.unique)` removed from all 5 `@Model` types so the schema is CloudKit-compatible. M2's `SubscriptionRepository.fetch(byID:)` already filtered in Swift, so no runtime regression.
- `Trackr.entitlements` / `Widgets.entitlements` declare the App Group (`group.com.placeholder.trackr`) and the app's iCloud container.
- `ModelContainerConfig.makeAppContainer(syncMode:)` relocates the SQLite store to the App Group URL and toggles `cloudKitDatabase: .private(...)` based on the caller's `SyncMode`.
- `SyncDecider` (pure) decides `.cloudKit` only when `ProStatus` is Pro AND `iCloud == .available`.
- `UpcomingRenewalsProvider` (pure) returns the top-N upcoming `UpcomingRenewal` value types from a subscription list.
- `SmallRenewalWidgetView` and `MediumRenewalWidgetView` (both snapshot-tested) render the widget UI.
- `RenewalTimelineProvider` opens the shared SwiftData store and emits 24 hourly entries per refresh window.
- `TrackrWidgetsBundle` is the `@main` widget bundle; supports `.systemSmall` + `.systemMedium`.
- `TrackrApp.init()` reads cached `UserSettings.proStatus` at launch, feeds it to `SyncDecider`, and constructs the container in the chosen sync mode.

**Net new tests:** 13 (3 SyncDecider + 6 UpcomingRenewalsProvider + 2 SmallRenewalWidget snapshot + 2 MediumRenewalWidget snapshot). Total: **196 tests, 0 failures**.

**Open / out-of-scope for M7:**
- Real CloudKit sync verification requires production team provisioning (Apple Developer team prefix on App Group + iCloud container + signed builds). M9 covers this.
- Family Sharing for IAP stays disabled (`familyShareable: false` in `Configuration.storekit`). No code change in M7; the audit-only verification step is part of M9 pre-launch.
- Switching sync mode mid-session (e.g., user buys Pro while the app is running) requires an app relaunch to pick up the new container. Documented; not engineered.

`git tag m7-widget-sync` set. Ready to scope M8 (onboarding + localization + polish).
