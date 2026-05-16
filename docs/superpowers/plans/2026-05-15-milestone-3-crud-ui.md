# Milestone 3 — Core CRUD UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** End-to-end create / read / update / delete of subscriptions via the iOS UI. Home shows the real list; FAB opens an Add sheet (CUSTOM tab only — the preset library is M5); rows navigate to a Detail screen that supports edit, pause/resume, and delete.

**Architecture:**
- Pure-logic types stay in `Trackr/Core/`. `MonthlyTotalCalculator` normalizes each `BillingCycle` to a per-month figure in a single currency; multi-currency aggregation is a V2 concern, so we filter to the user's `defaultCurrency` and ignore the rest. `SubscriptionDraft` is a plain struct that mirrors the form fields and exposes a `validate()` pure function; this lets us TDD validation without touching SwiftUI.
- Feature views live in `Trackr/Features/`. `HomeView` reads a sorted `@Query<Subscription>` directly (no view-model layer — `@Model` types are observable enough). `SubscriptionRow`, `AddSubscriptionSheet`, and `SubscriptionDetailView` are dumb subviews that take their data via parameters / `@Bindable` so they snapshot-test cleanly.
- All persistence still goes through the M2 repositories. The Add sheet writes via `SubscriptionRepository.insert`; Detail edits commit via `context.save()` on the `@Bindable` `Subscription`; deletes use `SubscriptionRepository.delete`. The 5-sub free-tier gate stays disabled — its enforcement lands in M6.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData (`@Query`, `@Bindable`, `@Environment(\.modelContext)`), XCTest, swift-snapshot-testing (already added). No new third-party dependencies.

---

## File Structure

After M3 the new code looks like this (only new + modified files shown):

```
Trackr/Core/
├─ Cycle/
│  └─ MonthlyTotalCalculator.swift     # NEW — pure aggregation
├─ Forms/
│  └─ SubscriptionDraft.swift          # NEW — form model + validation

Trackr/Features/
├─ Home/
│  ├─ HomeView.swift                   # MODIFIED — @Query, hero total, empty / populated, FAB action, navigation
│  └─ SubscriptionRow.swift            # NEW — list-row component
├─ AddSubscription/
│  └─ AddSubscriptionSheet.swift       # NEW — sheet form
└─ Detail/
   └─ SubscriptionDetailView.swift     # NEW — read / edit / pause / delete

TrackrTests/
├─ MonthlyTotalCalculator_Tests.swift     # NEW
├─ SubscriptionDraft_Tests.swift          # NEW
├─ SubscriptionRow_Snapshot_Tests.swift   # NEW
├─ HomeView_Snapshot_Tests.swift          # NEW
├─ AddSubscriptionSheet_Snapshot_Tests.swift  # NEW
└─ SubscriptionDetailView_Snapshot_Tests.swift # NEW
```

The repository, model, and design-system code from M1/M2 is untouched.

---

### Task 1: `MonthlyTotalCalculator` (TDD)

**Files:**
- Create: `Trackr/Core/Cycle/MonthlyTotalCalculator.swift`
- Create: `TrackrTests/MonthlyTotalCalculator_Tests.swift`

Pure function that sums active subscriptions of a single currency into a monthly-equivalent `Decimal`. Per the spec, multi-currency aggregation is deferred — anything whose `currency` does not match the requested one is filtered out, and inactive subs are skipped. Custom-day cycles convert with the formula `amount × 30 / days` so a 60-day plan reads as half its amount per month; that matches user intuition closely enough for a hero figure.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/MonthlyTotalCalculator_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class MonthlyTotalCalculatorTests: XCTestCase {

    private func sub(
        _ amount: Decimal,
        currency: String = "USD",
        cycle: BillingCycle = .monthly,
        active: Bool = true
    ) -> Subscription {
        Subscription(
            name: "X",
            amount: amount,
            currency: currency,
            billingCycle: cycle,
            nextBillingDate: .distantFuture,
            startDate: .distantPast,
            category: .other,
            isActive: active
        )
    }

    func test_empty_returnsZero() {
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [], in: "USD"), 0)
    }

    func test_singleMonthly_returnsAmount() {
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(20)], in: "USD"), 20)
    }

    func test_yearly_dividesByTwelve() {
        // 120 / 12 = 10
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(120, cycle: .yearly)], in: "USD"), 10)
    }

    func test_weekly_multipliesBy52over12() {
        // 12 * 52 / 12 = 52
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(12, cycle: .weekly)], in: "USD"), 52)
    }

    func test_customDays60_isHalfPerMonth() {
        // 100 * 30 / 60 = 50
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(100, cycle: .customDays(60))], in: "USD"), 50)
    }

    func test_customDays_zeroOrNegative_isIgnored() {
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(100, cycle: .customDays(0))], in: "USD"), 0)
        XCTAssertEqual(MonthlyTotalCalculator.total(of: [sub(100, cycle: .customDays(-7))], in: "USD"), 0)
    }

    func test_differentCurrency_isExcluded() {
        let list = [sub(10, currency: "USD"), sub(99, currency: "CNY")]
        XCTAssertEqual(MonthlyTotalCalculator.total(of: list, in: "USD"), 10)
    }

    func test_inactive_isExcluded() {
        XCTAssertEqual(
            MonthlyTotalCalculator.total(of: [sub(10, active: false)], in: "USD"),
            0
        )
    }

    func test_mixedCycles_areSummed() {
        // 20 (monthly) + 120/12 (yearly=10) + 12*52/12 (weekly=52) = 82
        let list = [
            sub(20),
            sub(120, cycle: .yearly),
            sub(12, cycle: .weekly),
        ]
        XCTAssertEqual(MonthlyTotalCalculator.total(of: list, in: "USD"), 82)
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
Expected: build error `cannot find 'MonthlyTotalCalculator' in scope`.

- [ ] **Step 3: Implement `MonthlyTotalCalculator.swift`**

Create `Trackr/Core/Cycle/MonthlyTotalCalculator.swift`:
```swift
import Foundation

/// Sums a collection of `Subscription` into a per-month `Decimal` total in one
/// currency. Multi-currency aggregation is deliberately deferred: subscriptions
/// whose `currency` differs from `targetCurrency` are skipped, as are paused or
/// inactive subscriptions. Custom-day cycles are converted via `amount * 30 / days`,
/// which is the closest user-intuitive approximation without introducing a calendar.
enum MonthlyTotalCalculator {

    static func total(of subs: [Subscription], in targetCurrency: String) -> Decimal {
        let target = targetCurrency.uppercased()
        return subs.reduce(into: Decimal(0)) { running, sub in
            guard sub.isActive, sub.currency.uppercased() == target else { return }
            running += monthlyEquivalent(amount: sub.amount, cycle: sub.billingCycle)
        }
    }

    private static func monthlyEquivalent(amount: Decimal, cycle: BillingCycle) -> Decimal {
        switch cycle {
        case .monthly:
            return amount
        case .yearly:
            return amount / 12
        case .weekly:
            return amount * 52 / 12
        case .customDays(let days):
            guard days > 0 else { return 0 }
            return amount * 30 / Decimal(days)
        }
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```
Expected: previous suite count + 9 new tests, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Cycle/MonthlyTotalCalculator.swift TrackrTests/MonthlyTotalCalculator_Tests.swift
git commit -m "feat(core): add MonthlyTotalCalculator with TDD coverage"
```

---

### Task 2: `SubscriptionDraft` form model (TDD)

**Files:**
- Create: `Trackr/Core/Forms/SubscriptionDraft.swift`
- Create: `TrackrTests/SubscriptionDraft_Tests.swift`

Plain struct that mirrors the editable subset of `Subscription`. The Add sheet binds to it; on submit we run `validate()` and (if successful) translate to a real `Subscription`. Keeping this pure means the form's correctness can be tested with no SwiftUI / SwiftData involvement.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/SubscriptionDraft_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class SubscriptionDraftTests: XCTestCase {

    private func validDraft() -> SubscriptionDraft {
        SubscriptionDraft(
            name: "Netflix",
            amountString: "9.99",
            currency: "USD",
            billingCycle: .monthly,
            customDays: 30,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .media
        )
    }

    func test_validDraft_validatesAndBuildsSubscription() throws {
        let draft = validDraft()
        let sub = try draft.makeSubscription()
        XCTAssertEqual(sub.name, "Netflix")
        XCTAssertEqual(sub.amount, Decimal(string: "9.99"))
        XCTAssertEqual(sub.currency, "USD")
        XCTAssertEqual(sub.billingCycle, .monthly)
        XCTAssertEqual(sub.category, .media)
    }

    func test_emptyName_isInvalid() {
        var draft = validDraft()
        draft.name = "   "
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .emptyName)
        }
    }

    func test_nonNumericAmount_isInvalid() {
        var draft = validDraft()
        draft.amountString = "abc"
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .invalidAmount)
        }
    }

    func test_negativeAmount_isInvalid() {
        var draft = validDraft()
        draft.amountString = "-5"
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .invalidAmount)
        }
    }

    func test_zeroAmount_isInvalid() {
        var draft = validDraft()
        draft.amountString = "0"
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .invalidAmount)
        }
    }

    func test_customCycle_usesCustomDays() throws {
        var draft = validDraft()
        draft.billingCycle = .customDays(1) // placeholder; struct should read customDays field
        draft.customDays = 45
        let sub = try draft.makeSubscription()
        XCTAssertEqual(sub.billingCycle, .customDays(45))
    }

    func test_customCycle_zeroDays_isInvalid() {
        var draft = validDraft()
        draft.billingCycle = .customDays(1)
        draft.customDays = 0
        XCTAssertThrowsError(try draft.makeSubscription()) { error in
            XCTAssertEqual(error as? SubscriptionDraft.ValidationError, .invalidCustomDays)
        }
    }

    func test_initialNextBillingDate_equalsStartDate() throws {
        let draft = validDraft()
        let sub = try draft.makeSubscription()
        XCTAssertEqual(sub.nextBillingDate, sub.startDate)
    }

    func test_initialEmpty_factoryHasSpecDefaults() {
        let empty = SubscriptionDraft.empty(defaultCurrency: "CNY")
        XCTAssertEqual(empty.currency, "CNY")
        XCTAssertEqual(empty.billingCycle, .monthly)
        XCTAssertEqual(empty.category, .other)
        XCTAssertTrue(empty.name.isEmpty)
        XCTAssertEqual(empty.amountString, "")
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Same xcodebuild command. Expected: `cannot find 'SubscriptionDraft'`.

- [ ] **Step 3: Implement `SubscriptionDraft.swift`**

Create `Trackr/Core/Forms/SubscriptionDraft.swift`:
```swift
import Foundation

/// Editable form model behind the Add / Edit Subscription forms. Keeps everything
/// as plain Swift so the form's validation can be unit-tested without touching
/// SwiftUI or SwiftData.
struct SubscriptionDraft: Equatable {
    var name: String
    var planName: String
    var amountString: String
    var currency: String
    var billingCycle: BillingCycle
    /// Used only when `billingCycle == .customDays(_)`. Stored separately so the
    /// picker can switch between cycles without losing the user's typed value.
    var customDays: Int
    var startDate: Date
    var category: Category
    var notes: String
    var urlString: String

    enum ValidationError: Error, Equatable {
        case emptyName
        case invalidAmount
        case invalidCustomDays
    }

    static func empty(defaultCurrency: String) -> SubscriptionDraft {
        SubscriptionDraft(
            name: "",
            planName: "",
            amountString: "",
            currency: defaultCurrency,
            billingCycle: .monthly,
            customDays: 30,
            startDate: .now,
            category: .other,
            notes: "",
            urlString: ""
        )
    }

    /// Builds a real `Subscription`. Throws `ValidationError` if any rule fails.
    /// `nextBillingDate` defaults to `startDate` because the first billing is the
    /// start. M4's `RenewalCalculator` advances it whenever the user marks the
    /// cycle paid.
    func makeSubscription() throws -> Subscription {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ValidationError.emptyName }

        guard let amount = Decimal(string: amountString), amount > 0 else {
            throw ValidationError.invalidAmount
        }

        let resolvedCycle: BillingCycle
        if case .customDays = billingCycle {
            guard customDays > 0 else { throw ValidationError.invalidCustomDays }
            resolvedCycle = .customDays(customDays)
        } else {
            resolvedCycle = billingCycle
        }

        return Subscription(
            name: trimmedName,
            planName: planName.isEmpty ? nil : planName,
            amount: amount,
            currency: currency.uppercased(),
            billingCycle: resolvedCycle,
            nextBillingDate: startDate,
            startDate: startDate,
            category: category,
            notes: notes.isEmpty ? nil : notes,
            url: URL(string: urlString)
        )
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Same xcodebuild. Expected: previous + 9 tests, **TEST SUCCEEDED**.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Forms TrackrTests/SubscriptionDraft_Tests.swift
git commit -m "feat(core): add SubscriptionDraft form model with validation"
```

---

### Task 3: `SubscriptionRow` component (snapshot)

**Files:**
- Create: `Trackr/Features/Home/SubscriptionRow.swift`
- Create: `TrackrTests/SubscriptionRow_Snapshot_Tests.swift`

One row in the Home list: monogram icon · name + plan · cycle hint · amount. Pure rendering — no state, no callbacks. Snapshot-tested in light + paused states.

- [ ] **Step 1: Write the failing snapshot test**

Create `TrackrTests/SubscriptionRow_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class SubscriptionRowSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    private func make(name: String, plan: String? = nil, amount: Decimal,
                      cycle: BillingCycle = .monthly, active: Bool = true) -> Subscription {
        Subscription(
            name: name,
            planName: plan,
            amount: amount,
            currency: "USD",
            billingCycle: cycle,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .media,
            isActive: active
        )
    }

    private func host(_ sub: Subscription) -> some View {
        SubscriptionRow(subscription: sub)
            .frame(width: 360, height: 72)
            .background(TrackrColors.bg)
    }

    func test_activeRow_render() {
        assertSnapshot(of: host(make(name: "Netflix", plan: "Standard", amount: 15.49)),
                       as: .image)
    }

    func test_pausedRow_render() {
        assertSnapshot(of: host(make(name: "Spotify", amount: 9.99, active: false)),
                       as: .image)
    }

    func test_customDaysCycle_render() {
        assertSnapshot(of: host(make(name: "Box60", amount: 30, cycle: .customDays(60))),
                       as: .image)
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'SubscriptionRow'`.

- [ ] **Step 3: Implement `SubscriptionRow.swift`**

Create `Trackr/Features/Home/SubscriptionRow.swift`:
```swift
import SwiftUI

/// One subscription as it appears in the Home list. Stateless — accepts the
/// model directly and renders. Tapping is handled by the parent `NavigationLink`.
struct SubscriptionRow: View {

    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            MonoSquareIcon(monogram: monogram)
                .opacity(subscription.isActive ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 2) {
                PixelText(subscription.name.uppercased(),
                          size: TrackrTypography.Scale.value,
                          tracking: 1.5)
                PixelText(cycleLine,
                          size: TrackrTypography.Scale.sectionLabel,
                          color: TrackrColors.fg2,
                          tracking: 1.5)
            }

            Spacer()

            PixelText(AmountFormatter.format(subscription.amount, currency: subscription.currency),
                      size: TrackrTypography.Scale.value,
                      color: subscription.isActive ? TrackrColors.fg : TrackrColors.fg3,
                      tracking: 1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private var monogram: String {
        let trimmed = subscription.name.trimmingCharacters(in: .whitespaces)
        let letters = trimmed.unicodeScalars.compactMap { CharacterSet.letters.contains($0) ? Character($0) : nil }
        return String(letters.prefix(2)).uppercased()
    }

    private var cycleLine: String {
        let cycle: String
        switch subscription.billingCycle {
        case .monthly:           cycle = "MONTHLY"
        case .yearly:            cycle = "YEARLY"
        case .weekly:            cycle = "WEEKLY"
        case .customDays(let d): cycle = "EVERY \(d) DAYS"
        }
        if let plan = subscription.planName, !plan.isEmpty {
            return "\(cycle) · \(plan.uppercased())"
        }
        return cycle
    }
}
```

Note: `MonoSquareIcon` already exists from M1; verify it accepts a `monogram:` parameter. If the existing initializer differs, adapt the call site to match — do not modify the component.

- [ ] **Step 4: Run, generate snapshots (first run records, second run verifies)**

```bash
xcodegen generate
# First run: records baseline images
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SubscriptionRowSnapshotTests 2>&1 | tail -5
# Second run: verifies against baseline (should pass)
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SubscriptionRowSnapshotTests 2>&1 | tail -5
```

Expected on second run: 3 tests pass.

- [ ] **Step 5: Visually review the recorded snapshots**

```bash
ls TrackrTests/__Snapshots__/SubscriptionRowSnapshotTests/
# Open one to eyeball it:
open TrackrTests/__Snapshots__/SubscriptionRowSnapshotTests/test_activeRow_render.1.png
```

The row should show monogram square on the left, white name + grey cycle line, right-aligned amount. Confirm before committing.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Home/SubscriptionRow.swift TrackrTests/SubscriptionRow_Snapshot_Tests.swift TrackrTests/__Snapshots__/SubscriptionRowSnapshotTests
git commit -m "feat(home): add SubscriptionRow with snapshot baselines"
```

---

### Task 4: `HomeView` rewrite — `@Query` + hero total + navigation hook

**Files:**
- Modify: `Trackr/Features/Home/HomeView.swift`
- Create: `TrackrTests/HomeView_Snapshot_Tests.swift`

Replace the M1 placeholder with a real list. Hero number reads the user's `defaultCurrency` from `UserSettings` and runs `MonthlyTotalCalculator` over the `@Query` result. Empty state stays the same when the list is empty. FAB and rows wire into the navigation work that lands in Task 5 / 7; for now we hook them to local `@State` flags so the snapshot tests can compose the view in isolation.

- [ ] **Step 1: Write the failing snapshot test**

Create `TrackrTests/HomeView_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class HomeViewSnapshotTests: XCTestCase {

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

    private func seed(_ subs: [Subscription]) throws {
        let ctx = container.mainContext
        for s in subs { ctx.insert(s) }
        try ctx.save()
    }

    private func host() -> some View {
        HomeView()
            .modelContainer(container)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_emptyState_render() {
        assertSnapshot(of: host(), as: .image)
    }

    func test_populated_render() throws {
        try seed([
            Subscription(name: "Netflix", amount: 15.49, currency: "USD",
                         billingCycle: .monthly,
                         nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
                         startDate: Date(timeIntervalSince1970: 1_700_000_000),
                         category: .media),
            Subscription(name: "iCloud", amount: 0.99, currency: "USD",
                         billingCycle: .monthly,
                         nextBillingDate: Date(timeIntervalSince1970: 1_760_000_000),
                         startDate: Date(timeIntervalSince1970: 1_700_000_000),
                         category: .cloud),
        ])
        assertSnapshot(of: host(), as: .image)
    }
}
```

- [ ] **Step 2: Run, expect baseline-missing failures**

Expected: 2 tests fail with "no reference snapshot" — they record on first run. Re-run to verify pass.

- [ ] **Step 3: Replace `HomeView.swift`**

Replace the entire contents of `Trackr/Features/Home/HomeView.swift` with:
```swift
import SwiftUI
import SwiftData

/// Home screen. Lists the user's active subscriptions in `nextBillingDate` order
/// and shows the monthly-equivalent total in the user's default currency.
struct HomeView: View {

    @Query(sort: \Subscription.nextBillingDate, order: .forward)
    private var subscriptions: [Subscription]

    @Environment(\.modelContext) private var context

    @State private var showingAdd = false
    @State private var selected: Subscription?

    /// Resolved lazily — `SettingsRepository` creates the row on first access.
    private var defaultCurrency: String {
        do {
            let repo = SettingsRepository(context: context)
            return try repo.currentSettings().defaultCurrency
        } catch {
            return "USD"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TrackrColors.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer().frame(height: 24)
                heroAmount
                Spacer().frame(height: 20)
                DashedDivider()
                Spacer().frame(height: 8)
                content
                Spacer()
            }
            .padding(.horizontal, 20)

            FloatingActionButton(action: { showingAdd = true })
                .padding(24)
        }
        .sheet(isPresented: $showingAdd) {
            AddSubscriptionSheet()
                .modelContext(context)
        }
        .sheet(item: $selected) { sub in
            SubscriptionDetailView(subscription: sub)
                .modelContext(context)
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Rectangle().fill(TrackrColors.accent).frame(width: 8, height: 8)
                PixelText("TRACKR", size: TrackrTypography.Scale.title, tracking: 3)
            }
            Spacer()
            HStack(spacing: 14) {
                Color.clear.frame(width: 32, height: 32)
                    .overlay(PixelText("≡", size: 14, color: TrackrColors.fg2, tracking: 0))
                    .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
                Color.clear.frame(width: 32, height: 32)
                    .overlay(PixelText("⚙", size: 14, color: TrackrColors.fg2, tracking: 0))
                    .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
            }
        }
    }

    private var heroAmount: some View {
        let total = MonthlyTotalCalculator.total(of: subscriptions, in: defaultCurrency)
        return VStack(alignment: .leading, spacing: 6) {
            PixelText("MONTHLY · \(defaultCurrency.uppercased())",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText(AmountFormatter.format(total, currency: defaultCurrency),
                      size: TrackrTypography.Scale.hero,
                      tracking: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if subscriptions.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(subscriptions) { sub in
                        Button { selected = sub } label: {
                            SubscriptionRow(subscription: sub)
                        }
                        .buttonStyle(.plain)
                        DashedDivider()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 60)
            PixelText("NO SUBS\nTRACKED",
                      size: TrackrTypography.Scale.title,
                      color: TrackrColors.fg3,
                      tracking: 3)
                .multilineTextAlignment(.center)
            Text("Tap + to add your first subscription")
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.caption))
                .foregroundStyle(TrackrColors.fg3)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview { HomeView() }
```

This file references `AddSubscriptionSheet` (Task 5) and `SubscriptionDetailView` (Task 7) that do not exist yet. To keep the build green between tasks, add placeholder stubs at the bottom of this file — you will delete them when the real types land:

```swift
// MARK: - Temporary stubs (removed in Tasks 5/7)
struct AddSubscriptionSheet: View {
    var body: some View { Text("AddSubscriptionSheet stub") }
}

struct SubscriptionDetailView: View {
    let subscription: Subscription
    var body: some View { Text("Detail stub: \(subscription.name)") }
}
```

- [ ] **Step 4: Build + run the snapshot tests twice to record then verify**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/HomeViewSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/HomeViewSnapshotTests 2>&1 | tail -3
```

Second run expected: 2 tests pass.

- [ ] **Step 5: Visual smoke test**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
xcrun simctl install booted "$APP_PATH" 2>/dev/null
xcrun simctl launch booted com.placeholder.trackr
sleep 2
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m3-home-empty.png
```

Confirm the empty state still matches M2's smoke screenshot (only difference: hero currency now reads from `UserSettings`, which defaults to USD).

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Home/HomeView.swift TrackrTests/HomeView_Snapshot_Tests.swift TrackrTests/__Snapshots__/HomeViewSnapshotTests
git commit -m "feat(home): bind HomeView to @Query with monthly total and navigation hooks"
```

---

### Task 5: `AddSubscriptionSheet` — form layout + draft binding (snapshot)

**Files:**
- Create: `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift`
- Create: `TrackrTests/AddSubscriptionSheet_Snapshot_Tests.swift`
- Modify: `Trackr/Features/Home/HomeView.swift` (delete the `AddSubscriptionSheet` stub)

We build the form first (read-only snapshot of the empty + a pre-filled state); the submit hook lands in Task 6.

- [ ] **Step 1: Write the failing snapshot test**

Create `TrackrTests/AddSubscriptionSheet_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class AddSubscriptionSheetSnapshotTests: XCTestCase {

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

    private func host(initial: SubscriptionDraft = .empty(defaultCurrency: "USD")) -> some View {
        AddSubscriptionSheet(initialDraft: initial)
            .modelContainer(container)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_emptyForm_render() {
        assertSnapshot(of: host(), as: .image)
    }

    func test_filledForm_render() {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Notion"
        draft.amountString = "8.00"
        draft.category = .productivity
        draft.planName = "Personal Pro"
        assertSnapshot(of: host(initial: draft), as: .image)
    }
}
```

- [ ] **Step 2: Run, expect build / missing-baseline failure**

- [ ] **Step 3: Implement `AddSubscriptionSheet.swift`**

Create `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift`:
```swift
import SwiftUI
import SwiftData

/// The CUSTOM tab of the Add Subscription sheet. Library tab is M5.
struct AddSubscriptionSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draft: SubscriptionDraft
    @State private var errorMessage: String?

    /// Production callers use the default initializer. The `initialDraft` overload
    /// is for snapshot tests that need to render a pre-filled form.
    init(initialDraft: SubscriptionDraft? = nil) {
        if let initialDraft {
            _draft = State(initialValue: initialDraft)
        } else {
            _draft = State(initialValue: .empty(defaultCurrency: "USD"))
        }
    }

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().background(TrackrColors.border)
                ScrollView {
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
                    .padding(20)
                }
                footer
            }
        }
        .onAppear {
            if draft.currency.isEmpty {
                draft = SubscriptionDraft.empty(
                    defaultCurrency: (try? SettingsRepository(context: context).currentSettings().defaultCurrency) ?? "USD"
                )
            }
        }
    }

    private var header: some View {
        HStack {
            Button("CANCEL") { dismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            PixelText("ADD SUB", size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            Button("SAVE") { /* wired in Task 6 */ }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.accent)
        }
        .padding(20)
    }

    private var nameField: some View {
        labeled("NAME") {
            TextField("", text: $draft.name)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
        }
    }

    private var amountAndCurrency: some View {
        HStack(spacing: 16) {
            labeled("AMOUNT") {
                TextField("0.00", text: $draft.amountString)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
                    .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
            }
            labeled("CCY") {
                TextField("USD", text: $draft.currency)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
                    .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                    .frame(width: 64)
            }
        }
    }

    private var cycleField: some View {
        labeled("CYCLE") {
            Picker("", selection: $draft.billingCycle) {
                Text("MONTHLY").tag(BillingCycle.monthly)
                Text("YEARLY").tag(BillingCycle.yearly)
                Text("WEEKLY").tag(BillingCycle.weekly)
                Text("CUSTOM").tag(BillingCycle.customDays(draft.customDays))
            }
            .pickerStyle(.segmented)
            if case .customDays = draft.billingCycle {
                HStack {
                    PixelText("EVERY", size: TrackrTypography.Scale.caption, color: TrackrColors.fg2, tracking: 1.5)
                    TextField("30", value: $draft.customDays, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .foregroundStyle(TrackrColors.fg)
                        .frame(width: 60)
                    PixelText("DAYS", size: TrackrTypography.Scale.caption, color: TrackrColors.fg2, tracking: 1.5)
                }
            }
        }
    }

    private var startDateField: some View {
        labeled("STARTS") {
            DatePicker("", selection: $draft.startDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
        }
    }

    private var categoryField: some View {
        labeled("CATEGORY") {
            Picker("", selection: $draft.category) {
                ForEach(Category.allCases, id: \.self) { cat in
                    Text(cat.displayName.uppercased()).tag(cat)
                }
            }
            .pickerStyle(.menu)
            .tint(TrackrColors.fg)
        }
    }

    private var planNameField: some View {
        labeled("PLAN") {
            TextField("optional", text: $draft.planName)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
        }
    }

    private var notesField: some View {
        labeled("NOTES") {
            TextField("optional", text: $draft.notes, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
        }
    }

    private var urlField: some View {
        labeled("URL") {
            TextField("https://", text: $draft.urlString)
                .keyboardType(.URL)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            DashedDivider()
            TrackrButton("SAVE") { /* wired in Task 6 */ }
                .padding(20)
        }
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(label, size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            content()
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }
}

#Preview {
    AddSubscriptionSheet()
        .preferredColorScheme(.dark)
}
```

Delete the temporary `AddSubscriptionSheet` stub from `HomeView.swift`.

- [ ] **Step 4: Build + run snapshots twice (record then verify)**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/AddSubscriptionSheetSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/AddSubscriptionSheetSnapshotTests 2>&1 | tail -3
```

Second run expected: 2 tests pass.

- [ ] **Step 5: Visually review the recorded snapshots**

Open `TrackrTests/__Snapshots__/AddSubscriptionSheetSnapshotTests/*.png` and confirm the form looks like the spec.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/AddSubscription Trackr/Features/Home/HomeView.swift TrackrTests/AddSubscriptionSheet_Snapshot_Tests.swift TrackrTests/__Snapshots__/AddSubscriptionSheetSnapshotTests
git commit -m "feat(add-sub): scaffold AddSubscriptionSheet form with snapshot baselines"
```

---

### Task 6: `AddSubscriptionSheet` — submit handler (TDD via repository)

**Files:**
- Modify: `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift` (replace the two `/* wired in Task 6 */` stubs)
- Create: `TrackrTests/AddSubscriptionSheet_Submit_Tests.swift`

The submit path is the only logic that can break silently, so we cover it directly. The view-level test instantiates `AddSubscriptionSheet`, drives its public `submit()` helper, and inspects the SwiftData store via `SubscriptionRepository`.

- [ ] **Step 1: Write the failing submit tests**

Create `TrackrTests/AddSubscriptionSheet_Submit_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class AddSubscriptionSheetSubmitTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_submit_validDraft_insertsRow() throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "ChatGPT Plus"
        draft.amountString = "20"
        draft.category = .ai

        var dismissed = false
        let result = AddSubscriptionSheet.submit(draft: draft,
                                                 context: container.mainContext,
                                                 onDismiss: { dismissed = true })

        XCTAssertNil(result, "submit should return nil error on success")
        XCTAssertTrue(dismissed)
        let all = try SubscriptionRepository(context: container.mainContext).fetchAll()
        XCTAssertEqual(all.map(\.name), ["ChatGPT Plus"])
        XCTAssertEqual(all.first?.amount, 20)
        XCTAssertEqual(all.first?.category, .ai)
    }

    func test_submit_invalidDraft_returnsErrorAndDoesNotInsert() throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = ""   // invalid

        var dismissed = false
        let result = AddSubscriptionSheet.submit(draft: draft,
                                                 context: container.mainContext,
                                                 onDismiss: { dismissed = true })

        XCTAssertNotNil(result)
        XCTAssertFalse(dismissed)
        let count = try SubscriptionRepository(context: container.mainContext).count()
        XCTAssertEqual(count, 0)
    }
}
```

- [ ] **Step 2: Run, expect build failure** — `submit` doesn't exist yet.

- [ ] **Step 3: Add the `submit` helper and wire the two buttons**

In `AddSubscriptionSheet.swift`, add inside the struct (right above the closing brace):
```swift
    /// Pure-ish submit helper exposed for tests. Returns `nil` on success or a
    /// user-facing error message on failure.
    @discardableResult
    static func submit(draft: SubscriptionDraft,
                       context: ModelContext,
                       onDismiss: () -> Void) -> String? {
        do {
            let sub = try draft.makeSubscription()
            try SubscriptionRepository(context: context).insert(sub)
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

Replace each `/* wired in Task 6 */` placeholder (header button and footer button) with:
```swift
{
    if let msg = AddSubscriptionSheet.submit(draft: draft, context: context, onDismiss: { dismiss() }) {
        errorMessage = msg
    } else {
        errorMessage = nil
    }
}
```

- [ ] **Step 4: Run, expect tests pass**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/AddSubscriptionSheetSubmitTests 2>&1 | tail -3
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Features/AddSubscription/AddSubscriptionSheet.swift TrackrTests/AddSubscriptionSheet_Submit_Tests.swift
git commit -m "feat(add-sub): wire submit to SubscriptionRepository with validation surface"
```

---

### Task 7: `SubscriptionDetailView` — read-only render (snapshot)

**Files:**
- Create: `Trackr/Features/Detail/SubscriptionDetailView.swift`
- Create: `TrackrTests/SubscriptionDetailView_Snapshot_Tests.swift`
- Modify: `Trackr/Features/Home/HomeView.swift` (delete the `SubscriptionDetailView` stub)

Show all fields. Pause / Edit / Delete actions are wired in Tasks 8–10.

- [ ] **Step 1: Write the failing snapshot test**

Create `TrackrTests/SubscriptionDetailView_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionDetailViewSnapshotTests: XCTestCase {

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

    private func seedAndHost(active: Bool) -> some View {
        let sub = Subscription(
            name: "Notion",
            planName: "Personal Pro",
            amount: 8,
            currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: Date(timeIntervalSince1970: 1_750_000_000),
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            category: .productivity,
            notes: "Annual savings option later",
            isActive: active
        )
        container.mainContext.insert(sub)
        try? container.mainContext.save()
        return SubscriptionDetailView(subscription: sub)
            .modelContainer(container)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_active_render() {
        assertSnapshot(of: seedAndHost(active: true), as: .image)
    }

    func test_paused_render() {
        assertSnapshot(of: seedAndHost(active: false), as: .image)
    }
}
```

- [ ] **Step 2: Run, expect build failure**

- [ ] **Step 3: Implement `SubscriptionDetailView.swift`**

Create `Trackr/Features/Detail/SubscriptionDetailView.swift`:
```swift
import SwiftUI
import SwiftData

struct SubscriptionDetailView: View {

    @Bindable var subscription: Subscription
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var editing = false
    @State private var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().background(TrackrColors.border)
                ScrollView {
                    if editing {
                        editingBody
                    } else {
                        readingBody
                    }
                }
                footer
            }
        }
        .confirmationDialog("Delete \(subscription.name)?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var header: some View {
        HStack {
            Button("CLOSE") { dismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            PixelText("DETAIL", size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            if editing {
                Button("DONE") { commitEdits() }
                    .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                    .foregroundStyle(TrackrColors.accent)
            } else {
                Button("EDIT") { beginEdit() }
                    .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                    .foregroundStyle(TrackrColors.accent)
            }
        }
        .padding(20)
    }

    private var readingBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            heroAmount
            DashedDivider()
            row("PLAN", subscription.planName ?? "—")
            row("CYCLE", cycleText)
            row("CATEGORY", subscription.category.displayName.uppercased())
            row("STARTED", iso(subscription.startDate))
            row("NEXT", iso(subscription.nextBillingDate))
            row("STATUS", subscription.isActive ? "ACTIVE" : "PAUSED")
            if let notes = subscription.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    PixelText("NOTES",
                              size: TrackrTypography.Scale.sectionLabel,
                              color: TrackrColors.fg2,
                              tracking: 2)
                    Text(notes)
                        .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                        .foregroundStyle(TrackrColors.fg)
                }
            }
        }
        .padding(20)
    }

    private var editingBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            labeled("NAME") {
                TextField("", text: $draft.name)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
            }
            labeled("AMOUNT") {
                TextField("0.00", text: $draft.amountString)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
            }
            labeled("PLAN") {
                TextField("optional", text: $draft.planName)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
            }
            labeled("NOTES") {
                TextField("optional", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrackrColors.fg)
            }
        }
        .padding(20)
    }

    private var heroAmount: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(subscription.name.uppercased(),
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            PixelText(AmountFormatter.format(subscription.amount, currency: subscription.currency),
                      size: TrackrTypography.Scale.hero,
                      color: subscription.isActive ? TrackrColors.fg : TrackrColors.fg3,
                      tracking: 1)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            DashedDivider()
            HStack(spacing: 12) {
                TrackrButton(subscription.isActive ? "PAUSE" : "RESUME",
                             variant: .outlined) { togglePause() }
                TrackrButton("DELETE", variant: .outlined) { confirmingDelete = true }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            PixelText(label, size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            Spacer()
            PixelText(value, size: TrackrTypography.Scale.value, tracking: 1)
        }
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(label, size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            content()
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var cycleText: String {
        switch subscription.billingCycle {
        case .monthly:           return "MONTHLY"
        case .yearly:            return "YEARLY"
        case .weekly:            return "WEEKLY"
        case .customDays(let d): return "EVERY \(d) DAYS"
        }
    }

    private func iso(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    // MARK: - Actions — implementations land in Tasks 8/9/10

    private func beginEdit() {
        // Task 8 fills this in.
        editing = true
    }

    private func commitEdits() {
        // Task 8 fills this in.
        editing = false
    }

    private func togglePause() {
        // Task 9 fills this in.
    }

    private func performDelete() {
        // Task 10 fills this in.
    }
}
```

Delete the temporary `SubscriptionDetailView` stub from `HomeView.swift`.

- [ ] **Step 4: Build + run snapshots twice (record then verify)**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SubscriptionDetailViewSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SubscriptionDetailViewSnapshotTests 2>&1 | tail -3
```

Second run: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Features/Detail Trackr/Features/Home/HomeView.swift TrackrTests/SubscriptionDetailView_Snapshot_Tests.swift TrackrTests/__Snapshots__/SubscriptionDetailViewSnapshotTests
git commit -m "feat(detail): add SubscriptionDetailView read-only with snapshot baselines"
```

---

### Task 8: Detail — edit mode commit (TDD)

**Files:**
- Modify: `Trackr/Features/Detail/SubscriptionDetailView.swift`
- Create: `TrackrTests/SubscriptionDetailView_Edit_Tests.swift`

We add a static `applyEdits(...)` helper (mirroring Task 6's pattern) so the edit path is testable without UI plumbing.

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/SubscriptionDetailView_Edit_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionDetailViewEditTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_applyEdits_updatesFieldsAndSaves() throws {
        let sub = Subscription(
            name: "Old", planName: nil, amount: 5, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now, category: .other
        )
        let ctx = container.mainContext
        ctx.insert(sub)
        try ctx.save()

        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "New Name"
        draft.amountString = "12.50"
        draft.planName = "Pro"
        draft.notes = "moved up a tier"

        let error = SubscriptionDetailView.applyEdits(to: sub, draft: draft, context: ctx)
        XCTAssertNil(error)
        XCTAssertEqual(sub.name, "New Name")
        XCTAssertEqual(sub.amount, Decimal(string: "12.50"))
        XCTAssertEqual(sub.planName, "Pro")
        XCTAssertEqual(sub.notes, "moved up a tier")

        // Re-fetch to confirm save round-tripped.
        let refetched = try SubscriptionRepository(context: ctx).fetch(byID: sub.id)
        XCTAssertEqual(refetched?.name, "New Name")
    }

    func test_applyEdits_invalidAmount_doesNotMutate() throws {
        let sub = Subscription(
            name: "Keep", amount: 5, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now, category: .other
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()

        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Keep"
        draft.amountString = "not-a-number"

        let error = SubscriptionDetailView.applyEdits(to: sub, draft: draft, context: container.mainContext)
        XCTAssertNotNil(error)
        XCTAssertEqual(sub.amount, 5)
    }
}
```

- [ ] **Step 2: Run, expect build failure**

- [ ] **Step 3: Add `applyEdits` + flesh out edit handlers**

Inside `SubscriptionDetailView`, replace the three stubs (`beginEdit`, `commitEdits`, and add `applyEdits`) with:
```swift
    private func beginEdit() {
        draft = SubscriptionDraft(
            name: subscription.name,
            planName: subscription.planName ?? "",
            amountString: "\(subscription.amount)",
            currency: subscription.currency,
            billingCycle: subscription.billingCycle,
            customDays: {
                if case .customDays(let d) = subscription.billingCycle { return d }
                return 30
            }(),
            startDate: subscription.startDate,
            category: subscription.category,
            notes: subscription.notes ?? "",
            urlString: subscription.url?.absoluteString ?? ""
        )
        editing = true
    }

    private func commitEdits() {
        if Self.applyEdits(to: subscription, draft: draft, context: context) == nil {
            editing = false
        }
    }

    /// Pure-ish helper: validates `draft`, mutates `subscription`, saves the context.
    /// Returns `nil` on success or a user-facing error message on failure.
    @discardableResult
    static func applyEdits(to subscription: Subscription,
                           draft: SubscriptionDraft,
                           context: ModelContext) -> String? {
        do {
            let built = try draft.makeSubscription()
            subscription.name = built.name
            subscription.planName = built.planName
            subscription.amount = built.amount
            subscription.currency = built.currency
            subscription.billingCycle = built.billingCycle
            subscription.category = built.category
            subscription.notes = built.notes
            subscription.url = built.url
            subscription.updatedAt = .now
            try context.save()
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

- [ ] **Step 4: Run, expect tests pass**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SubscriptionDetailViewEditTests 2>&1 | tail -3
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Features/Detail/SubscriptionDetailView.swift TrackrTests/SubscriptionDetailView_Edit_Tests.swift
git commit -m "feat(detail): wire edit commit through SubscriptionDraft validation"
```

---

### Task 9: Detail — pause / resume toggle (TDD)

**Files:**
- Modify: `Trackr/Features/Detail/SubscriptionDetailView.swift`
- Create: `TrackrTests/SubscriptionDetailView_Pause_Tests.swift`

Toggle flips `isActive` and saves. `pausedUntil` is left untouched in M3 — the spec uses it for "pause until date X", which is an M4 detail-screen affordance; for now Pause is just an indefinite pause.

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/SubscriptionDetailView_Pause_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionDetailViewPauseTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_togglePause_flipsAndPersists() throws {
        let sub = Subscription(
            name: "X", amount: 1, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now, category: .other
        )
        let ctx = container.mainContext
        ctx.insert(sub)
        try ctx.save()
        XCTAssertTrue(sub.isActive)

        try SubscriptionDetailView.togglePause(subscription: sub, context: ctx)
        XCTAssertFalse(sub.isActive)
        try SubscriptionDetailView.togglePause(subscription: sub, context: ctx)
        XCTAssertTrue(sub.isActive)

        // Confirm latest state survived a save.
        let refetched = try SubscriptionRepository(context: ctx).fetch(byID: sub.id)
        XCTAssertEqual(refetched?.isActive, true)
    }
}
```

- [ ] **Step 2: Run, expect build failure**

- [ ] **Step 3: Implement `togglePause`**

In `SubscriptionDetailView`, replace the `togglePause()` stub with:
```swift
    private func togglePause() {
        try? Self.togglePause(subscription: subscription, context: context)
    }

    static func togglePause(subscription: Subscription, context: ModelContext) throws {
        subscription.isActive.toggle()
        subscription.updatedAt = .now
        try context.save()
    }
```

- [ ] **Step 4: Run, expect tests pass**

- [ ] **Step 5: Commit**

```bash
git add Trackr/Features/Detail/SubscriptionDetailView.swift TrackrTests/SubscriptionDetailView_Pause_Tests.swift
git commit -m "feat(detail): wire pause/resume toggle"
```

---

### Task 10: Detail — delete with confirmation (TDD)

**Files:**
- Modify: `Trackr/Features/Detail/SubscriptionDetailView.swift`
- Create: `TrackrTests/SubscriptionDetailView_Delete_Tests.swift`

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/SubscriptionDetailView_Delete_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class SubscriptionDetailViewDeleteTests: XCTestCase {

    private var container: ModelContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
    }

    override func tearDownWithError() throws {
        container = nil
        try super.tearDownWithError()
    }

    func test_performDelete_removesRowAndDismisses() throws {
        let sub = Subscription(
            name: "GoneSoon", amount: 1, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture, startDate: .now, category: .other
        )
        let ctx = container.mainContext
        ctx.insert(sub)
        try ctx.save()

        var dismissed = false
        try SubscriptionDetailView.performDelete(subscription: sub,
                                                 context: ctx,
                                                 onDismiss: { dismissed = true })

        XCTAssertTrue(dismissed)
        let count = try SubscriptionRepository(context: ctx).count()
        XCTAssertEqual(count, 0)
    }
}
```

- [ ] **Step 2: Run, expect build failure**

- [ ] **Step 3: Implement `performDelete`**

In `SubscriptionDetailView`, replace the `performDelete()` stub with:
```swift
    private func performDelete() {
        try? Self.performDelete(subscription: subscription,
                                context: context,
                                onDismiss: { dismiss() })
    }

    static func performDelete(subscription: Subscription,
                              context: ModelContext,
                              onDismiss: () -> Void) throws {
        try SubscriptionRepository(context: context).delete(subscription)
        onDismiss()
    }
```

- [ ] **Step 4: Run, expect tests pass**

- [ ] **Step 5: Commit**

```bash
git add Trackr/Features/Detail/SubscriptionDetailView.swift TrackrTests/SubscriptionDetailView_Delete_Tests.swift
git commit -m "feat(detail): wire delete with confirmation through SubscriptionRepository"
```

---

### Task 11: End-to-end simulator smoke test + tag

**Files:** none — verification only.

- [ ] **Step 1: Clean build**

```bash
cd /Users/jingxue/Downloads/CC/subscription
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  clean build 2>&1 | tail -5
```

Exit 0.

- [ ] **Step 2: Full test suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected:
- M1 + M2: 71 tests
- + Task 1 MonthlyTotalCalculator: 9
- + Task 2 SubscriptionDraft: 9
- + Task 3 SubscriptionRow snapshot: 3
- + Task 4 HomeView snapshot: 2
- + Task 5 AddSubscriptionSheet snapshot: 2
- + Task 6 Submit: 2
- + Task 7 Detail snapshot: 2
- + Task 8 Edit: 2
- + Task 9 Pause: 1
- + Task 10 Delete: 1
- **Total: 104 tests, 0 failures.**

- [ ] **Step 3: Manual happy path in the simulator**

```bash
xcrun simctl boot 'iPhone 16' 2>/dev/null || true
sleep 2
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.placeholder.trackr
sleep 2
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m3-home-empty.png
```

Then in the simulator UI, run through this checklist by hand:
1. Tap the FAB. Add sheet opens.
2. Fill `Name = Netflix`, `Amount = 15.49`. Tap SAVE.
3. Home shows one row, hero shows `$15.49`.
4. Tap the row. Detail opens. Tap EDIT.
5. Change amount to `12.99`. Tap DONE.
6. Detail shows `$12.99`. Close. Home hero reads `$12.99`.
7. Re-open Detail. Tap PAUSE. Status row shows PAUSED, hero greyed out.
8. Tap RESUME. Active again.
9. Tap DELETE → Delete. Detail dismisses. Home is empty again.

Take a final screenshot:
```bash
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m3-after-flow.png
```

- [ ] **Step 4: Tag**

```bash
git tag m3-crud-ui
git tag --list 'm*'
git show m3-crud-ui --stat --no-patch
```

Expected tags: `m1-foundation`, `m2-data`, `m3-crud-ui`.

- [ ] **Step 5: Acceptance summary**

```bash
echo '=== M3 new feature files ==='
git ls-files Trackr/Features
echo
echo '=== Test files added since m2-data ==='
git diff --name-only m2-data HEAD -- TrackrTests | sort
```

---

## M3 Acceptance Summary

- Home: real `@Query`-driven list, dynamic monthly hero in the user's default currency, empty state preserved, FAB opens Add sheet, rows open Detail.
- Add Subscription sheet (CUSTOM): form with name / amount / currency / cycle (incl. customDays) / start date / category / plan / notes / URL; submit goes through `SubscriptionDraft` validation and `SubscriptionRepository.insert`.
- Detail: read view shows every spec field, edit mode commits through the same draft validation, pause/resume toggles `isActive`, delete confirms and removes via the repository.
- 33 net new tests (104 total), build clean, simulator end-to-end exercised manually.
- `git tag m3-crud-ui` set. Ready to scope M4 (`LocalNotificationScheduler` + per-`leadDay` reminders + deep-link from notification to detail).
