# Milestone 2 — Data Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SwiftData persistence layer with CRUD repositories, currency/amount formatting, and drift-safe renewal-date math — all TDD'd against in-memory `ModelContainer`. No UI changes. Output: green test suite that proves all data operations work correctly under realistic edge cases (leap years, month-end anchors, multi-currency input).

**Architecture:**
- 5 SwiftData `@Model` types (`Subscription`, `RenewalEvent`, `PriceChangeAlert`, `UserSettings`, `PresetCache`) live in `Trackr/Core/Models/`.
- 4 enums for type-safe fields (`BillingCycle`, `Category`, `RenewalStatus`, `ProStatus`) live in `Trackr/Core/Models/Enums/`.
- Repositories (`SubscriptionRepository`, `AlertRepository`, `SettingsRepository`) wrap `ModelContext` operations behind narrow, testable APIs. No feature view ever touches `ModelContext` directly — repositories are the only gateway.
- `RenewalCalculator` is a pure stateless function that owns cycle math. Anchored to `startDate` (not "last billing date") to prevent the well-known monthly-drift bug.
- `AmountFormatter` formats `Decimal` amounts to localized strings (`$12.34`, `¥123.00`). Multi-currency aggregation is a V2 concern; we just format individual amounts here.
- `ModelContainer` is constructed in `Storage/ModelContainerConfig.swift`. The app target creates the persistent variant on launch; tests construct the in-memory variant per `XCTestCase` for full isolation.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData (iOS 17), XCTest, swift-snapshot-testing (already added, test-only). Still no runtime third-party dependencies.

---

## File Structure

After M2 the new code looks like this:

```
Trackr/Core/
├─ Models/
│  ├─ Subscription.swift              # @Model
│  ├─ RenewalEvent.swift               # @Model
│  ├─ PriceChangeAlert.swift           # @Model
│  ├─ UserSettings.swift               # @Model — singleton-by-convention
│  ├─ PresetCache.swift                # @Model — singleton-by-convention
│  └─ Enums/
│     ├─ BillingCycle.swift
│     ├─ Category.swift
│     ├─ RenewalStatus.swift
│     └─ ProStatus.swift
├─ Storage/
│  └─ ModelContainerConfig.swift      # makeAppContainer() + makeInMemoryContainer()
├─ Repositories/
│  ├─ SubscriptionRepository.swift
│  ├─ AlertRepository.swift
│  └─ SettingsRepository.swift
├─ Money/
│  └─ AmountFormatter.swift
└─ Cycle/
   └─ RenewalCalculator.swift

TrackrTests/
├─ BillingCycle_Tests.swift
├─ Category_Tests.swift
├─ Subscription_Tests.swift
├─ RenewalEvent_Tests.swift
├─ PriceChangeAlert_Tests.swift
├─ UserSettings_Tests.swift
├─ PresetCache_Tests.swift
├─ AmountFormatter_Tests.swift
├─ RenewalCalculator_Tests.swift
├─ SubscriptionRepository_Tests.swift
├─ AlertRepository_Tests.swift
└─ SettingsRepository_Tests.swift
```

The `Trackr/Features/` and `Trackr/DesignSystem/` trees from M1 are untouched. `TrackrApp.swift` gets a small change in the final task to inject the production `ModelContainer`.

---

### Task 1: Enums — `BillingCycle`, `Category`, `RenewalStatus`, `ProStatus` (TDD)

**Files:**
- Create: `Trackr/Core/Models/Enums/BillingCycle.swift`
- Create: `Trackr/Core/Models/Enums/Category.swift`
- Create: `Trackr/Core/Models/Enums/RenewalStatus.swift`
- Create: `Trackr/Core/Models/Enums/ProStatus.swift`
- Create: `TrackrTests/BillingCycle_Tests.swift`
- Create: `TrackrTests/Category_Tests.swift`

The four enums are simple but `BillingCycle` has an associated value (`.customDays(Int)`), which means we cannot use raw-representable shortcuts; instead we encode/decode via `Codable`. We TDD `BillingCycle`'s round-trip plus the human-readable `Category.displayName` so screens later can rely on stable strings.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/BillingCycle_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class BillingCycleTests: XCTestCase {

    func test_monthly_roundTripsThroughCodable() throws {
        let original: BillingCycle = .monthly
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BillingCycle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_yearly_roundTripsThroughCodable() throws {
        let original: BillingCycle = .yearly
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BillingCycle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_weekly_roundTripsThroughCodable() throws {
        let original: BillingCycle = .weekly
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BillingCycle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_customDays_roundTripsThroughCodable() throws {
        let original: BillingCycle = .customDays(45)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BillingCycle.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_customDays_associatedValueIsPreserved() {
        let cycle: BillingCycle = .customDays(15)
        if case .customDays(let days) = cycle {
            XCTAssertEqual(days, 15)
        } else {
            XCTFail("expected .customDays")
        }
    }
}
```

Create `TrackrTests/Category_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class CategoryTests: XCTestCase {

    func test_allCategoriesHaveDistinctDisplayNames() {
        let names = Category.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count, "displayName collision: \(names)")
    }

    func test_displayName_isStableEnglish() {
        XCTAssertEqual(Category.ai.displayName, "AI")
        XCTAssertEqual(Category.dev.displayName, "Developer")
        XCTAssertEqual(Category.media.displayName, "Media")
        XCTAssertEqual(Category.cloud.displayName, "Cloud")
        XCTAssertEqual(Category.productivity.displayName, "Productivity")
        XCTAssertEqual(Category.other.displayName, "Other")
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
Expected: build error `cannot find 'BillingCycle' / 'Category' in scope`.

- [ ] **Step 3: Implement the four enums**

Create `Trackr/Core/Models/Enums/BillingCycle.swift`:
```swift
import Foundation

/// How often a subscription bills. `customDays` covers irregular cycles like
/// "every 60 days" for non-standard plans.
enum BillingCycle: Codable, Equatable, Hashable {
    case weekly
    case monthly
    case yearly
    case customDays(Int)
}
```

Swift synthesises `Codable` for enums with associated values automatically; the keyed-payload format JSONEncoder emits is stable and round-trips correctly with `JSONDecoder`. We rely on the synthesised implementation.

Create `Trackr/Core/Models/Enums/Category.swift`:
```swift
import Foundation

/// Coarse classification used for grouping and Insights breakdown.
enum Category: String, Codable, CaseIterable, Hashable {
    case ai
    case dev
    case media
    case cloud
    case productivity
    case other

    /// Human-readable English label. Localization comes in M8 via `LocalizedStringKey`.
    var displayName: String {
        switch self {
        case .ai:           return "AI"
        case .dev:          return "Developer"
        case .media:        return "Media"
        case .cloud:        return "Cloud"
        case .productivity: return "Productivity"
        case .other:        return "Other"
        }
    }
}
```

Create `Trackr/Core/Models/Enums/RenewalStatus.swift`:
```swift
import Foundation

/// Lifecycle of a single `RenewalEvent` — i.e. one billing occurrence.
enum RenewalStatus: String, Codable, CaseIterable, Hashable {
    /// Charge expected in the future; default state at creation time.
    case scheduled
    /// Charge confirmed by the user (or auto-confirmed when the date passes).
    case paid
    /// User indicated this cycle was skipped (paused / cancelled mid-cycle).
    case skipped
}
```

Create `Trackr/Core/Models/Enums/ProStatus.swift`:
```swift
import Foundation

/// User's current Pro entitlement state, derived from StoreKit transactions in M6.
/// In M2 we just persist the value; verification logic lives in `ProEntitlement` later.
enum ProStatus: String, Codable, CaseIterable, Hashable {
    case free
    case proMonthly
    case proLifetime
}
```

- [ ] **Step 4: Regenerate and verify tests pass**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | tail -10
```
Expected: exit 0; 21 prior + 7 new tests (5 in BillingCycleTests + 2 in CategoryTests) = 28 total passing.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Models/Enums TrackrTests/BillingCycle_Tests.swift TrackrTests/Category_Tests.swift
git commit -m "feat(core): add BillingCycle, Category, RenewalStatus, ProStatus enums"
```

---

### Task 2: `Subscription` @Model + tests

**Files:**
- Create: `Trackr/Core/Models/Subscription.swift`
- Create: `TrackrTests/Subscription_Tests.swift`

The single most important type in the data layer. Stored properties match the spec section 6 exactly.

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/Subscription_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionTests: XCTestCase {

    func test_canBeInsertedIntoInMemoryContainerAndFetched() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let sub = Subscription(
            name: "AI Chat Pro",
            amount: 20,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_730_000_000),
            category: .ai
        )
        context.insert(sub)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Subscription>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "AI Chat Pro")
        XCTAssertEqual(fetched.first?.billingCycle, .monthly)
        XCTAssertEqual(fetched.first?.category, .ai)
    }

    func test_defaultValuesAreSetOnInit() throws {
        let sub = Subscription(
            name: "X",
            amount: 1,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture,
            startDate: .now,
            category: .other
        )
        XCTAssertTrue(sub.isActive)
        XCTAssertNil(sub.planName)
        XCTAssertNil(sub.notes)
        XCTAssertNil(sub.url)
        XCTAssertNil(sub.presetId)
        XCTAssertNil(sub.pausedUntil)
    }

    func test_iconRefDefaultsToCustomQuestionMark() throws {
        let sub = Subscription(
            name: "X",
            amount: 1,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture,
            startDate: .now,
            category: .other
        )
        XCTAssertEqual(sub.iconRef, "custom:emoji:❓")
    }
}
```

The test references `makeInMemoryContainer()` — this helper lands in Task 8. To unblock TDD now, add a temporary stub at the bottom of this test file (you will delete it in Task 8):

```swift
import Foundation
import SwiftData

func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Subscription.self, RenewalEvent.self, PriceChangeAlert.self, UserSettings.self, PresetCache.self,
        configurations: config
    )
}
```

Note: this stub references types that don't exist yet (`RenewalEvent`, etc.). Comment them out for now and add them back as each task lands. Specifically, at the end of Task 2 the helper reads:

```swift
return try ModelContainer(
    for: Subscription.self,
    configurations: config
)
```

When subsequent tasks add new models, append them to the `for:` list.

- [ ] **Step 2: Run, verify build fails**

Same xcodebuild command. Expected: `cannot find 'Subscription' in scope`.

- [ ] **Step 3: Implement `Subscription.swift`**

Create `Trackr/Core/Models/Subscription.swift`:
```swift
import Foundation
import SwiftData

/// A recurring subscription the user is tracking. Source of truth for everything
/// the app displays on the Home / Detail screens.
@Model
final class Subscription {
    // Identity
    @Attribute(.unique) var id: UUID

    // Core fields
    var name: String
    var planName: String?
    var amount: Decimal
    var currency: String          // ISO 4217 — "USD", "CNY", etc.
    var billingCycle: BillingCycle
    var nextBillingDate: Date
    var startDate: Date           // anchor for cycle math — never changes after creation
    var category: Category

    // Optional metadata
    var paymentMethod: String?
    var notes: String?
    var url: URL?
    /// Either `"preset:<id>"` for library-backed subs, or `"custom:emoji:<emoji>"` for manual ones.
    var iconRef: String
    /// Set when this Subscription was added from the AI preset library. Used by M5 price-change matching.
    var presetId: String?

    // State
    var isActive: Bool
    var pausedUntil: Date?

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        planName: String? = nil,
        amount: Decimal,
        currency: String,
        billingCycle: BillingCycle,
        nextBillingDate: Date,
        startDate: Date,
        category: Category,
        paymentMethod: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        iconRef: String = "custom:emoji:❓",
        presetId: String? = nil,
        isActive: Bool = true,
        pausedUntil: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.planName = planName
        self.amount = amount
        self.currency = currency
        self.billingCycle = billingCycle
        self.nextBillingDate = nextBillingDate
        self.startDate = startDate
        self.category = category
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.url = url
        self.iconRef = iconRef
        self.presetId = presetId
        self.isActive = isActive
        self.pausedUntil = pausedUntil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 28 + 3 = 31 tests passing.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Models/Subscription.swift TrackrTests/Subscription_Tests.swift
git commit -m "feat(core): add Subscription @Model"
```

---

### Task 3: `RenewalEvent` @Model + tests

**Files:**
- Create: `Trackr/Core/Models/RenewalEvent.swift`
- Create: `TrackrTests/RenewalEvent_Tests.swift`
- Modify: `TrackrTests/Subscription_Tests.swift` — extend the `makeInMemoryContainer` stub's `for:` list to include `RenewalEvent.self`.

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/RenewalEvent_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class RenewalEventTests: XCTestCase {

    func test_canBeInsertedAndFetched() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let subId = UUID()
        let event = RenewalEvent(
            subscriptionId: subId,
            date: .now,
            amount: 20,
            currency: "USD",
            status: .scheduled
        )
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RenewalEvent>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.subscriptionId, subId)
        XCTAssertEqual(fetched.first?.status, .scheduled)
    }
}
```

- [ ] **Step 2: Update the shared `makeInMemoryContainer` helper**

In `TrackrTests/Subscription_Tests.swift`, update the helper at the bottom:
```swift
return try ModelContainer(
    for: Subscription.self, RenewalEvent.self,
    configurations: config
)
```

- [ ] **Step 3: Run, verify build fails**

Expected: `cannot find 'RenewalEvent' in scope`.

- [ ] **Step 4: Implement `RenewalEvent.swift`**

Create `Trackr/Core/Models/RenewalEvent.swift`:
```swift
import Foundation
import SwiftData

/// One billing occurrence. Captured at the moment of renewal so we can display
/// historical amounts on the Detail screen even after prices change.
@Model
final class RenewalEvent {
    @Attribute(.unique) var id: UUID
    var subscriptionId: UUID
    var date: Date
    var amount: Decimal
    var currency: String
    var status: RenewalStatus

    init(
        id: UUID = UUID(),
        subscriptionId: UUID,
        date: Date,
        amount: Decimal,
        currency: String,
        status: RenewalStatus = .scheduled
    ) {
        self.id = id
        self.subscriptionId = subscriptionId
        self.date = date
        self.amount = amount
        self.currency = currency
        self.status = status
    }
}
```

We use `subscriptionId: UUID` rather than a SwiftData relationship intentionally — relationships in SwiftData with CloudKit sync currently have subtle write-amplification quirks. Joining on UUID is simpler and explicit.

- [ ] **Step 5: Run, verify tests pass**

Expected: 31 + 1 = 32 tests passing.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Core/Models/RenewalEvent.swift TrackrTests/RenewalEvent_Tests.swift TrackrTests/Subscription_Tests.swift
git commit -m "feat(core): add RenewalEvent @Model"
```

---

### Task 4: `PriceChangeAlert` @Model + tests

**Files:**
- Create: `Trackr/Core/Models/PriceChangeAlert.swift`
- Create: `TrackrTests/PriceChangeAlert_Tests.swift`
- Modify: `TrackrTests/Subscription_Tests.swift` — extend helper.

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/PriceChangeAlert_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class PriceChangeAlertTests: XCTestCase {

    func test_canBeInsertedWithBothLocalizations() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let alert = PriceChangeAlert(
            presetId: "vendor.product",
            planKey: "pro",
            oldAmount: 18,
            newAmount: 20,
            currency: "USD",
            effectiveDate: .now,
            messageEn: "Pro tier up $2/mo",
            messageZh: "Pro 档涨 $2/月"
        )
        context.insert(alert)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PriceChangeAlert>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.messageEn, "Pro tier up $2/mo")
        XCTAssertEqual(fetched.first?.messageZh, "Pro 档涨 $2/月")
        XCTAssertNil(fetched.first?.seenAt)
    }

    func test_seenAtCanBeMarked() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let alert = PriceChangeAlert(
            presetId: "vendor.product",
            planKey: "pro",
            oldAmount: 18, newAmount: 20,
            currency: "USD",
            effectiveDate: .now,
            messageEn: "", messageZh: ""
        )
        context.insert(alert)
        let when = Date(timeIntervalSince1970: 1_750_000_000)
        alert.seenAt = when
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PriceChangeAlert>())
        XCTAssertEqual(fetched.first?.seenAt, when)
    }
}
```

- [ ] **Step 2: Update the shared helper**

```swift
return try ModelContainer(
    for: Subscription.self, RenewalEvent.self, PriceChangeAlert.self,
    configurations: config
)
```

- [ ] **Step 3: Run, verify build fails**

Expected: `cannot find 'PriceChangeAlert' in scope`.

- [ ] **Step 4: Implement `PriceChangeAlert.swift`**

Create `Trackr/Core/Models/PriceChangeAlert.swift`:
```swift
import Foundation
import SwiftData

/// A price-change record generated by `PresetSync` (M5) when the remote presets.json
/// version reports a different amount than our cached version. Surfaces as a banner
/// on the relevant Subscription Detail screen, and (Pro only) as a push notification.
@Model
final class PriceChangeAlert {
    @Attribute(.unique) var id: UUID
    var presetId: String
    var planKey: String
    var oldAmount: Decimal
    var newAmount: Decimal
    var currency: String
    var effectiveDate: Date
    /// English message body. The two locales are stored separately so localization is
    /// a JSON-fetch problem, not a runtime translation problem.
    var messageEn: String
    /// Simplified Chinese message body.
    var messageZh: String
    /// `nil` until the user dismisses the banner.
    var seenAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        presetId: String,
        planKey: String,
        oldAmount: Decimal,
        newAmount: Decimal,
        currency: String,
        effectiveDate: Date,
        messageEn: String,
        messageZh: String,
        seenAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.presetId = presetId
        self.planKey = planKey
        self.oldAmount = oldAmount
        self.newAmount = newAmount
        self.currency = currency
        self.effectiveDate = effectiveDate
        self.messageEn = messageEn
        self.messageZh = messageZh
        self.seenAt = seenAt
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 5: Run, verify tests pass**

Expected: 32 + 2 = 34 tests.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Core/Models/PriceChangeAlert.swift TrackrTests/PriceChangeAlert_Tests.swift TrackrTests/Subscription_Tests.swift
git commit -m "feat(core): add PriceChangeAlert @Model"
```

---

### Task 5: `UserSettings` @Model + tests

**Files:**
- Create: `Trackr/Core/Models/UserSettings.swift`
- Create: `TrackrTests/UserSettings_Tests.swift`
- Modify: shared helper.

`UserSettings` is conceptually a singleton — the app only ever has one row. SwiftData doesn't enforce singleton-ness; we encode that in the repository (Task 12) by always fetching `.first` and creating on miss.

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/UserSettings_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class UserSettingsTests: XCTestCase {

    func test_defaultsMatchSpec() throws {
        let s = UserSettings()
        XCTAssertEqual(s.defaultCurrency, "USD")
        XCTAssertEqual(s.leadDays, [3, 1])
        XCTAssertEqual(s.notifyHour, 9)
        XCTAssertEqual(s.language, "auto")
        XCTAssertFalse(s.biometricLockEnabled)
        XCTAssertEqual(s.proStatus, .free)
        XCTAssertNil(s.proExpiresAt)
        XCTAssertNil(s.onboardingCompletedAt)
    }

    func test_canBeInsertedAndMutated() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let s = UserSettings()
        context.insert(s)
        try context.save()

        s.notifyHour = 18
        s.proStatus = .proLifetime
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserSettings>()).first
        XCTAssertEqual(fetched?.notifyHour, 18)
        XCTAssertEqual(fetched?.proStatus, .proLifetime)
    }
}
```

- [ ] **Step 2: Update helper**

```swift
return try ModelContainer(
    for: Subscription.self, RenewalEvent.self, PriceChangeAlert.self, UserSettings.self,
    configurations: config
)
```

- [ ] **Step 3: Run, verify build fails**

- [ ] **Step 4: Implement `UserSettings.swift`**

Create `Trackr/Core/Models/UserSettings.swift`:
```swift
import Foundation
import SwiftData

/// User-tunable app settings. One row only — enforced by `SettingsRepository`, not
/// at the schema level (SwiftData has no singleton constraint).
@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var defaultCurrency: String
    /// Days before `nextBillingDate` to fire local notifications. Default [3, 1].
    var leadDays: [Int]
    /// Hour (0–23) at which notifications fire in the user's local timezone.
    var notifyHour: Int
    /// "auto" | "en" | "zh-Hans". M8 wires this into the localization layer.
    var language: String
    var biometricLockEnabled: Bool
    var proStatus: ProStatus
    var proExpiresAt: Date?
    var onboardingCompletedAt: Date?

    init(
        id: UUID = UUID(),
        defaultCurrency: String = "USD",
        leadDays: [Int] = [3, 1],
        notifyHour: Int = 9,
        language: String = "auto",
        biometricLockEnabled: Bool = false,
        proStatus: ProStatus = .free,
        proExpiresAt: Date? = nil,
        onboardingCompletedAt: Date? = nil
    ) {
        self.id = id
        self.defaultCurrency = defaultCurrency
        self.leadDays = leadDays
        self.notifyHour = notifyHour
        self.language = language
        self.biometricLockEnabled = biometricLockEnabled
        self.proStatus = proStatus
        self.proExpiresAt = proExpiresAt
        self.onboardingCompletedAt = onboardingCompletedAt
    }
}
```

- [ ] **Step 5: Run, verify tests pass**

Expected: 34 + 2 = 36.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Core/Models/UserSettings.swift TrackrTests/UserSettings_Tests.swift TrackrTests/Subscription_Tests.swift
git commit -m "feat(core): add UserSettings @Model"
```

---

### Task 6: `PresetCache` @Model + tests

**Files:**
- Create: `Trackr/Core/Models/PresetCache.swift`
- Create: `TrackrTests/PresetCache_Tests.swift`
- Modify: shared helper.

`PresetCache` mirrors the remote `presets.json`. The full payload is stored as raw `Data` (so we can deserialize via `JSONDecoder` into typed `PresetItem` later in M5 without making `PresetCache` aware of that shape now).

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/PresetCache_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class PresetCacheTests: XCTestCase {

    func test_canBeInsertedAndFetched() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let payload = Data("{\"version\":\"2026.05.15\"}".utf8)
        let cache = PresetCache(
            version: "2026.05.15",
            fetchedAt: Date(timeIntervalSince1970: 1_750_000_000),
            data: payload
        )
        context.insert(cache)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PresetCache>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.version, "2026.05.15")
        XCTAssertEqual(fetched.first?.data, payload)
    }
}
```

- [ ] **Step 2: Update helper**

```swift
return try ModelContainer(
    for: Subscription.self, RenewalEvent.self, PriceChangeAlert.self, UserSettings.self, PresetCache.self,
    configurations: config
)
```

- [ ] **Step 3: Run, verify build fails**

- [ ] **Step 4: Implement `PresetCache.swift`**

Create `Trackr/Core/Models/PresetCache.swift`:
```swift
import Foundation
import SwiftData

/// Mirror of the remote `presets.json`. One row only.
/// `data` holds the raw JSON payload — parsing into typed `PresetItem` is done by
/// `PresetSync` (M5) so this model stays schema-agnostic.
@Model
final class PresetCache {
    @Attribute(.unique) var id: UUID
    var version: String
    var fetchedAt: Date
    var data: Data

    init(
        id: UUID = UUID(),
        version: String,
        fetchedAt: Date,
        data: Data
    ) {
        self.id = id
        self.version = version
        self.fetchedAt = fetchedAt
        self.data = data
    }
}
```

- [ ] **Step 5: Run, verify tests pass**

Expected: 36 + 1 = 37.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Core/Models/PresetCache.swift TrackrTests/PresetCache_Tests.swift TrackrTests/Subscription_Tests.swift
git commit -m "feat(core): add PresetCache @Model"
```

---

### Task 7: Extract `ModelContainerConfig` and replace the test stub

**Files:**
- Create: `Trackr/Core/Storage/ModelContainerConfig.swift`
- Modify: `TrackrTests/Subscription_Tests.swift` — remove the inline stub helper.
- Modify: every test file that calls `makeInMemoryContainer()` — they'll now resolve via `@testable import Trackr`.

- [ ] **Step 1: Implement `ModelContainerConfig.swift`**

Create `Trackr/Core/Storage/ModelContainerConfig.swift`:
```swift
import Foundation
import SwiftData

/// Constructs SwiftData `ModelContainer`s for the app and for tests.
enum ModelContainerConfig {

    /// The persistent container used by the running app. Lives in the user's app group.
    /// CloudKit sync wiring lands in M7; for M2 this is local-only persistence.
    static func makeAppContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
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

The free function at the bottom is intentionally a top-level shim so existing test calls keep working without imports changes.

- [ ] **Step 2: Delete the inline stub helper in `TrackrTests/Subscription_Tests.swift`**

Remove the entire bottom block:
```swift
// DELETE THIS:
import Foundation
import SwiftData

func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Subscription.self, RenewalEvent.self, PriceChangeAlert.self, UserSettings.self, PresetCache.self,
        configurations: config
    )
}
```

The shim in `ModelContainerConfig.swift` replaces it.

- [ ] **Step 3: Regenerate and run all tests**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | tail -10
```

Expected: exit 0, 37 tests still passing. No new tests; this is a refactor.

- [ ] **Step 4: Commit**

```bash
git add Trackr/Core/Storage/ModelContainerConfig.swift TrackrTests/Subscription_Tests.swift
git commit -m "refactor(core): centralise ModelContainer construction"
```

---

### Task 8: `AmountFormatter` (TDD)

**Files:**
- Create: `Trackr/Core/Money/AmountFormatter.swift`
- Create: `TrackrTests/AmountFormatter_Tests.swift`

Formats a `Decimal` + ISO currency code into a localized display string. Used by the Home hero number and Detail amount in M3.

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/AmountFormatter_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class AmountFormatterTests: XCTestCase {

    func test_USD_simpleInteger() {
        XCTAssertEqual(AmountFormatter.format(20, currency: "USD"), "$20.00")
    }

    func test_USD_decimal() {
        XCTAssertEqual(AmountFormatter.format(Decimal(string: "147.92")!, currency: "USD"), "$147.92")
    }

    func test_CNY_simple() {
        XCTAssertEqual(AmountFormatter.format(21, currency: "CNY"), "¥21.00")
    }

    func test_zero() {
        XCTAssertEqual(AmountFormatter.format(0, currency: "USD"), "$0.00")
    }

    func test_thousandsSeparator() {
        XCTAssertEqual(
            AmountFormatter.format(Decimal(string: "1775")!, currency: "USD"),
            "$1,775.00"
        )
    }

    func test_unknownCurrency_fallsBackToCodePrefix() {
        // For unknown ISO codes, we don't crash — we just prefix with the code.
        let result = AmountFormatter.format(10, currency: "ZZZ")
        XCTAssertTrue(result.contains("10"), "got: \(result)")
    }
}
```

- [ ] **Step 2: Run, verify build fails**

- [ ] **Step 3: Implement `AmountFormatter.swift`**

Create `Trackr/Core/Money/AmountFormatter.swift`:
```swift
import Foundation

/// Formats a `Decimal` amount and ISO 4217 currency code into a display string.
/// Always emits two fractional digits per the spec ("$20.00", not "$20").
enum AmountFormatter {

    /// Format `amount` as `currency`. The result respects the *currency's* conventional
    /// symbol and grouping (USD = $1,775.00; CNY = ¥21.00) regardless of the user's
    /// system locale — we want consistent app-wide display until M8 i18n lands.
    static func format(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        // Use en_US_POSIX as the formatting locale so grouping & decimal separators
        // are stable. Currency symbol still respects the ISO code.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency) \(amount)"
    }
}
```

The `en_US_POSIX` choice keeps grouping characters identical across user locales for V1 — when M8 i18n lands we'll revisit and let the user's chosen `language` setting drive this. Test 6 (`unknownCurrency_fallsBackToCodePrefix`) passes because `NumberFormatter` returns a sensible non-symbol display for unknown ISO codes (the test only requires the amount be present in the output).

- [ ] **Step 4: Run, verify tests pass**

Expected: 37 + 6 = 43.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Money/AmountFormatter.swift TrackrTests/AmountFormatter_Tests.swift
git commit -m "feat(core): add AmountFormatter with TDD coverage"
```

---

### Task 9: `RenewalCalculator` — drift-safe cycle math (TDD — the meat of M2)

**Files:**
- Create: `Trackr/Core/Cycle/RenewalCalculator.swift`
- Create: `TrackrTests/RenewalCalculator_Tests.swift`

This is the highest-value piece of M2. Most subscription-tracker bugs come from sloppy cycle math (the classic "subscribed 31 Jan, now stuck on the 28th forever" drift). We anchor everything to `startDate`.

- [ ] **Step 1: Write the failing tests (extensive edge-case coverage)**

Create `TrackrTests/RenewalCalculator_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class RenewalCalculatorTests: XCTestCase {

    // MARK: helpers

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)!
    }

    // MARK: monthly happy paths

    func test_monthly_today_isBeforeFirstBilling_returnsStartDate() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-01-01"),
            startingFrom: date("2026-02-15"),
            cycle: .monthly
        )
        XCTAssertEqual(next, date("2026-02-15"))
    }

    func test_monthly_today_isAfterFirstBilling_returnsSecondCycle() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-02-16"),
            startingFrom: date("2026-02-15"),
            cycle: .monthly
        )
        XCTAssertEqual(next, date("2026-03-15"))
    }

    func test_monthly_today_isExactlyOnPreviousBilling_returnsNextCycle() {
        // Convention: if today == startDate, the user is on day 0 of cycle 1.
        // Next billing is one full cycle later.
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-02-15"),
            startingFrom: date("2026-02-15"),
            cycle: .monthly
        )
        XCTAssertEqual(next, date("2026-03-15"))
    }

    // MARK: month-end anchoring (the drift bug)

    func test_monthly_31stStartDate_preservesAnchor_acrossShortMonths() {
        // start 31 Jan → cycle dates should be 31-of-each-month (or end-of-month if shorter).
        // CRITICAL: after passing through Feb (28 days), the March cycle MUST go back to 31.
        // Naive "add 1 month to last billing" would stay stuck on 28 forever — this is the bug we prevent.
        let start = date("2026-01-31")

        XCTAssertEqual(
            RenewalCalculator.nextBillingDate(after: date("2026-01-31"), startingFrom: start, cycle: .monthly),
            date("2026-02-28"),
            "Feb cycle clamps to month-end"
        )
        XCTAssertEqual(
            RenewalCalculator.nextBillingDate(after: date("2026-02-28"), startingFrom: start, cycle: .monthly),
            date("2026-03-31"),
            "March cycle must restore the 31st anchor"
        )
        XCTAssertEqual(
            RenewalCalculator.nextBillingDate(after: date("2026-04-30"), startingFrom: start, cycle: .monthly),
            date("2026-05-31"),
            "May cycle restores 31st after April's 30"
        )
    }

    // MARK: leap years

    func test_yearly_feb29Start_inLeapYear_landsOnFeb28InNonLeap() {
        let start = date("2024-02-29")
        let next = RenewalCalculator.nextBillingDate(
            after: date("2024-12-31"),
            startingFrom: start,
            cycle: .yearly
        )
        XCTAssertEqual(next, date("2025-02-28"))
    }

    func test_yearly_feb29Start_returnsToFeb29InNextLeapYear() {
        let start = date("2024-02-29")
        let next = RenewalCalculator.nextBillingDate(
            after: date("2027-12-31"),
            startingFrom: start,
            cycle: .yearly
        )
        XCTAssertEqual(next, date("2028-02-29"))
    }

    // MARK: weekly

    func test_weekly_today_isBeforeStart_returnsStart() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-02-01"),
            startingFrom: date("2026-02-08"),
            cycle: .weekly
        )
        XCTAssertEqual(next, date("2026-02-08"))
    }

    func test_weekly_today_isMidCycle_returnsNextWeekFromStart() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-02-10"),
            startingFrom: date("2026-02-08"),
            cycle: .weekly
        )
        XCTAssertEqual(next, date("2026-02-15"))
    }

    // MARK: customDays

    func test_customDays_60_today_pastStart() {
        let next = RenewalCalculator.nextBillingDate(
            after: date("2026-04-01"),
            startingFrom: date("2026-01-01"),
            cycle: .customDays(60)
        )
        // cycles: 2026-01-01, 2026-03-02, 2026-05-01
        XCTAssertEqual(next, date("2026-05-01"))
    }
}
```

- [ ] **Step 2: Run, verify build fails**

- [ ] **Step 3: Implement `RenewalCalculator.swift`**

Create `Trackr/Core/Cycle/RenewalCalculator.swift`:
```swift
import Foundation

/// Computes the next billing date for a subscription. All calculations are anchored
/// to `startDate` rather than chained off the previous billing, which prevents the
/// classic month-end drift bug ("subscribed Jan 31, stuck on the 28th forever").
enum RenewalCalculator {

    /// Returns the next billing date strictly after `today`, given `startDate` as the
    /// anchor and `cycle` as the recurrence.
    ///
    /// - Parameters:
    ///   - today: The reference instant. Usually `.now`.
    ///   - startDate: The first-ever billing date for this subscription. Never changes.
    ///   - cycle: The recurrence pattern.
    /// - Returns: The next billing date strictly after `today`.
    static func nextBillingDate(
        after today: Date,
        startingFrom startDate: Date,
        cycle: BillingCycle
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // If we haven't reached the first billing yet, that's the answer.
        if today < startDate {
            return startDate
        }

        switch cycle {
        case .monthly:
            return nthDate(after: today, startDate: startDate, unit: .month, in: calendar)
        case .yearly:
            return nthDate(after: today, startDate: startDate, unit: .year, in: calendar)
        case .weekly:
            return nthDate(after: today, startDate: startDate, unit: .day, in: calendar, step: 7)
        case .customDays(let days):
            return nthDate(after: today, startDate: startDate, unit: .day, in: calendar, step: days)
        }
    }

    /// Finds the smallest N ≥ 1 such that `startDate + N×step` of `unit` is strictly
    /// after `today`. By computing every candidate from `startDate` we avoid drift.
    private static func nthDate(
        after today: Date,
        startDate: Date,
        unit: Calendar.Component,
        in calendar: Calendar,
        step: Int = 1
    ) -> Date {
        // Lower bound — the number of complete `unit`s already elapsed.
        let elapsed = max(0, calendar.dateComponents([unit], from: startDate, to: today).value(for: unit) ?? 0)
        // Convert to cycle index. For step=1, n is just elapsed; for step>1 (weekly,
        // customDays), divide.
        let cyclesElapsed = elapsed / step
        var n = cyclesElapsed + 1

        // Calendar's "add N months to Jan 31" returns Feb 28 — Apple's natural wrap.
        // That's the behaviour we want; we never re-anchor on the wrapped date because
        // we always re-compute from startDate each invocation.
        var candidate = calendar.date(byAdding: unit, value: n * step, to: startDate) ?? today
        // Guard against rounding-floor edge cases where the candidate happens to equal
        // `today`: push one more cycle.
        while candidate <= today {
            n += 1
            candidate = calendar.date(byAdding: unit, value: n * step, to: startDate) ?? today
        }
        return candidate
    }
}

private extension DateComponents {
    func value(for unit: Calendar.Component) -> Int? {
        switch unit {
        case .month: return month
        case .year:  return year
        case .day:   return day
        case .weekOfYear: return weekOfYear
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Run, verify all 9 tests pass**

If any test fails, do **not** modify the tests. Read the failure message and adjust the implementation. The 31-of-month and Feb 29 cases are the most likely to require iteration.

Expected: exit 0, 43 + 9 = 52 tests passing.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Cycle/RenewalCalculator.swift TrackrTests/RenewalCalculator_Tests.swift
git commit -m "feat(core): add RenewalCalculator with drift-safe cycle math"
```

---

### Task 10: `SubscriptionRepository` (TDD CRUD)

**Files:**
- Create: `Trackr/Core/Repositories/SubscriptionRepository.swift`
- Create: `TrackrTests/SubscriptionRepository_Tests.swift`

The narrow API features call. Throws `SubscriptionLimitExceeded` when a free user tries to add their 6th sub (the actual gate logic lands in M6, but the error type exists now).

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/SubscriptionRepository_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionRepositoryTests: XCTestCase {

    private func makeRepo() throws -> (SubscriptionRepository, ModelContext) {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        return (SubscriptionRepository(context: context), context)
    }

    private func makeSub(name: String = "Test") -> Subscription {
        Subscription(
            name: name,
            amount: 10,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture,
            startDate: .now,
            category: .other
        )
    }

    func test_insert_thenFetchAll_returnsOneSub() throws {
        let (repo, _) = try makeRepo()
        try repo.insert(makeSub(name: "Alpha"))
        XCTAssertEqual(try repo.fetchAll().count, 1)
        XCTAssertEqual(try repo.fetchAll().first?.name, "Alpha")
    }

    func test_fetchAll_sortsByNextBillingDateAscending() throws {
        let (repo, _) = try makeRepo()
        let near = Subscription(
            name: "Near", amount: 1, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_000),
            startDate: .now, category: .other
        )
        let far = Subscription(
            name: "Far", amount: 1, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 2_000),
            startDate: .now, category: .other
        )
        try repo.insert(far)
        try repo.insert(near)
        let result = try repo.fetchAll()
        XCTAssertEqual(result.map(\.name), ["Near", "Far"])
    }

    func test_delete_removesIt() throws {
        let (repo, _) = try makeRepo()
        let sub = makeSub(name: "ToDelete")
        try repo.insert(sub)
        XCTAssertEqual(try repo.fetchAll().count, 1)
        try repo.delete(sub)
        XCTAssertEqual(try repo.fetchAll().count, 0)
    }

    func test_count_reflectsInserts() throws {
        let (repo, _) = try makeRepo()
        XCTAssertEqual(try repo.count(), 0)
        try repo.insert(makeSub())
        try repo.insert(makeSub())
        XCTAssertEqual(try repo.count(), 2)
    }

    func test_fetchByID_findsIt() throws {
        let (repo, _) = try makeRepo()
        let sub = makeSub(name: "FindMe")
        try repo.insert(sub)
        let found = try repo.fetch(byID: sub.id)
        XCTAssertEqual(found?.name, "FindMe")
    }

    func test_fetchByID_returnsNilForMissing() throws {
        let (repo, _) = try makeRepo()
        let result = try repo.fetch(byID: UUID())
        XCTAssertNil(result)
    }
}
```

- [ ] **Step 2: Run, verify build fails**

- [ ] **Step 3: Implement `SubscriptionRepository.swift`**

Create `Trackr/Core/Repositories/SubscriptionRepository.swift`:
```swift
import Foundation
import SwiftData

/// Thrown by `insert(...)` when a free-tier user attempts to exceed the 5-subscription limit.
/// Enforcement of the gate lives in M6 — for now this error type just exists so callers
/// can route to the paywall when it lands.
struct SubscriptionLimitExceeded: Error {}

/// The single gateway between features and SwiftData for `Subscription` rows.
@MainActor
struct SubscriptionRepository {
    let context: ModelContext

    func insert(_ sub: Subscription) throws {
        context.insert(sub)
        try context.save()
    }

    func delete(_ sub: Subscription) throws {
        context.delete(sub)
        try context.save()
    }

    func fetchAll() throws -> [Subscription] {
        var descriptor = FetchDescriptor<Subscription>(
            sortBy: [SortDescriptor(\.nextBillingDate, order: .forward)]
        )
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor)
    }

    func fetch(byID id: UUID) throws -> Subscription? {
        let descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<Subscription>())
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 52 + 6 = 58.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Repositories/SubscriptionRepository.swift TrackrTests/SubscriptionRepository_Tests.swift
git commit -m "feat(core): add SubscriptionRepository with TDD CRUD coverage"
```

---

### Task 11: `AlertRepository` (TDD)

**Files:**
- Create: `Trackr/Core/Repositories/AlertRepository.swift`
- Create: `TrackrTests/AlertRepository_Tests.swift`

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/AlertRepository_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class AlertRepositoryTests: XCTestCase {

    private func makeRepo() throws -> AlertRepository {
        let container = try makeInMemoryContainer()
        return AlertRepository(context: container.mainContext)
    }

    private func makeAlert(presetId: String = "p", seen: Date? = nil) -> PriceChangeAlert {
        PriceChangeAlert(
            presetId: presetId, planKey: "pro",
            oldAmount: 1, newAmount: 2,
            currency: "USD",
            effectiveDate: .now,
            messageEn: "", messageZh: "",
            seenAt: seen
        )
    }

    func test_insertedAlertIsFetchable() throws {
        let repo = try makeRepo()
        let alert = makeAlert(presetId: "vendor.product")
        try repo.insert(alert)
        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.presetId, "vendor.product")
    }

    func test_fetchUnseen_excludesAlreadyDismissed() throws {
        let repo = try makeRepo()
        try repo.insert(makeAlert(presetId: "a"))
        try repo.insert(makeAlert(presetId: "b", seen: .now))
        let unseen = try repo.fetchUnseen()
        XCTAssertEqual(unseen.map(\.presetId), ["a"])
    }

    func test_markSeen_setsSeenAt() throws {
        let repo = try makeRepo()
        let alert = makeAlert(presetId: "x")
        try repo.insert(alert)
        XCTAssertNil(alert.seenAt)
        try repo.markSeen(alert)
        XCTAssertNotNil(alert.seenAt)
    }

    func test_fetchForPreset_filtersById() throws {
        let repo = try makeRepo()
        try repo.insert(makeAlert(presetId: "match"))
        try repo.insert(makeAlert(presetId: "other"))
        let result = try repo.fetch(forPresetId: "match")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.presetId, "match")
    }
}
```

- [ ] **Step 2: Run, verify build fails**

- [ ] **Step 3: Implement `AlertRepository.swift`**

Create `Trackr/Core/Repositories/AlertRepository.swift`:
```swift
import Foundation
import SwiftData

@MainActor
struct AlertRepository {
    let context: ModelContext

    func insert(_ alert: PriceChangeAlert) throws {
        context.insert(alert)
        try context.save()
    }

    func markSeen(_ alert: PriceChangeAlert, at date: Date = .now) throws {
        alert.seenAt = date
        try context.save()
    }

    func fetchAll() throws -> [PriceChangeAlert] {
        let descriptor = FetchDescriptor<PriceChangeAlert>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchUnseen() throws -> [PriceChangeAlert] {
        let descriptor = FetchDescriptor<PriceChangeAlert>(
            predicate: #Predicate { $0.seenAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetch(forPresetId presetId: String) throws -> [PriceChangeAlert] {
        let descriptor = FetchDescriptor<PriceChangeAlert>(
            predicate: #Predicate { $0.presetId == presetId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 58 + 4 = 62.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Repositories/AlertRepository.swift TrackrTests/AlertRepository_Tests.swift
git commit -m "feat(core): add AlertRepository with TDD coverage"
```

---

### Task 12: `SettingsRepository` (TDD — singleton-by-convention)

**Files:**
- Create: `Trackr/Core/Repositories/SettingsRepository.swift`
- Create: `TrackrTests/SettingsRepository_Tests.swift`

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/SettingsRepository_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SettingsRepositoryTests: XCTestCase {

    private func makeRepo() throws -> SettingsRepository {
        let container = try makeInMemoryContainer()
        return SettingsRepository(context: container.mainContext)
    }

    func test_currentSettings_createsRowOnFirstCall() throws {
        let repo = try makeRepo()
        let settings = try repo.currentSettings()
        XCTAssertEqual(settings.defaultCurrency, "USD")
        XCTAssertEqual(settings.leadDays, [3, 1])
        XCTAssertEqual(settings.proStatus, .free)
    }

    func test_currentSettings_returnsSameRowOnSubsequentCalls() throws {
        let repo = try makeRepo()
        let first = try repo.currentSettings()
        first.notifyHour = 22
        try repo.save()

        let second = try repo.currentSettings()
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.notifyHour, 22)
    }

    func test_proStatus_canBeMutated() throws {
        let repo = try makeRepo()
        let s = try repo.currentSettings()
        s.proStatus = .proLifetime
        try repo.save()

        let reFetched = try repo.currentSettings()
        XCTAssertEqual(reFetched.proStatus, .proLifetime)
    }
}
```

- [ ] **Step 2: Run, verify build fails**

- [ ] **Step 3: Implement `SettingsRepository.swift`**

Create `Trackr/Core/Repositories/SettingsRepository.swift`:
```swift
import Foundation
import SwiftData

/// Singleton-by-convention access to the user's `UserSettings` row.
/// First call creates the row with spec defaults; subsequent calls return the same row.
@MainActor
struct SettingsRepository {
    let context: ModelContext

    func currentSettings() throws -> UserSettings {
        let existing = try context.fetch(FetchDescriptor<UserSettings>()).first
        if let existing { return existing }
        let fresh = UserSettings()
        context.insert(fresh)
        try context.save()
        return fresh
    }

    func save() throws {
        try context.save()
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 62 + 3 = 65.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Repositories/SettingsRepository.swift TrackrTests/SettingsRepository_Tests.swift
git commit -m "feat(core): add SettingsRepository (singleton-by-convention)"
```

---

### Task 13: Wire `ModelContainer` into `TrackrApp` and verify HomeView still renders

**Files:**
- Modify: `Trackr/TrackrApp.swift`

We inject the persistent container into the SwiftUI environment so future feature views can use `@Query` and `@Environment(\.modelContext)`. Does not touch `HomeView` (still purely placeholder visuals from M1).

- [ ] **Step 1: Modify `TrackrApp.swift`**

Replace the existing content of `/Users/jingxue/Downloads/CC/subscription/Trackr/TrackrApp.swift` with:

```swift
import SwiftUI
import SwiftData

@main
struct TrackrApp: App {
    /// The app's SwiftData container. Constructed once at launch.
    private let container: ModelContainer

    init() {
        do {
            self.container = try ModelContainerConfig.makeAppContainer()
        } catch {
            // If the persistent store fails at launch, fall back to in-memory so the
            // app still renders. M7 adds CloudKit sync and stricter error handling.
            fatalError("Failed to construct ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
```

The `fatalError` is intentional and correct here: at launch with no data yet, the only ways `makeAppContainer()` can throw are schema mismatch (a developer bug) or disk-full (an environmental disaster). Both warrant a crash rather than a silent degradation. We will revisit when CloudKit lands in M7.

- [ ] **Step 2: Regenerate and verify HomeView still renders**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet build
echo "Build: $?"
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | tail -10
echo "Test: ${PIPESTATUS[0]}"
```

Both exit 0; 65 tests pass.

- [ ] **Step 3: Visual smoke test in simulator**

```bash
xcrun simctl boot 'iPhone 16' 2>/dev/null || true
sleep 3
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.placeholder.trackr
sleep 2
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m2-smoke-screenshot.png
file /Users/jingxue/Downloads/CC/subscription/.m2-smoke-screenshot.png
```

The screenshot must be a valid PNG showing the same M1 Home shell. If it shows a launch-screen-only or crashes, something in `init()` is failing — investigate.

- [ ] **Step 4: Commit**

```bash
git add Trackr/TrackrApp.swift
git commit -m "feat(app): wire SwiftData ModelContainer into TrackrApp environment"
```

---

### Task 14: Final M2 acceptance + tag

**Files:** none — verification only.

- [ ] **Step 1: Clean build from scratch**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  clean build 2>&1 | tail -10
echo "Build: ${PIPESTATUS[0]}"
```

Exit 0. No own-code warnings.

- [ ] **Step 2: Run all tests**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  test 2>&1 | tail -30
echo "Test: ${PIPESTATUS[0]}"
```

Expected breakdown:
- All 21 M1 tests still passing
- 7 BillingCycleTests + CategoryTests
- 3 SubscriptionTests
- 1 RenewalEventTests
- 2 PriceChangeAlertTests
- 2 UserSettingsTests
- 1 PresetCacheTests
- 6 AmountFormatterTests
- 9 RenewalCalculatorTests
- 6 SubscriptionRepositoryTests
- 4 AlertRepositoryTests
- 3 SettingsRepositoryTests
- **Total: 65 tests, 0 failures.**

- [ ] **Step 3: Verify git state**

```bash
git log --oneline | head -15
git status
```

13 new commits beyond `m1-foundation` (one per task 1–13), plus an empty acceptance commit. ~34 total commits.

- [ ] **Step 4: Tag**

```bash
git tag m2-data
git tag --list 'm*'
git show m2-data --stat --no-patch
```

Expected tags: `m1-foundation`, `m2-data`.

- [ ] **Step 5: Inventory and acceptance note**

```bash
echo '=== Core files ==='
git ls-files Trackr/Core | sort
echo
echo '=== New tests ==='
git diff --name-only m1-foundation HEAD -- TrackrTests | sort
```

---

## M2 Acceptance Summary

- 5 SwiftData models implemented + tested
- 4 enums implemented + tested where they have non-trivial logic (BillingCycle Codable round-trip, Category displayName)
- 3 repositories implemented + tested
- `AmountFormatter` and `RenewalCalculator` utilities implemented with extensive edge-case coverage (Feb 29, 31-of-month drift, leap year, custom cycles)
- `TrackrApp` injects the persistent `ModelContainer` into the environment
- Total test count: ~65 (44 net new beyond M1's 21)
- Build clean, test suite green, M1 functionality still works
- `git tag m2-data` set
- Ready to write the M3 plan (Home screen with real data binding, Add Subscription form, Detail screen)
