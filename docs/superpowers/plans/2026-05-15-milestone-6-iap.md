# Milestone 6 — IAP, Paywall, Free / Pro Gating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A working StoreKit 2 integration that exposes a single `ProEntitlement` observable, a `FeatureGate` map deciding what free users can/can't do, a `PaywallView` triggered from the gated call sites, the free 5-subscription limit, Pro-only push notifications when the M5 price-change differ produces an alert, and a Pro-gated `InsightsView` scaffold.

**Architecture:**
- `StoreKitClient` is the narrow seam over StoreKit 2 — exposes "current entitlement", "purchase by product ID", "transaction updates stream", and "product display info". `SystemStoreKitClient` is the real wrapper; `FakeStoreKitClient` powers tests. `ProEntitlement` is an `@Observable @MainActor` class consuming the protocol; it owns the long-running transaction-updates task and writes the resolved `ProStatus` through to `UserSettings.proStatus` so the widget (M7) and `FeatureGate` callers can read a stable cached value.
- `FeatureGate` is a pure-Swift enum with one function: `isAllowed(_:given:)`. No protocols, no StoreKit awareness. Every gated call site reads `ProStatus` and asks the gate.
- The 5-subscription free-tier ceiling lives at the Add Subscription submit site (not the repository) — it needs both `ProStatus` and the current count, both already on the SwiftUI side. `SubscriptionLimitExceeded` (declared in M2 but unused) finally has a producer.
- `PaywallTriggerCoordinator` is an `@Observable` mailbox, mirroring M4's `AppDeepLinkRouter`: any call site that hits a Pro gate writes "show paywall" into it; `HomeView` watches and presents `PaywallView`.
- `PaywallView` shows two products (monthly + lifetime), feature bullets, and a Restore button. Purchase flows through `ProEntitlement.purchase(_:)`. Pricing strings come from `StoreKitClient.priceForDisplay(_:)`, so we don't hard-code them.
- `PriceChangePushPublisher` is a pure orchestrator: given a list of `PriceChangeAlert` and the current `ProStatus`, it asks the `NotificationCenterProtocol` to schedule one immediate notification per alert — but only when Pro. `PresetSync` calls it after persisting alerts.
- `InsightsView` is a Pro-gated scaffold: free users see a paywall stub; Pro users see monthly total / yearly total / sub count. We don't ship trend graphs in M6.
- A `Configuration.storekit` file at the repo root ships the two product definitions for local sandbox testing. The Trackr scheme references it via xcodegen.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData (iOS 17), StoreKit 2, `UserNotifications`, XCTest, swift-snapshot-testing. No new third-party deps.

---

## File Structure

After M6 the new code looks like this (only new + modified files shown):

```
Configuration.storekit                              # NEW — repo-root StoreKit config
Trackr/
├─ Core/
│  └─ IAP/
│     ├─ StoreKitClient.swift                       # NEW — protocol + display types
│     ├─ SystemStoreKitClient.swift                 # NEW — real StoreKit 2 wrapper
│     ├─ ProEntitlement.swift                       # NEW — @Observable entitlement
│     ├─ FeatureGate.swift                          # NEW — pure gating map
│     └─ PriceChangePushPublisher.swift             # NEW — Pro-only immediate notifs
└─ Features/
   ├─ Paywall/
   │  ├─ PaywallTriggerCoordinator.swift            # NEW — @Observable mailbox
   │  └─ PaywallView.swift                          # NEW — SwiftUI paywall
   ├─ Insights/
   │  └─ InsightsView.swift                         # NEW — Pro-gated insights stub
   ├─ AddSubscription/AddSubscriptionSheet.swift    # MODIFIED — 5-sub limit + paywall trigger
   ├─ Home/HomeView.swift                           # MODIFIED — Insights entry + paywall sheet
   └─ Routing/AppDeepLinkRouter.swift               # MODIFIED — env keys for entitlement + paywall

Trackr/Core/Presets/PresetSync.swift                # MODIFIED — calls PriceChangePushPublisher

Trackr/TrackrApp.swift                              # MODIFIED — instantiate ProEntitlement, paywall coordinator

project.yml                                         # MODIFIED — scheme storeKitConfiguration

TrackrTests/
├─ FakeStoreKitClient.swift                         # NEW — test fake
├─ ProEntitlement_Tests.swift
├─ FeatureGate_Tests.swift
├─ AddSubscriptionSheet_FreeTierLimit_Tests.swift
├─ PaywallTriggerCoordinator_Tests.swift
├─ PaywallView_Snapshot_Tests.swift
├─ PriceChangePushPublisher_Tests.swift
├─ PresetSync_ProPush_Tests.swift                   # extends T8 coverage at the orchestrator level
└─ InsightsView_Snapshot_Tests.swift
```

---

### Task 1: `StoreKitClient` protocol + system impl + test fake + `.storekit` config

**Files:**
- Create: `Trackr/Core/IAP/StoreKitClient.swift`
- Create: `Trackr/Core/IAP/SystemStoreKitClient.swift`
- Create: `TrackrTests/FakeStoreKitClient.swift`
- Create: `Configuration.storekit`
- Modify: `project.yml` (point the Trackr scheme at the `.storekit` config)

Narrow seam: tests inject `FakeStoreKitClient`; production wires `SystemStoreKitClient` against `StoreKit.Transaction`. We only need four methods plus a value type for display.

- [ ] **Step 1: Create the protocol + display struct**

Create `Trackr/Core/IAP/StoreKitClient.swift`:
```swift
import Foundation

/// Product display info pulled from the App Store (or local `.storekit` config).
/// `priceDisplay` is the already-formatted localized price string ("$2.99",
/// "¥21.00"); we never re-format it.
struct ProProductDisplay: Equatable {
    let productID: String
    let priceDisplay: String
}

/// Narrow seam over StoreKit 2. The whole IAP stack only touches the methods
/// declared here, so tests can inject `FakeStoreKitClient` and production
/// wires `SystemStoreKitClient`.
protocol StoreKitClient: AnyObject {

    /// Resolves the user's current Pro tier from their active entitlements.
    /// Returns `.free` when nothing is active.
    func currentEntitlement() async -> ProStatus

    /// Initiates a purchase. On success the resolved tier is returned. The
    /// caller is responsible for updating UI state and `UserSettings.proStatus`.
    func purchase(productID: String) async throws -> ProStatus

    /// Long-running stream of `ProStatus` values, one emitted for every
    /// `Transaction.updates` event. Used by `ProEntitlement` for live updates.
    func transactionUpdates() -> AsyncStream<ProStatus>

    /// Display info for both Pro products. Reads from the App Store / local
    /// `.storekit` config. Returns an empty array if products can't be loaded.
    func availableProducts() async -> [ProProductDisplay]
}

/// Product IDs for the two Pro tiers — kept here so `FeatureGate`, `PaywallView`,
/// and the StoreKit config all share one source of truth.
enum ProProductID {
    static let monthly  = "com.placeholder.trackr.pro.monthly"
    static let lifetime = "com.placeholder.trackr.pro.lifetime"
}
```

- [ ] **Step 2: Create the system implementation**

Create `Trackr/Core/IAP/SystemStoreKitClient.swift`:
```swift
import Foundation
import StoreKit

/// Production `StoreKitClient` implementation. Thin wrapper over StoreKit 2 —
/// no business logic; tests cover the consumers (`ProEntitlement`, the paywall).
final class SystemStoreKitClient: StoreKitClient {

    func currentEntitlement() async -> ProStatus {
        var resolved: ProStatus = .free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            switch txn.productID {
            case ProProductID.lifetime:
                return .proLifetime // strictly the highest tier — short-circuit
            case ProProductID.monthly:
                resolved = .proMonthly
            default:
                continue
            }
        }
        return resolved
    }

    func purchase(productID: String) async throws -> ProStatus {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw PurchaseError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let txn) = verification {
                await txn.finish()
            }
            return await currentEntitlement()
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    func transactionUpdates() -> AsyncStream<ProStatus> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    guard case .verified(let txn) = result else { continue }
                    await txn.finish()
                    let resolved = await self.currentEntitlement()
                    continuation.yield(resolved)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func availableProducts() async -> [ProProductDisplay] {
        let ids = [ProProductID.monthly, ProProductID.lifetime]
        guard let products = try? await Product.products(for: ids) else { return [] }
        return products.map { product in
            ProProductDisplay(productID: product.id,
                              priceDisplay: product.displayPrice)
        }
    }

    enum PurchaseError: Error, Equatable {
        case productNotFound
        case userCancelled
        case pending
        case unknown
    }
}
```

- [ ] **Step 3: Create the test fake**

Create `TrackrTests/FakeStoreKitClient.swift`:
```swift
import Foundation
@testable import Trackr

/// In-memory `StoreKitClient` for tests. Tests configure `currentResult`,
/// `purchaseResults`, and optionally feed values into `updatesContinuation`.
final class FakeStoreKitClient: StoreKitClient {

    var currentResult: ProStatus = .free
    var purchaseResults: [String: Result<ProStatus, Error>] = [:]
    var products: [ProProductDisplay] = []
    private(set) var purchaseCallCount = 0

    // Test handle for pumping live updates into the stream.
    var updatesContinuation: AsyncStream<ProStatus>.Continuation?

    func currentEntitlement() async -> ProStatus {
        currentResult
    }

    func purchase(productID: String) async throws -> ProStatus {
        purchaseCallCount += 1
        guard let result = purchaseResults[productID] else {
            struct Unconfigured: Error {}
            throw Unconfigured()
        }
        switch result {
        case .success(let status):
            currentResult = status
            return status
        case .failure(let error):
            throw error
        }
    }

    func transactionUpdates() -> AsyncStream<ProStatus> {
        AsyncStream { continuation in
            self.updatesContinuation = continuation
        }
    }

    func availableProducts() async -> [ProProductDisplay] {
        products
    }
}
```

- [ ] **Step 4: Create the StoreKit configuration**

Create `Configuration.storekit` at the repository root:
```json
{
  "identifier" : "trackr-iap-config",
  "nonRenewingSubscriptions" : [],
  "products" : [
    {
      "displayPrice" : "29.99",
      "familyShareable" : false,
      "internalID" : "F0E1D2C3",
      "localizations" : [
        {
          "description" : "One-time purchase — Pro features forever.",
          "displayName" : "Trackr Pro Lifetime",
          "locale" : "en_US"
        }
      ],
      "productID" : "com.placeholder.trackr.pro.lifetime",
      "referenceName" : "Pro Lifetime",
      "type" : "NonConsumable"
    }
  ],
  "settings" : {
    "_compatibilityTimeRate" : 1,
    "_locale" : "en_US",
    "_storefront" : "USA",
    "_storeKitErrors" : []
  },
  "subscriptionGroups" : [
    {
      "id" : "BA1A2B3C",
      "localizations" : [],
      "name" : "Trackr Pro",
      "subscriptions" : [
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "2.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "A1B2C3D4",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Auto-renewing monthly subscription with all Pro features.",
              "displayName" : "Trackr Pro Monthly",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.placeholder.trackr.pro.monthly",
          "recurringSubscriptionPeriod" : "P1M",
          "referenceName" : "Pro Monthly",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : {
    "major" : 4,
    "minor" : 0
  }
}
```

- [ ] **Step 5: Wire the `.storekit` file into the Trackr scheme**

Open `/Users/jingxue/Downloads/CC/subscription/project.yml`. xcodegen lets you set `storeKitConfiguration` under the scheme. Add (or extend) a `schemes:` block at the bottom of the file (above `packages:` if it exists, else at root level):

```yaml
schemes:
  Trackr:
    build:
      targets:
        Trackr: all
        TrackrTests: [test]
    run:
      config: Debug
      storeKitConfiguration: Configuration.storekit
    test:
      config: Debug
      targets:
        - TrackrTests
      storeKitConfiguration: Configuration.storekit
```

If a `schemes:` block already exists, merge the `storeKitConfiguration:` lines into it rather than duplicating.

Regenerate and confirm: `xcodegen generate`, then open the project's scheme settings and verify "Options → StoreKit Configuration" reads `Configuration.storekit` for both Run and Test phases.

- [ ] **Step 6: Run, verify the build is green**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 159 tests still green (no net new tests yet — Task 2 onwards adds them). `FakeStoreKitClient` adds zero tests on its own.

- [ ] **Step 7: Commit**

```bash
git add Configuration.storekit project.yml \
        Trackr/Core/IAP/StoreKitClient.swift \
        Trackr/Core/IAP/SystemStoreKitClient.swift \
        TrackrTests/FakeStoreKitClient.swift
git commit -m "feat(iap): add StoreKitClient protocol, system wrapper, test fake, .storekit config"
```

---

### Task 2: `ProEntitlement` (TDD)

**Files:**
- Create: `Trackr/Core/IAP/ProEntitlement.swift`
- Create: `TrackrTests/ProEntitlement_Tests.swift`

The runtime source of truth. On `start()`, it reads `currentEntitlement`, caches it as `current: ProStatus`, writes through to `UserSettings.proStatus`, and starts consuming `transactionUpdates()` for live changes. Tests pump values into `FakeStoreKitClient.updatesContinuation` and assert that `current` flips.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/ProEntitlement_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class ProEntitlementTests: XCTestCase {

    private var container: ModelContainer!
    private var client: FakeStoreKitClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        client = FakeStoreKitClient()
    }

    override func tearDownWithError() throws {
        container = nil
        client = nil
        try super.tearDownWithError()
    }

    func test_start_resolvesInitialEntitlement_andWritesToSettings() async throws {
        client.currentResult = .proLifetime

        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()

        XCTAssertEqual(entitlement.current, .proLifetime)
        let s = try SettingsRepository(context: container.mainContext).currentSettings()
        XCTAssertEqual(s.proStatus, .proLifetime,
                       "ProEntitlement should write through to UserSettings on start")
    }

    func test_purchase_flipsCurrent_andWritesSettings() async throws {
        client.purchaseResults[ProProductID.monthly] = .success(.proMonthly)

        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()

        try await entitlement.purchase(productID: ProProductID.monthly)
        XCTAssertEqual(entitlement.current, .proMonthly)
        XCTAssertEqual(client.purchaseCallCount, 1)
        let s = try SettingsRepository(context: container.mainContext).currentSettings()
        XCTAssertEqual(s.proStatus, .proMonthly)
    }

    func test_transactionUpdate_updatesCurrent() async throws {
        client.currentResult = .free
        let entitlement = ProEntitlement(client: client, container: container)
        await entitlement.start()
        XCTAssertEqual(entitlement.current, .free)

        // Pump an update through the fake's continuation. The listener task
        // ProEntitlement spawned in `start()` reads from this stream.
        client.updatesContinuation?.yield(.proLifetime)
        // Give the listener task a moment to consume the value.
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(entitlement.current, .proLifetime)
    }

    func test_availableProducts_passesThroughClient() async {
        client.products = [
            ProProductDisplay(productID: ProProductID.monthly, priceDisplay: "$2.99"),
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$29.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        let products = await entitlement.availableProducts()
        XCTAssertEqual(products.map(\.priceDisplay), ["$2.99", "$29.99"])
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

Expected: `cannot find 'ProEntitlement'`.

- [ ] **Step 3: Implement `ProEntitlement.swift`**

Create `Trackr/Core/IAP/ProEntitlement.swift`:
```swift
import Foundation
import Observation
import SwiftData

/// Runtime entitlement state. `current` is observable; SwiftUI views can
/// subscribe via `@Environment(ProEntitlement.self)`. Writes through to
/// `UserSettings.proStatus` on every change so widgets / cold-launch checks
/// have a cached value to read.
@Observable
@MainActor
final class ProEntitlement {

    private(set) var current: ProStatus = .free

    private let client: StoreKitClient
    private let container: ModelContainer
    private var listenerTask: Task<Void, Never>?

    init(client: StoreKitClient, container: ModelContainer) {
        self.client = client
        self.container = container
    }

    /// Resolves the initial entitlement and starts listening for updates.
    /// Idempotent — calling twice is a no-op.
    func start() async {
        if listenerTask != nil { return }
        let initial = await client.currentEntitlement()
        await update(to: initial)

        listenerTask = Task { [weak self] in
            guard let self else { return }
            for await status in await self.client.transactionUpdates() {
                await self.update(to: status)
            }
        }
    }

    func purchase(productID: String) async throws {
        let resolved = try await client.purchase(productID: productID)
        await update(to: resolved)
    }

    func availableProducts() async -> [ProProductDisplay] {
        await client.availableProducts()
    }

    deinit {
        listenerTask?.cancel()
    }

    // MARK: - private

    private func update(to status: ProStatus) async {
        current = status
        do {
            let settings = try SettingsRepository(context: container.mainContext)
                .currentSettings()
            settings.proStatus = status
            try container.mainContext.save()
        } catch {
            // Persisting the cache is best-effort; the in-memory `current`
            // is the authoritative source for the running session.
        }
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

Expected: 159 + 4 = 163 tests, **TEST SUCCEEDED**.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/IAP/ProEntitlement.swift TrackrTests/ProEntitlement_Tests.swift
git commit -m "feat(iap): add ProEntitlement observable with StoreKit client backing"
```

---

### Task 3: `FeatureGate` (TDD)

**Files:**
- Create: `Trackr/Core/IAP/FeatureGate.swift`
- Create: `TrackrTests/FeatureGate_Tests.swift`

Pure-Swift enum mapping `Feature` to the lowest tier that unlocks it. One public function: `isAllowed(_:given:)`. Also exports a single specialized helper `canAddSubscription(currentCount:proStatus:)` because that gate has a count parameter alongside the tier.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/FeatureGate_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class FeatureGateTests: XCTestCase {

    func test_unlimitedSubs_requiresPro() {
        XCTAssertFalse(FeatureGate.isAllowed(.unlimitedSubs, given: .free))
        XCTAssertTrue(FeatureGate.isAllowed(.unlimitedSubs, given: .proMonthly))
        XCTAssertTrue(FeatureGate.isAllowed(.unlimitedSubs, given: .proLifetime))
    }

    func test_pricePush_requiresPro() {
        XCTAssertFalse(FeatureGate.isAllowed(.pricePushNotifications, given: .free))
        XCTAssertTrue(FeatureGate.isAllowed(.pricePushNotifications, given: .proMonthly))
        XCTAssertTrue(FeatureGate.isAllowed(.pricePushNotifications, given: .proLifetime))
    }

    func test_insights_requiresPro() {
        XCTAssertFalse(FeatureGate.isAllowed(.insights, given: .free))
        XCTAssertTrue(FeatureGate.isAllowed(.insights, given: .proMonthly))
    }

    func test_canAddSubscription_freeUnder5_allowed() {
        XCTAssertTrue(FeatureGate.canAddSubscription(currentCount: 0, proStatus: .free))
        XCTAssertTrue(FeatureGate.canAddSubscription(currentCount: 4, proStatus: .free))
    }

    func test_canAddSubscription_freeAt5_blocked() {
        XCTAssertFalse(FeatureGate.canAddSubscription(currentCount: 5, proStatus: .free))
        XCTAssertFalse(FeatureGate.canAddSubscription(currentCount: 99, proStatus: .free))
    }

    func test_canAddSubscription_proAlwaysAllowed() {
        XCTAssertTrue(FeatureGate.canAddSubscription(currentCount: 100, proStatus: .proMonthly))
        XCTAssertTrue(FeatureGate.canAddSubscription(currentCount: 100, proStatus: .proLifetime))
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'FeatureGate'`.

- [ ] **Step 3: Implement `FeatureGate.swift`**

Create `Trackr/Core/IAP/FeatureGate.swift`:
```swift
import Foundation

/// Static map of features to the tier required to unlock them. No side effects,
/// no StoreKit dependency — every gated call site reads its `ProStatus` from
/// `ProEntitlement` / `UserSettings` and asks here.
enum FeatureGate {

    enum Feature {
        /// Unlimited subscriptions (free is capped at `freeSubscriptionLimit`).
        case unlimitedSubs
        /// Push notification fires whenever a `PriceChangeAlert` is generated.
        /// Free users still see the in-app banner; only Pro gets push.
        case pricePushNotifications
        /// Insights screen — totals + future trend charts.
        case insights
        /// CloudKit sync (M7 will gate the toggle on this).
        case iCloudSync
    }

    /// The hard cap on a free user's subscription count.
    static let freeSubscriptionLimit = 5

    static func isAllowed(_ feature: Feature, given status: ProStatus) -> Bool {
        switch status {
        case .free:
            return false
        case .proMonthly, .proLifetime:
            return true
        }
    }

    static func canAddSubscription(currentCount: Int, proStatus: ProStatus) -> Bool {
        if isAllowed(.unlimitedSubs, given: proStatus) { return true }
        return currentCount < freeSubscriptionLimit
    }
}
```

The current map is "everything Pro" / "nothing free" — the per-feature `case` exists so future tiers (e.g., a Family plan) can flip individual gates without touching call sites.

- [ ] **Step 4: Run, verify tests pass**

Expected: 163 + 6 = 169 tests.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/IAP/FeatureGate.swift TrackrTests/FeatureGate_Tests.swift
git commit -m "feat(iap): add FeatureGate with TDD"
```

---

### Task 4: Enforce 5-sub free-tier limit in `AddSubscriptionSheet.submit` (TDD)

**Files:**
- Modify: `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift`
- Create: `TrackrTests/AddSubscriptionSheet_FreeTierLimit_Tests.swift`
- Modify: `TrackrTests/AddSubscriptionSheet_Submit_Tests.swift` (add `proStatus: .free,` at call sites — or `.proLifetime` if you want the existing tests to bypass the gate)
- Modify: `TrackrTests/AddSubscriptionSheet_TabSwitch_Tests.swift` (same)
- Modify: `TrackrTests/NotificationWriteHooks_Tests.swift` (same)

`submit` grows two new optional parameters: `proStatus: ProStatus = .proLifetime` (default unblocks all existing test paths) and `onLimitExceeded: () -> Void = {}` (called when the gate trips so the UI can route to the paywall — wired in Task 7).

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/AddSubscriptionSheet_FreeTierLimit_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class AddSubscriptionSheetFreeTierLimitTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    private func seed(_ n: Int) throws {
        for i in 0..<n {
            let sub = Subscription(
                name: "Sub\(i)", amount: 1, currency: "USD",
                billingCycle: .monthly,
                nextBillingDate: .distantFuture, startDate: .now,
                category: .other
            )
            container.mainContext.insert(sub)
        }
        try container.mainContext.save()
    }

    func test_free_under5_allowsInsert() async throws {
        try seed(4)
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Fifth"
        draft.amountString = "1"

        var limitTripped = false
        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: nil,
            proStatus: .free,
            context: container.mainContext,
            coordinator: nil,
            onLimitExceeded: { limitTripped = true },
            onDismiss: {}
        )
        XCTAssertNil(result)
        XCTAssertFalse(limitTripped)
        XCTAssertEqual(try SubscriptionRepository(context: container.mainContext).count(), 5)
    }

    func test_free_at5_blocksAndCallsLimitHook() async throws {
        try seed(5)
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Sixth"
        draft.amountString = "1"

        var limitTripped = false
        var dismissed = false
        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: nil,
            proStatus: .free,
            context: container.mainContext,
            coordinator: nil,
            onLimitExceeded: { limitTripped = true },
            onDismiss: { dismissed = true }
        )
        XCTAssertNotNil(result, "should return user-facing message")
        XCTAssertTrue(limitTripped)
        XCTAssertFalse(dismissed)
        XCTAssertEqual(try SubscriptionRepository(context: container.mainContext).count(), 5,
                       "no sub was added")
    }

    func test_pro_at5_stillAllowed() async throws {
        try seed(5)
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Sixth"
        draft.amountString = "1"

        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            presetId: nil,
            proStatus: .proLifetime,
            context: container.mainContext,
            coordinator: nil,
            onLimitExceeded: {},
            onDismiss: {}
        )
        XCTAssertNil(result)
        XCTAssertEqual(try SubscriptionRepository(context: container.mainContext).count(), 6)
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `submit` doesn't accept `proStatus` / `onLimitExceeded` yet.

- [ ] **Step 3: Update `AddSubscriptionSheet.submit`**

Open `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift`. Replace the existing static `submit(draft:presetId:context:coordinator:onDismiss:)` with the expanded signature:

```swift
    @discardableResult
    static func submit(draft: SubscriptionDraft,
                       presetId: String? = nil,
                       proStatus: ProStatus = .proLifetime,
                       context: ModelContext,
                       coordinator: NotificationCoordinator? = nil,
                       onLimitExceeded: () -> Void = {},
                       onDismiss: () -> Void) async -> String? {
        do {
            // Free-tier gate.
            let count = try SubscriptionRepository(context: context).count()
            if !FeatureGate.canAddSubscription(currentCount: count, proStatus: proStatus) {
                onLimitExceeded()
                return "Free tier is limited to \(FeatureGate.freeSubscriptionLimit) subscriptions. Upgrade to Pro for unlimited."
            }

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

The default `proStatus: .proLifetime` means existing tests that don't care about the gate keep compiling and passing without changes. The defaults for `onLimitExceeded` and `onDismiss` mirror what M3/M4 already required.

Also update `attemptSave()` (the instance method on the struct that fires SAVE) to forward the live entitlement. Read the current `attemptSave` implementation, then update:

```swift
    @Environment(ProEntitlement.self) private var entitlement
    // ... add this alongside the existing @Environment properties.

    private func attemptSave() {
        Task {
            if let msg = await Self.submit(draft: draft,
                                            presetId: pendingPresetId,
                                            proStatus: entitlement.current,
                                            context: context,
                                            coordinator: coordinator,
                                            onLimitExceeded: handleLimitExceeded,
                                            onDismiss: { dismiss() }) {
                errorMessage = msg
            } else {
                errorMessage = nil
            }
        }
    }

    private func handleLimitExceeded() {
        // Task 7 fills this in — for now leave a no-op so the build is green.
    }
```

(`@Environment(ProEntitlement.self)` requires `ProEntitlement` to conform to `Observable`, which it does because it's `@Observable`.)

- [ ] **Step 4: Update existing `submit` callers in tests**

Three test files invoke `AddSubscriptionSheet.submit`:
- `TrackrTests/AddSubscriptionSheet_Submit_Tests.swift`
- `TrackrTests/AddSubscriptionSheet_TabSwitch_Tests.swift`
- `TrackrTests/NotificationWriteHooks_Tests.swift`

Each call site uses keyword arguments. The new parameters have defaults (`proStatus: .proLifetime`, `onLimitExceeded: {}`), so existing tests compile unchanged. **Verify by running the suite** — if any test file no longer compiles, insert `proStatus: .proLifetime,` between the existing `presetId:` and `context:` arguments at that one call site.

- [ ] **Step 5: Update the snapshot host helpers**

The existing `AddSubscriptionSheet` snapshot tests (`AddSubscriptionSheet_Snapshot_Tests.swift`) instantiate the view without a `ProEntitlement` in the environment. Now that the view reads `@Environment(ProEntitlement.self)`, those snapshots will crash with "No ProEntitlement found in environment".

Update `TrackrTests/AddSubscriptionSheet_Snapshot_Tests.swift` to inject a stub:
```swift
    private func host(initial: SubscriptionDraft = .empty(defaultCurrency: "USD")) -> some View {
        let entitlement = ProEntitlement(client: FakeStoreKitClient(), container: container)
        return AddSubscriptionSheet(initialDraft: initial)
            .modelContainer(container)
            .environment(entitlement)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }
```

Delete the stale baselines so they re-record (the picker layout from M5 should look identical, but if the body changed, this surfaces the diff):
```bash
rm TrackrTests/__Snapshots__/AddSubscriptionSheet_Snapshot_Tests/*.png
```

- [ ] **Step 6: Run, verify tests pass (record snapshots twice)**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/AddSubscriptionSheetSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 169 + 3 = 172 tests, **TEST SUCCEEDED**.

- [ ] **Step 7: Commit**

```bash
git add Trackr/Features/AddSubscription/AddSubscriptionSheet.swift \
        TrackrTests/AddSubscriptionSheet_FreeTierLimit_Tests.swift \
        TrackrTests/AddSubscriptionSheet_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/AddSubscriptionSheet_Snapshot_Tests
git commit -m "feat(iap): enforce free 5-subscription limit in submit, surface paywall hook"
```

---

### Task 5: `PaywallTriggerCoordinator` mailbox + environment key (TDD)

**Files:**
- Create: `Trackr/Features/Paywall/PaywallTriggerCoordinator.swift`
- Modify: `Trackr/Features/Routing/AppDeepLinkRouter.swift` (append env key for entitlement + paywall coordinator)
- Create: `TrackrTests/PaywallTriggerCoordinator_Tests.swift`

Mirrors `AppDeepLinkRouter`: an `@Observable @MainActor` mailbox with a single flag.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/PaywallTriggerCoordinator_Tests.swift`:
```swift
import XCTest
@testable import Trackr

@MainActor
final class PaywallTriggerCoordinatorTests: XCTestCase {

    func test_initialState_notShowing() {
        let coordinator = PaywallTriggerCoordinator()
        XCTAssertFalse(coordinator.isShowing)
        XCTAssertNil(coordinator.reason)
    }

    func test_present_setsFlagAndReason() {
        let coordinator = PaywallTriggerCoordinator()
        coordinator.present(reason: .subscriptionLimit)
        XCTAssertTrue(coordinator.isShowing)
        XCTAssertEqual(coordinator.reason, .subscriptionLimit)
    }

    func test_dismiss_clearsState() {
        let coordinator = PaywallTriggerCoordinator()
        coordinator.present(reason: .insightsLocked)
        coordinator.dismiss()
        XCTAssertFalse(coordinator.isShowing)
        XCTAssertNil(coordinator.reason)
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'PaywallTriggerCoordinator'`.

- [ ] **Step 3: Implement `PaywallTriggerCoordinator.swift`**

Create `Trackr/Features/Paywall/PaywallTriggerCoordinator.swift`:
```swift
import Foundation
import Observation

/// One-shot mailbox for "show the paywall". Gated call sites call `present(reason:)`;
/// `HomeView` watches `isShowing` and presents `PaywallView`.
@Observable
@MainActor
final class PaywallTriggerCoordinator {

    enum Reason: Equatable {
        case subscriptionLimit
        case insightsLocked
        case pushNotificationsLocked
        case iCloudSyncLocked
        case manual    // user tapped "Upgrade" without a gate trip
    }

    private(set) var isShowing = false
    private(set) var reason: Reason?

    func present(reason: Reason) {
        self.reason = reason
        self.isShowing = true
    }

    func dismiss() {
        isShowing = false
        reason = nil
    }
}
```

- [ ] **Step 4: Append env keys for `ProEntitlement` and `PaywallTriggerCoordinator`**

Open `Trackr/Features/Routing/AppDeepLinkRouter.swift`. Append below the existing `PresetSyncKey` block:

```swift
private struct ProEntitlementKey: EnvironmentKey {
    static let defaultValue: ProEntitlement? = nil
}

extension EnvironmentValues {
    var proEntitlement: ProEntitlement? {
        get { self[ProEntitlementKey.self] }
        set { self[ProEntitlementKey.self] = newValue }
    }
}

private struct PaywallTriggerCoordinatorKey: EnvironmentKey {
    static let defaultValue: PaywallTriggerCoordinator? = nil
}

extension EnvironmentValues {
    var paywallTrigger: PaywallTriggerCoordinator? {
        get { self[PaywallTriggerCoordinatorKey.self] }
        set { self[PaywallTriggerCoordinatorKey.self] = newValue }
    }
}
```

Note: we also pass `ProEntitlement` via `@Environment(ProEntitlement.self)` (the `@Observable`-typed environment that Task 4 uses). The `\.proEntitlement` env key is for places that need to know whether one exists at all (snapshot tests can pass `nil`). Both forms coexist.

- [ ] **Step 5: Run, verify tests pass**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 172 + 3 = 175 tests.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Paywall/PaywallTriggerCoordinator.swift \
        Trackr/Features/Routing/AppDeepLinkRouter.swift \
        TrackrTests/PaywallTriggerCoordinator_Tests.swift
git commit -m "feat(iap): add PaywallTriggerCoordinator with env keys"
```

---

### Task 6: `PaywallView` (snapshot)

**Files:**
- Create: `Trackr/Features/Paywall/PaywallView.swift`
- Create: `TrackrTests/PaywallView_Snapshot_Tests.swift`

A sheet shown by `HomeView` when `PaywallTriggerCoordinator.isShowing` is true. Renders:
- Header: "TRACKR PRO" + close button.
- Hero copy: "Unlock the full library."
- Feature bullets: unlimited subs, price-change push, insights, iCloud sync.
- Two product cards: Monthly + Lifetime, with prices from `entitlement.availableProducts()`.
- Restore button at the bottom.

- [ ] **Step 1: Write the failing snapshot test**

Create `TrackrTests/PaywallView_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class PaywallViewSnapshotTests: XCTestCase {

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

    private func host() -> some View {
        let client = FakeStoreKitClient()
        client.products = [
            ProProductDisplay(productID: ProProductID.monthly,  priceDisplay: "$2.99"),
            ProProductDisplay(productID: ProProductID.lifetime, priceDisplay: "$29.99"),
        ]
        let entitlement = ProEntitlement(client: client, container: container)
        return PaywallView(reason: .subscriptionLimit)
            .modelContainer(container)
            .environment(entitlement)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_paywall_render() {
        assertSnapshot(of: host(), as: .image)
    }
}
```

- [ ] **Step 2: Run, expect build / baseline missing**

Expected: `cannot find 'PaywallView'`.

- [ ] **Step 3: Implement `PaywallView.swift`**

Create `Trackr/Features/Paywall/PaywallView.swift`:
```swift
import SwiftUI

struct PaywallView: View {

    let reason: PaywallTriggerCoordinator.Reason

    @Environment(ProEntitlement.self) private var entitlement
    @Environment(\.dismiss) private var dismiss

    @State private var products: [ProProductDisplay] = []
    @State private var purchaseInFlight = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        hero
                        DashedDivider()
                        featureList
                        productCards
                        if let errorMessage {
                            PixelText(errorMessage.uppercased(),
                                      size: TrackrTypography.Scale.caption,
                                      color: TrackrColors.warn,
                                      tracking: 1.5)
                        }
                        TrackrButton("RESTORE PURCHASES", variant: .outlined) {
                            Task { await restore() }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .task { products = await entitlement.availableProducts() }
    }

    private var header: some View {
        HStack {
            Button("CLOSE") { dismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            PixelText("TRACKR PRO", size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(20)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            PixelText(headline(for: reason).uppercased(),
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            Text(subhead(for: reason))
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow("UNLIMITED SUBSCRIPTIONS")
            featureRow("PUSH NOTIFICATIONS ON PRICE CHANGES")
            featureRow("INSIGHTS DASHBOARD")
            featureRow("iCLOUD SYNC ACROSS DEVICES")
        }
    }

    private func featureRow(_ label: String) -> some View {
        HStack(spacing: 8) {
            PixelText("✓",
                      size: TrackrTypography.Scale.value,
                      color: TrackrColors.accent, tracking: 0)
            PixelText(label,
                      size: TrackrTypography.Scale.body,
                      tracking: 1.5)
        }
    }

    private var productCards: some View {
        VStack(spacing: 12) {
            productCard(productID: ProProductID.lifetime,
                        title: "LIFETIME",
                        subtitle: "ONE-TIME PURCHASE")
            productCard(productID: ProProductID.monthly,
                        title: "MONTHLY",
                        subtitle: "AUTO-RENEWS · CANCEL ANYTIME")
        }
    }

    private func productCard(productID: String,
                             title: String,
                             subtitle: String) -> some View {
        let price = products.first(where: { $0.productID == productID })?.priceDisplay ?? "—"
        return Button {
            Task { await purchase(productID: productID) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    PixelText(title,
                              size: TrackrTypography.Scale.title,
                              tracking: 2)
                    Spacer()
                    PixelText(price,
                              size: TrackrTypography.Scale.title,
                              color: TrackrColors.accent,
                              tracking: 1)
                }
                PixelText(subtitle,
                          size: TrackrTypography.Scale.sectionLabel,
                          color: TrackrColors.fg2, tracking: 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(purchaseInFlight)
    }

    private func headline(for reason: PaywallTriggerCoordinator.Reason) -> String {
        switch reason {
        case .subscriptionLimit:        return "Hit the 5-sub limit?"
        case .insightsLocked:           return "Insights are Pro"
        case .pushNotificationsLocked:  return "Push notifications are Pro"
        case .iCloudSyncLocked:         return "Sync is Pro"
        case .manual:                   return "Go Pro"
        }
    }

    private func subhead(for reason: PaywallTriggerCoordinator.Reason) -> String {
        switch reason {
        case .subscriptionLimit:        return "Pro removes the cap and unlocks everything below."
        case .insightsLocked:           return "Spend totals, trends, and category breakdowns."
        case .pushNotificationsLocked:  return "Get notified the moment a service changes its price."
        case .iCloudSyncLocked:         return "Keep your subscriptions in sync across every device."
        case .manual:                   return "One purchase. Every feature, forever."
        }
    }

    private func purchase(productID: String) async {
        guard !purchaseInFlight else { return }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            try await entitlement.purchase(productID: productID)
            dismiss()
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    private func restore() async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        // SystemStoreKitClient reads `Transaction.currentEntitlements` on every
        // `currentEntitlement()` call, so triggering an update via the listener
        // is enough. We re-read here as a defensive double-check.
        await entitlement.refresh()
        errorMessage = nil
    }
}
```

Note: `ProEntitlement.refresh()` doesn't exist yet. Add it to `Trackr/Core/IAP/ProEntitlement.swift`:
```swift
    /// Force a re-read of the current entitlement. Used by "Restore purchases".
    func refresh() async {
        let resolved = await client.currentEntitlement()
        await update(to: resolved)
    }
```

- [ ] **Step 4: Build snapshots twice (record + verify)**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/PaywallViewSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/PaywallViewSnapshotTests 2>&1 | tail -3
```

Second run: 1 test passes. The PaywallView's `.task` populates `products` from the fake client, so prices render as "$2.99" / "$29.99".

- [ ] **Step 5: Run full suite**

Expected: 175 + 1 = 176 tests.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Paywall/PaywallView.swift \
        Trackr/Core/IAP/ProEntitlement.swift \
        TrackrTests/PaywallView_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/PaywallView_Snapshot_Tests
git commit -m "feat(iap): add PaywallView with product cards and restore"
```

---

### Task 7: Wire `PaywallView` into `HomeView`; route limit-trip from Add sheet

**Files:**
- Modify: `Trackr/Features/Home/HomeView.swift`
- Modify: `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift`
- Modify: `Trackr/TrackrApp.swift` (instantiate `ProEntitlement` + `PaywallTriggerCoordinator`)
- Modify: `TrackrTests/HomeView_Snapshot_Tests.swift` (inject the new env values; delete stale baselines)
- Modify: `TrackrTests/DesignSystemSnapshot_Tests.swift` (its `test_homeView_iPhone15` host needs the same env values)

- [ ] **Step 1: Update `TrackrApp.swift`**

Read it first. Then replace the file's contents with:
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
    private let entitlement: ProEntitlement
    private let paywallTrigger: PaywallTriggerCoordinator

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

        let catalogURL = URL(string: "https://presets.invalid/trackr/v1/presets.json")!
        self.presetSync = PresetSync(
            fetcher: URLSessionPresetFetcher(catalogURL: catalogURL),
            container: container
        )

        self.entitlement = ProEntitlement(client: SystemStoreKitClient(), container: container)
        self.paywallTrigger = PaywallTriggerCoordinator()
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
}
```

- [ ] **Step 2: Update `HomeView` to present `PaywallView`**

In `Trackr/Features/Home/HomeView.swift`:

(a) Add new environment properties near the existing ones:
```swift
    @Environment(ProEntitlement.self) private var entitlement
    @Environment(PaywallTriggerCoordinator.self) private var paywallTrigger
```

(b) Append a `.sheet` for the paywall and an `.onChange` that watches the trigger — add right before the existing `.task` modifier at the end of the outer `ZStack`:
```swift
        .sheet(isPresented: Binding(
            get: { paywallTrigger.isShowing },
            set: { newValue in if !newValue { paywallTrigger.dismiss() } }
        )) {
            PaywallView(reason: paywallTrigger.reason ?? .manual)
                .modelContext(context)
                .environment(entitlement)
        }
```

- [ ] **Step 3: Update `AddSubscriptionSheet.handleLimitExceeded`**

Replace the stub `handleLimitExceeded` in `AddSubscriptionSheet.swift` with:
```swift
    @Environment(PaywallTriggerCoordinator.self) private var paywallTrigger
    // Add this alongside the other environment properties.

    private func handleLimitExceeded() {
        paywallTrigger.present(reason: .subscriptionLimit)
        // The error message is also surfaced inline by submit()'s return value,
        // so the user sees both the paywall and the inline message.
        dismiss()
    }
```

- [ ] **Step 4: Update snapshot test hosts to inject the new env values**

In `TrackrTests/HomeView_Snapshot_Tests.swift`, update `host()`:
```swift
    private func host() -> some View {
        let client = FakeStoreKitClient()
        let entitlement = ProEntitlement(client: client, container: container)
        return HomeView()
            .modelContainer(container)
            .environment(AppDeepLinkRouter())
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }
```

In `TrackrTests/DesignSystemSnapshot_Tests.swift`, locate `test_homeView_iPhone15` and add the same three `.environment(...)` injections (creating fresh instances).

In `TrackrTests/AddSubscriptionSheet_Snapshot_Tests.swift`, the host now also needs the paywall trigger:
```swift
    private func host(initial: SubscriptionDraft = .empty(defaultCurrency: "USD")) -> some View {
        let entitlement = ProEntitlement(client: FakeStoreKitClient(), container: container)
        return AddSubscriptionSheet(initialDraft: initial)
            .modelContainer(container)
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }
```

- [ ] **Step 5: Re-record stale baselines and run the suite**

```bash
rm TrackrTests/__Snapshots__/HomeView_Snapshot_Tests/*.png
rm TrackrTests/__Snapshots__/DesignSystemSnapshot_Tests/test_homeView_iPhone15.1.png
rm TrackrTests/__Snapshots__/AddSubscriptionSheet_Snapshot_Tests/*.png
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

The first run re-records baselines and may report failures; the second verifies. Expected: 176 tests still pass.

- [ ] **Step 6: Commit**

```bash
git add Trackr/TrackrApp.swift \
        Trackr/Features/Home/HomeView.swift \
        Trackr/Features/AddSubscription/AddSubscriptionSheet.swift \
        TrackrTests/HomeView_Snapshot_Tests.swift \
        TrackrTests/DesignSystemSnapshot_Tests.swift \
        TrackrTests/AddSubscriptionSheet_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/HomeView_Snapshot_Tests \
        TrackrTests/__Snapshots__/DesignSystemSnapshot_Tests \
        TrackrTests/__Snapshots__/AddSubscriptionSheet_Snapshot_Tests
git commit -m "feat(iap): install ProEntitlement + paywall in TrackrApp, present from HomeView"
```

---

### Task 8: `PriceChangePushPublisher` (TDD) + Pro-only push from `PresetSync`

**Files:**
- Create: `Trackr/Core/IAP/PriceChangePushPublisher.swift`
- Modify: `Trackr/Core/Presets/PresetSync.swift`
- Create: `TrackrTests/PriceChangePushPublisher_Tests.swift`
- Create: `TrackrTests/PresetSync_ProPush_Tests.swift`

The publisher takes a list of alerts and the current `ProStatus`. For each alert, if `FeatureGate.isAllowed(.pricePushNotifications, given: status)`, it builds a `UNNotificationRequest` with no trigger (immediate delivery) and adds it via `NotificationCenterProtocol`. Free users get no push (the in-app banner from M5 still fires).

`PresetSync` gains an optional `pushPublisher: PriceChangePushPublisher?` and calls it inside `run()` after `AlertRepository.insert(_:)`.

- [ ] **Step 1: Write the failing publisher tests**

Create `TrackrTests/PriceChangePushPublisher_Tests.swift`:
```swift
import XCTest
import UserNotifications
@testable import Trackr

@MainActor
final class PriceChangePushPublisherTests: XCTestCase {

    private func alert(presetId: String = "a") -> PriceChangeAlert {
        PriceChangeAlert(
            presetId: presetId, planKey: "Standard",
            oldAmount: 10, newAmount: 12,
            currency: "USD",
            effectiveDate: .now,
            messageEn: "Service A raised its Standard price from $10.00 to $12.00.",
            messageZh: "Service A Standard 价格已上调，由 $10.00 变为 $12.00。",
            seenAt: nil
        )
    }

    func test_pro_schedulesOneNotificationPerAlert() async throws {
        let fake = FakeNotificationCenter()
        let pub = PriceChangePushPublisher(center: fake)
        try await pub.publish(alerts: [alert(presetId: "a"), alert(presetId: "b")],
                              proStatus: .proLifetime)
        XCTAssertEqual(fake.addedRequests.count, 2)
        XCTAssertTrue(fake.addedRequests[0].content.body.contains("Service A"))
    }

    func test_free_schedulesNothing() async throws {
        let fake = FakeNotificationCenter()
        let pub = PriceChangePushPublisher(center: fake)
        try await pub.publish(alerts: [alert()], proStatus: .free)
        XCTAssertEqual(fake.addedRequests.count, 0)
    }

    func test_proMonthly_alsoSchedules() async throws {
        let fake = FakeNotificationCenter()
        let pub = PriceChangePushPublisher(center: fake)
        try await pub.publish(alerts: [alert()], proStatus: .proMonthly)
        XCTAssertEqual(fake.addedRequests.count, 1)
    }
}
```

- [ ] **Step 2: Implement `PriceChangePushPublisher.swift`**

Create `Trackr/Core/IAP/PriceChangePushPublisher.swift`:
```swift
import Foundation
import UserNotifications

/// Fires one immediate local notification per price-change alert — but only
/// when the user is on a Pro tier (`FeatureGate.pricePushNotifications`).
/// Free users still see the in-app banner from M5; this layer adds the push.
@MainActor
final class PriceChangePushPublisher {

    private let center: NotificationCenterProtocol

    init(center: NotificationCenterProtocol) {
        self.center = center
    }

    func publish(alerts: [PriceChangeAlert], proStatus: ProStatus) async throws {
        guard FeatureGate.isAllowed(.pricePushNotifications, given: proStatus) else { return }
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = "Price change"
            content.body = alert.messageEn
            content.sound = .default
            content.userInfo = ["presetId": alert.presetId]
            // No trigger → deliver immediately.
            let request = UNNotificationRequest(
                identifier: "trackr.price-change.\(alert.id.uuidString.lowercased())",
                content: content,
                trigger: nil
            )
            try await center.add(request)
        }
    }
}
```

- [ ] **Step 3: Wire the publisher into `PresetSync`**

Open `Trackr/Core/Presets/PresetSync.swift`. Read it first. Modify the initializer + `run()`:

Add a property and init parameter:
```swift
    private let pushPublisher: PriceChangePushPublisher?

    init(fetcher: PresetFetcher,
         container: ModelContainer,
         bundle: Bundle = .main,
         pushPublisher: PriceChangePushPublisher? = nil) {
        self.fetcher = fetcher
        self.container = container
        self.bundle = bundle
        self.pushPublisher = pushPublisher
    }
```

In `run()`, after the existing alert-insertion loop (`for alert in alerts { try alertRepo.insert(alert) }`), add:
```swift
        // Pro-only push for each new alert. Free users see only the in-app banner.
        if let pushPublisher {
            let settings = try SettingsRepository(context: context).currentSettings()
            try await pushPublisher.publish(alerts: alerts, proStatus: settings.proStatus)
        }
```

- [ ] **Step 4: Add an orchestrator-level test**

Create `TrackrTests/PresetSync_ProPush_Tests.swift`:
```swift
import XCTest
import SwiftData
import UserNotifications
@testable import Trackr

@MainActor
final class PresetSyncProPushTests: XCTestCase {

    private var container: ModelContainer!
    private var fetcher: FakePresetFetcher!
    private var notificationCenter: FakeNotificationCenter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        fetcher = FakePresetFetcher()
        notificationCenter = FakeNotificationCenter()
    }

    override func tearDownWithError() throws {
        notificationCenter = nil
        fetcher = nil
        container = nil
        try super.tearDownWithError()
    }

    private func seedSettings(proStatus: ProStatus) throws {
        let s = try SettingsRepository(context: container.mainContext).currentSettings()
        s.proStatus = proStatus
        try container.mainContext.save()
    }

    private func seedSubAndCache() throws {
        let sub = Subscription(
            name: "X", amount: 10, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now,
            category: .media, presetId: "a"
        )
        container.mainContext.insert(sub)
        let initial = try JSONDecoder().decode(PresetCatalog.self,
            from: Data(#"""
            {"version":"1.0.0","items":[{"id":"a","name":"Service A","defaultPlanName":"S","defaultAmount":"10","defaultCurrency":"USD","defaultCycle":"monthly","category":"media","iconRef":"preset:a"}]}
            """#.utf8))
        let cache = PresetCache(version: "1.0.0", fetchedAt: .now,
                                data: try JSONEncoder().encode(initial))
        container.mainContext.insert(cache)
        try container.mainContext.save()
    }

    func test_pro_pricesChange_firesPush() async throws {
        try seedSubAndCache()
        try seedSettings(proStatus: .proLifetime)
        fetcher.result = try JSONDecoder().decode(PresetCatalog.self,
            from: Data(#"""
            {"version":"1.1.0","items":[{"id":"a","name":"Service A","defaultPlanName":"S","defaultAmount":"12","defaultCurrency":"USD","defaultCycle":"monthly","category":"media","iconRef":"preset:a"}]}
            """#.utf8))

        let publisher = PriceChangePushPublisher(center: notificationCenter)
        let sync = PresetSync(fetcher: fetcher,
                              container: container,
                              pushPublisher: publisher)
        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(notificationCenter.addedRequests.count, 1,
                       "Pro user should get one push per alert")
    }

    func test_free_pricesChange_noPush() async throws {
        try seedSubAndCache()
        try seedSettings(proStatus: .free)
        fetcher.result = try JSONDecoder().decode(PresetCatalog.self,
            from: Data(#"""
            {"version":"1.1.0","items":[{"id":"a","name":"Service A","defaultPlanName":"S","defaultAmount":"12","defaultCurrency":"USD","defaultCycle":"monthly","category":"media","iconRef":"preset:a"}]}
            """#.utf8))

        let publisher = PriceChangePushPublisher(center: notificationCenter)
        let sync = PresetSync(fetcher: fetcher,
                              container: container,
                              pushPublisher: publisher)
        try await sync.run(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(notificationCenter.addedRequests.count, 0)
    }
}
```

- [ ] **Step 5: Wire the publisher into `TrackrApp`**

In `TrackrApp.swift`'s `init`, after constructing `coordinator`, also construct the publisher and pass it to `presetSync`:
```swift
        let pushPublisher = PriceChangePushPublisher(center: SystemNotificationCenter())
        self.presetSync = PresetSync(
            fetcher: URLSessionPresetFetcher(catalogURL: catalogURL),
            container: container,
            pushPublisher: pushPublisher
        )
```

- [ ] **Step 6: Run, verify tests pass**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 176 + 3 + 2 = 181 tests.

- [ ] **Step 7: Commit**

```bash
git add Trackr/Core/IAP/PriceChangePushPublisher.swift \
        Trackr/Core/Presets/PresetSync.swift \
        Trackr/TrackrApp.swift \
        TrackrTests/PriceChangePushPublisher_Tests.swift \
        TrackrTests/PresetSync_ProPush_Tests.swift
git commit -m "feat(iap): Pro-only push notifications on price-change alerts"
```

---

### Task 9: `InsightsView` (Pro-gated snapshot)

**Files:**
- Create: `Trackr/Features/Insights/InsightsView.swift`
- Create: `TrackrTests/InsightsView_Snapshot_Tests.swift`

V1 insights: monthly total + yearly total + active sub count. Gated behind Pro — free users see a paywall stub with a CTA button.

- [ ] **Step 1: Write the failing snapshot tests**

Create `TrackrTests/InsightsView_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class InsightsViewSnapshotTests: XCTestCase {

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

    private func seed(_ subs: [(String, Decimal, BillingCycle)]) throws {
        for (name, amount, cycle) in subs {
            let sub = Subscription(
                name: name, amount: amount, currency: "USD",
                billingCycle: cycle,
                nextBillingDate: .distantFuture, startDate: .now,
                category: .media
            )
            container.mainContext.insert(sub)
        }
        try container.mainContext.save()
    }

    private func host(proStatus: ProStatus) -> some View {
        let client = FakeStoreKitClient()
        client.currentResult = proStatus
        let entitlement = ProEntitlement(client: client, container: container)
        return InsightsView()
            .modelContainer(container)
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_freeUser_showsPaywallStub() {
        assertSnapshot(of: host(proStatus: .free), as: .image)
    }

    func test_proUser_showsTotals() throws {
        try seed([
            ("Netflix", 15.49, .monthly),
            ("iCloud",   0.99, .monthly),
            ("AnnualThing", 120, .yearly),
        ])
        assertSnapshot(of: host(proStatus: .proLifetime), as: .image)
    }
}
```

- [ ] **Step 2: Run, expect build failure**

Expected: `cannot find 'InsightsView'`.

- [ ] **Step 3: Implement `InsightsView.swift`**

Create `Trackr/Features/Insights/InsightsView.swift`:
```swift
import SwiftUI
import SwiftData

/// Pro-gated insights dashboard. V1 shows totals only — trends and category
/// breakdowns ship in a later milestone.
struct InsightsView: View {

    @Environment(ProEntitlement.self) private var entitlement
    @Environment(PaywallTriggerCoordinator.self) private var paywallTrigger
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Subscription.nextBillingDate, order: .forward)
    private var subscriptions: [Subscription]

    private var currentCurrency: String {
        do {
            return try SettingsRepository(context: context).currentSettings().defaultCurrency
        } catch {
            return "USD"
        }
    }

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    if FeatureGate.isAllowed(.insights, given: entitlement.current) {
                        proBody
                    } else {
                        lockedBody
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button("CLOSE") { dismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            PixelText("INSIGHTS", size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(20)
    }

    private var proBody: some View {
        let currency = currentCurrency
        let monthly = MonthlyTotalCalculator.total(of: subscriptions, in: currency)
        let yearly = monthly * 12
        let count = subscriptions.filter { $0.isActive }.count
        return VStack(alignment: .leading, spacing: 24) {
            metricCard(label: "MONTHLY",
                       value: AmountFormatter.format(monthly, currency: currency))
            metricCard(label: "YEARLY",
                       value: AmountFormatter.format(yearly, currency: currency))
            metricCard(label: "ACTIVE SUBS",
                       value: "\(count)")
        }
        .padding(20)
    }

    private func metricCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(label,
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(value,
                      size: TrackrTypography.Scale.hero,
                      tracking: 1)
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var lockedBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            PixelText("INSIGHTS ARE PRO",
                      size: TrackrTypography.Scale.title, tracking: 2)
            Text("Upgrade to Trackr Pro to see totals, trends, and category breakdowns.")
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            TrackrButton("UPGRADE") {
                paywallTrigger.present(reason: .insightsLocked)
            }
        }
        .padding(20)
    }
}

#Preview { InsightsView() }
```

- [ ] **Step 4: Build snapshots twice (record + verify)**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/InsightsViewSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/InsightsViewSnapshotTests 2>&1 | tail -3
```

Second run: 2 tests pass.

- [ ] **Step 5: Run full suite**

Expected: 181 + 2 = 183 tests.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Insights/InsightsView.swift \
        TrackrTests/InsightsView_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/InsightsView_Snapshot_Tests
git commit -m "feat(iap): add Pro-gated InsightsView with totals"
```

---

### Task 10: Wire Insights entry, E2E, tag

**Files:**
- Modify: `Trackr/Features/Home/HomeView.swift` — make the hamburger (`≡`) icon present `InsightsView`
- Modify: `TrackrTests/HomeView_Snapshot_Tests.swift` (only if a re-record is needed — likely not, the icon was already there)

- [ ] **Step 1: Wire the hamburger icon**

In `Trackr/Features/Home/HomeView.swift`:

(a) Add a state flag near the existing ones:
```swift
    @State private var showingInsights = false
```

(b) Replace the hamburger overlay block in `topBar` (the `Color.clear.frame(width: 32, height: 32)` chain showing `≡`) with:
```swift
                Button { showingInsights = true } label: {
                    Color.clear.frame(width: 32, height: 32)
                        .overlay(PixelText("≡", size: 14, color: TrackrColors.fg2, tracking: 0))
                        .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
```

(c) Add a sheet for it, placed alongside the existing `.sheet(isPresented: $showingSettings) { ... }` block:
```swift
        .sheet(isPresented: $showingInsights) {
            InsightsView()
                .modelContext(context)
                .environment(entitlement)
                .environment(paywallTrigger)
        }
```

- [ ] **Step 2: Re-record HomeView baselines if needed**

The hamburger icon gaining a tappable hit area shouldn't change rendered pixels, so the existing baselines should hold. If they fail:
```bash
rm TrackrTests/__Snapshots__/HomeView_Snapshot_Tests/*.png
rm TrackrTests/__Snapshots__/DesignSystemSnapshot_Tests/test_homeView_iPhone15.1.png
```
…and re-run the targeted snapshot suite twice (first run records, second verifies).

- [ ] **Step 3: Clean build + full suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  clean build 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 183 tests, **TEST SUCCEEDED**.

- [ ] **Step 4: Manual smoke in the simulator**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
xcrun simctl boot 'iPhone 16' 2>/dev/null || true
xcrun simctl uninstall booted com.placeholder.trackr 2>/dev/null || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.placeholder.trackr
sleep 2
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m6-home.png
```

Then in the simulator, by hand (with the StoreKit config in the run scheme):
1. Tap the FAB and create 5 subscriptions via CUSTOM. The 6th attempt should show the inline limit message AND the paywall sheet.
2. On the paywall, tap LIFETIME. The local StoreKit prompt appears → approve. Sheet dismisses. Try adding a 6th sub again — it should now succeed.
3. Tap the hamburger icon. Insights shows monthly / yearly / count cards.
4. On a fresh install (uninstall + reinstall), Insights for a free user shows the "INSIGHTS ARE PRO" stub + UPGRADE button. Tapping it opens the paywall.

- [ ] **Step 5: Tag**

```bash
git tag m6-iap
git tag --list 'm*'
git show m6-iap --stat --no-patch
```

Expected tags: `m1-foundation`, `m2-data`, `m3-crud-ui`, `m4-notifications`, `m5-presets`, `m6-iap`.

- [ ] **Step 6: Acceptance inventory**

```bash
echo '=== M6 new core files ==='
git ls-files Trackr/Core/IAP
echo
echo '=== M6 new feature files ==='
git diff --name-only m5-presets HEAD -- Trackr/Features
echo
echo '=== Test files added since m5-presets ==='
git diff --name-only m5-presets HEAD -- TrackrTests | sort
echo
echo '=== Commit count m5-presets..HEAD ==='
git rev-list m5-presets..HEAD --count
```

---

## M6 Acceptance Summary

- 5 IAP types under `Trackr/Core/IAP/`: `StoreKitClient` protocol + `SystemStoreKitClient`, `FakeStoreKitClient` for tests, `ProEntitlement` (`@Observable`), `FeatureGate` (pure), `PriceChangePushPublisher` (Pro-gated immediate-delivery push).
- `Configuration.storekit` defines monthly ($2.99 auto-renewing) and lifetime ($29.99 non-consumable) products; the Trackr scheme references it for both Run and Test.
- 2 paywall types under `Trackr/Features/Paywall/`: `PaywallTriggerCoordinator` (`@Observable` mailbox) and `PaywallView` (snapshot-tested).
- `Trackr/Features/Insights/InsightsView` — Pro-gated; free users see a paywall stub.
- `AddSubscriptionSheet.submit` enforces the free 5-sub limit and calls `onLimitExceeded` so the sheet can surface the paywall.
- `PresetSync` calls `PriceChangePushPublisher` after persisting alerts — Pro users get a local push per alert; free users only see the in-app banner.
- `TrackrApp` instantiates `ProEntitlement`, `PaywallTriggerCoordinator`, `PriceChangePushPublisher`, and starts the entitlement listener via `.task`.
- Net new tests: 24 (4 ProEntitlement + 6 FeatureGate + 3 FreeTierLimit + 3 PaywallTrigger + 1 PaywallView snapshot + 3 PriceChangePushPublisher + 2 PresetSync_ProPush + 2 InsightsView snapshot). Total: **183 tests, 0 failures**.
- `git tag m6-iap` set. Ready to scope M7 (Widget + iCloud sync, Pro-gated).
