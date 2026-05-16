# Milestone 4 — Notifications & Cycle-Math Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Local notifications fire `leadDay` days before every active subscription's `nextBillingDate`, at the user's preferred `notifyHour`, with same-day aggregation when multiple subs collide. Tapping a notification deep-links to that subscription's Detail screen. A new Settings screen lets the user tune `leadDays` and `notifyHour`.

**Architecture:**
- The whole notification subsystem lives in `Trackr/Core/Notifications/`. Pure-logic pieces (`NotificationRequestBuilder`, `SameDayAggregator`, `NotificationIdentifier`) stand alone with TDD. `LocalNotificationScheduler` orchestrates them and talks to a `NotificationCenterProtocol`. The real implementation wraps `UNUserNotificationCenter.current()`; tests inject `FakeNotificationCenter` so we can assert exactly which requests would have been scheduled. Each `Subscription` × `leadDay` pair gets a stable identifier (`sub-{uuid}-lead-{N}`) so cancel-and-replace is deterministic.
- A `NotificationCoordinator` is the only seam features call. It does a full `refresh()`: cancel everything Trackr-owned, recompute desired requests across all active subscriptions and the current `UserSettings`, then re-add them. We deliberately avoid diff-based scheduling — O(n) reschedules on save are cheap and avoid drift bugs.
- Deep-linking goes through a single `AppDeepLinkRouter` `@Observable`. `UNUserNotificationCenterDelegate.didReceive(_:)` writes the target subscription UUID to the router; `HomeView` watches it and presents `SubscriptionDetailView`.
- The Settings screen lives in `Trackr/Features/Settings/`. It binds directly to `UserSettings` via `@Bindable` (mirroring how Detail edits work) and calls `NotificationCoordinator.refresh()` on save so a `leadDays`/`notifyHour` change replans every reminder.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData (iOS 17), `UserNotifications`, XCTest, swift-snapshot-testing (already added). No new third-party dependencies.

---

## File Structure

After M4 the new code looks like this (only new + modified files shown):

```
Trackr/Core/Notifications/
├─ NotificationCenterProtocol.swift   # NEW — narrow protocol over UNUserNotificationCenter
├─ SystemNotificationCenter.swift     # NEW — real implementation
├─ NotificationIdentifier.swift       # NEW — pure ID strategy
├─ NotificationRequestBuilder.swift   # NEW — pure: sub × leadDay → UNNotificationRequest
├─ SameDayAggregator.swift            # NEW — pure: groups requests by day+hour
├─ LocalNotificationScheduler.swift   # NEW — orchestrates refresh()
└─ NotificationCoordinator.swift      # NEW — features call this; talks to scheduler + repos

Trackr/Features/
├─ Routing/
│  └─ AppDeepLinkRouter.swift          # NEW — @Observable target sub UUID
├─ Settings/
│  └─ SettingsView.swift                # NEW — leadDays / notifyHour form
├─ Home/HomeView.swift                  # MODIFIED — observes router, opens gear → SettingsView
├─ AddSubscription/AddSubscriptionSheet.swift  # MODIFIED — calls coordinator.refresh()
└─ Detail/SubscriptionDetailView.swift  # MODIFIED — calls coordinator.refresh()

Trackr/TrackrApp.swift                  # MODIFIED — install delegate, inject coordinator/router

TrackrTests/
├─ NotificationIdentifier_Tests.swift
├─ NotificationRequestBuilder_Tests.swift
├─ SameDayAggregator_Tests.swift
├─ LocalNotificationScheduler_Tests.swift
├─ NotificationCoordinator_Tests.swift
├─ AppDeepLinkRouter_Tests.swift
├─ SettingsView_Snapshot_Tests.swift
└─ FakeNotificationCenter.swift         # test-only helper (no `_Tests` suffix)
```

M3 features (`HomeView`, `AddSubscriptionSheet`, `SubscriptionDetailView`) keep their structure — they each grow a single line that calls `NotificationCoordinator.refresh()` on a change.

---

### Task 1: `NotificationCenterProtocol` + real implementation + test fake

**Files:**
- Create: `Trackr/Core/Notifications/NotificationCenterProtocol.swift`
- Create: `Trackr/Core/Notifications/SystemNotificationCenter.swift`
- Create: `TrackrTests/FakeNotificationCenter.swift`
- Create: `TrackrTests/SystemNotificationCenter_Tests.swift`

A narrow protocol over `UNUserNotificationCenter` — only the calls the scheduler actually makes. The real wrapper is thin (forwards everything); the fake is what carries our test coverage. We assert the wrapper's surface area with a single smoke test against a real `UNUserNotificationCenter` instance (the simulator's center accepts `add` without prompting in unit tests when authorization is `.notDetermined`).

- [ ] **Step 1: Write the failing test**

Create `TrackrTests/SystemNotificationCenter_Tests.swift`:
```swift
import XCTest
import UserNotifications
@testable import Trackr

@MainActor
final class SystemNotificationCenterTests: XCTestCase {

    func test_wrapsUNUserNotificationCenterCurrent() {
        let wrapper = SystemNotificationCenter()
        // Exercising the forwarding methods on the real center is hard in unit
        // tests (it'll hit the simulator's user-notification daemon). We just
        // assert the wrapper exists and the underlying center is non-nil.
        XCTAssertNotNil(wrapper.underlying)
    }
}
```

Create `TrackrTests/FakeNotificationCenter.swift`:
```swift
import Foundation
import UserNotifications
@testable import Trackr

/// In-memory stand-in for `UNUserNotificationCenter`. The scheduler talks to
/// `NotificationCenterProtocol` so tests can inject this and assert on
/// `addedRequests` / `removedIdentifiers` directly.
final class FakeNotificationCenter: NotificationCenterProtocol {

    var authorizationResult: Bool = true
    var requestedOptions: UNAuthorizationOptions?
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    private(set) var pendingRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions = options
        return authorizationResult
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        removedIdentifiers.append(contentsOf: ids)
        pendingRequests.removeAll { ids.contains($0.identifier) }
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
Expected: `cannot find 'SystemNotificationCenter' / 'NotificationCenterProtocol' in scope`.

- [ ] **Step 3: Implement the protocol + wrapper**

Create `Trackr/Core/Notifications/NotificationCenterProtocol.swift`:
```swift
import Foundation
import UserNotifications

/// Narrow seam over `UNUserNotificationCenter`. The notification subsystem only
/// ever touches the methods declared here; the production wrapper forwards to
/// `UNUserNotificationCenter.current()`, and tests inject `FakeNotificationCenter`.
protocol NotificationCenterProtocol: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers: [String])
}
```

Create `Trackr/Core/Notifications/SystemNotificationCenter.swift`:
```swift
import Foundation
import UserNotifications

/// Production `NotificationCenterProtocol` implementation. Thin forwarder over
/// `UNUserNotificationCenter.current()` — no logic of its own, kept tiny so the
/// untestable surface area stays as small as possible.
final class SystemNotificationCenter: NotificationCenterProtocol {

    let underlying: UNUserNotificationCenter

    init(_ center: UNUserNotificationCenter = .current()) {
        self.underlying = center
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await underlying.requestAuthorization(options: options)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await underlying.pendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await underlying.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers ids: [String]) {
        underlying.removePendingNotificationRequests(withIdentifiers: ids)
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
Expected: 104 + 1 = 105 tests, `** TEST SUCCEEDED **`. The `FakeNotificationCenter` adds zero tests on its own — Tasks 4 and 5 exercise it.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Notifications/NotificationCenterProtocol.swift \
        Trackr/Core/Notifications/SystemNotificationCenter.swift \
        TrackrTests/FakeNotificationCenter.swift \
        TrackrTests/SystemNotificationCenter_Tests.swift
git commit -m "feat(notifications): add NotificationCenterProtocol with system wrapper and test fake"
```

---

### Task 2: `NotificationIdentifier` (TDD)

**Files:**
- Create: `Trackr/Core/Notifications/NotificationIdentifier.swift`
- Create: `TrackrTests/NotificationIdentifier_Tests.swift`

The scheduler needs to know which pending notifications belong to Trackr (vs. anything a future widget or other component might add) and which sub-and-lead-day pair they came from. Format: `trackr.sub.{uuid}.lead.{N}` for per-sub leadDay notifications and `trackr.aggregate.{yyyy-MM-dd}.lead.{N}` for same-day aggregated ones.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/NotificationIdentifier_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class NotificationIdentifierTests: XCTestCase {

    func test_perSubscription_includesUUIDAndLeadDay() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        XCTAssertEqual(
            NotificationIdentifier.perSubscription(subscriptionID: id, leadDay: 3),
            "trackr.sub.11111111-2222-3333-4444-555555555555.lead.3"
        )
    }

    func test_aggregate_includesDateAndLeadDay() {
        let date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 UTC
        XCTAssertEqual(
            NotificationIdentifier.aggregate(fireDay: date, leadDay: 1),
            "trackr.aggregate.2023-11-14.lead.1"
        )
    }

    func test_isTrackrIdentifier_prefixCheck() {
        XCTAssertTrue(NotificationIdentifier.isTrackrIdentifier("trackr.sub.abc.lead.7"))
        XCTAssertTrue(NotificationIdentifier.isTrackrIdentifier("trackr.aggregate.2024-01-01.lead.3"))
        XCTAssertFalse(NotificationIdentifier.isTrackrIdentifier("widget.refresh"))
        XCTAssertFalse(NotificationIdentifier.isTrackrIdentifier(""))
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'NotificationIdentifier'`.

- [ ] **Step 3: Implement `NotificationIdentifier.swift`**

Create `Trackr/Core/Notifications/NotificationIdentifier.swift`:
```swift
import Foundation

/// Stable identifier strategy for Trackr's local notifications. The `trackr.`
/// prefix lets the scheduler distinguish its own requests from anything else
/// running in the same process (a future widget refresh, etc.) when it cancels
/// in bulk during `refresh()`.
enum NotificationIdentifier {

    static func perSubscription(subscriptionID: UUID, leadDay: Int) -> String {
        "trackr.sub.\(subscriptionID.uuidString.lowercased()).lead.\(leadDay)"
    }

    static func aggregate(fireDay: Date, leadDay: Int) -> String {
        "trackr.aggregate.\(dayFormatter.string(from: fireDay)).lead.\(leadDay)"
    }

    static func isTrackrIdentifier(_ id: String) -> Bool {
        id.hasPrefix("trackr.")
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 105 + 3 = 108 tests passing.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Notifications/NotificationIdentifier.swift \
        TrackrTests/NotificationIdentifier_Tests.swift
git commit -m "feat(notifications): add NotificationIdentifier with TDD coverage"
```

---

### Task 3: `NotificationRequestBuilder` (TDD)

**Files:**
- Create: `Trackr/Core/Notifications/NotificationRequestBuilder.swift`
- Create: `TrackrTests/NotificationRequestBuilder_Tests.swift`

Pure function: given one `Subscription`, one `leadDay`, a `notifyHour`, and a `Calendar`, produce a `UNNotificationRequest`. Body wording: `"Netflix renews in 3 days · $15.49"` (or `"… tomorrow · $15.49"` when leadDay == 1). `userInfo` carries `"subscriptionID"` as the UUID string so the deep-link delegate can recover the target.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/NotificationRequestBuilder_Tests.swift`:
```swift
import XCTest
import UserNotifications
@testable import Trackr

final class NotificationRequestBuilderTests: XCTestCase {

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func sub(name: String = "Netflix",
                     amount: Decimal = 15.49,
                     currency: String = "USD",
                     nextBilling: Date) -> Subscription {
        Subscription(
            name: name,
            amount: amount,
            currency: currency,
            billingCycle: .monthly,
            nextBillingDate: nextBilling,
            startDate: Date(timeIntervalSince1970: 0),
            category: .media
        )
    }

    func test_buildsRequestWithExpectedIdentifierAndUserInfo() throws {
        let sub = sub(nextBilling: Date(timeIntervalSince1970: 1_700_000_000))
        let request = try XCTUnwrap(
            NotificationRequestBuilder.build(
                subscription: sub,
                leadDay: 3,
                notifyHour: 9,
                calendar: Self.utc
            )
        )
        XCTAssertEqual(
            request.identifier,
            "trackr.sub.\(sub.id.uuidString.lowercased()).lead.3"
        )
        XCTAssertEqual(request.content.userInfo["subscriptionID"] as? String,
                       sub.id.uuidString)
    }

    func test_bodyMentionsAmountAndDaysWord() throws {
        let billing = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13 UTC
        let request = try XCTUnwrap(
            NotificationRequestBuilder.build(
                subscription: sub(name: "Netflix", amount: 15.49, nextBilling: billing),
                leadDay: 3,
                notifyHour: 9,
                calendar: Self.utc
            )
        )
        XCTAssertEqual(request.content.title, "Netflix renews soon")
        XCTAssertTrue(request.content.body.contains("3 days"),
                      "body: \(request.content.body)")
        XCTAssertTrue(request.content.body.contains("$15.49"),
                      "body: \(request.content.body)")
    }

    func test_leadDay1_usesTomorrowCopy() throws {
        let billing = Date(timeIntervalSince1970: 1_700_000_000)
        let request = try XCTUnwrap(
            NotificationRequestBuilder.build(
                subscription: sub(nextBilling: billing),
                leadDay: 1,
                notifyHour: 9,
                calendar: Self.utc
            )
        )
        XCTAssertTrue(request.content.body.contains("tomorrow"),
                      "body: \(request.content.body)")
    }

    func test_fireDate_isLeadDaysBeforeBillingAtNotifyHourUTC() throws {
        // 2023-11-14 22:13:20 UTC minus 3 days → 2023-11-11, at notifyHour 9 → 2023-11-11 09:00:00 UTC
        let billing = Date(timeIntervalSince1970: 1_700_000_000)
        let request = try XCTUnwrap(
            NotificationRequestBuilder.build(
                subscription: sub(nextBilling: billing),
                leadDay: 3,
                notifyHour: 9,
                calendar: Self.utc
            )
        )
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        var comps = trigger.dateComponents
        comps.calendar = Self.utc
        comps.timeZone = TimeZone(identifier: "UTC")
        let fire = try XCTUnwrap(comps.date)
        let expected = ISO8601DateFormatter().date(from: "2023-11-11T09:00:00Z")!
        XCTAssertEqual(fire, expected)
    }

    func test_fireDateInPast_returnsNil() {
        let billing = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14
        // leadDay 5_000 days before → far in the past
        let request = NotificationRequestBuilder.build(
            subscription: sub(nextBilling: billing),
            leadDay: 5_000,
            notifyHour: 9,
            calendar: Self.utc,
            now: Date(timeIntervalSince1970: 1_700_000_000) // "now" is the same instant
        )
        XCTAssertNil(request)
    }

    func test_inactiveSubscription_returnsNil() {
        var s = sub(nextBilling: .distantFuture)
        s.isActive = false
        XCTAssertNil(NotificationRequestBuilder.build(
            subscription: s,
            leadDay: 3,
            notifyHour: 9,
            calendar: Self.utc
        ))
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'NotificationRequestBuilder'`.

- [ ] **Step 3: Implement `NotificationRequestBuilder.swift`**

Create `Trackr/Core/Notifications/NotificationRequestBuilder.swift`:
```swift
import Foundation
import UserNotifications

/// Pure builder: takes one (subscription, leadDay, notifyHour, calendar) tuple
/// and returns the matching `UNNotificationRequest`. Returns `nil` when the
/// subscription is inactive or the computed fire date already passed.
enum NotificationRequestBuilder {

    /// `now` is injectable for tests; production callers leave it at `.now`.
    static func build(
        subscription: Subscription,
        leadDay: Int,
        notifyHour: Int,
        calendar: Calendar,
        now: Date = .now
    ) -> UNNotificationRequest? {
        guard subscription.isActive else { return nil }

        // Compute the calendar day for (nextBilling - leadDay), then anchor to notifyHour.
        guard let dayMinusLead = calendar.date(
            byAdding: .day,
            value: -leadDay,
            to: subscription.nextBillingDate
        ) else { return nil }

        var comps = calendar.dateComponents([.year, .month, .day], from: dayMinusLead)
        comps.hour = notifyHour
        comps.minute = 0
        comps.second = 0

        guard let fire = calendar.date(from: comps), fire > now else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "\(subscription.name) renews soon"
        content.body = bodyText(for: subscription, leadDay: leadDay)
        content.userInfo = ["subscriptionID": subscription.id.uuidString]
        content.sound = .default

        let triggerComps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fire
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)

        return UNNotificationRequest(
            identifier: NotificationIdentifier.perSubscription(
                subscriptionID: subscription.id,
                leadDay: leadDay
            ),
            content: content,
            trigger: trigger
        )
    }

    private static func bodyText(for sub: Subscription, leadDay: Int) -> String {
        let amount = AmountFormatter.format(sub.amount, currency: sub.currency)
        let when = leadDay == 1 ? "tomorrow" : "in \(leadDay) days"
        return "\(sub.name) renews \(when) · \(amount)"
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 108 + 6 = 114 tests.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Notifications/NotificationRequestBuilder.swift \
        TrackrTests/NotificationRequestBuilder_Tests.swift
git commit -m "feat(notifications): add NotificationRequestBuilder with TDD"
```

---

### Task 4: `SameDayAggregator` (TDD)

**Files:**
- Create: `Trackr/Core/Notifications/SameDayAggregator.swift`
- Create: `TrackrTests/SameDayAggregator_Tests.swift`

Pure function: when multiple per-subscription requests would fire on the same calendar day at the same hour, combine them into one aggregate request. Rule: a group of `N >= 2` requests becomes one notification titled "{N} subscriptions renew soon" with body summarizing how many and the combined amount. Group of 1 passes through unchanged.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/SameDayAggregator_Tests.swift`:
```swift
import XCTest
import UserNotifications
@testable import Trackr

final class SameDayAggregatorTests: XCTestCase {

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func req(id: String, fire: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "x"
        content.body = "y"
        let comps = Self.utc.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    func test_singleRequest_passesThrough() {
        let r = req(id: "trackr.sub.A.lead.3",
                    fire: Date(timeIntervalSince1970: 1_700_000_000))
        let out = SameDayAggregator.aggregate([r], leadDay: 3, calendar: Self.utc)
        XCTAssertEqual(out.map(\.identifier), ["trackr.sub.A.lead.3"])
    }

    func test_twoRequestsSameDayAndHour_collapseIntoAggregate() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let a = req(id: "trackr.sub.A.lead.1", fire: day)
        let b = req(id: "trackr.sub.B.lead.1", fire: day)
        let out = SameDayAggregator.aggregate([a, b], leadDay: 1, calendar: Self.utc)
        XCTAssertEqual(out.count, 1)
        let agg = out[0]
        XCTAssertTrue(agg.identifier.hasPrefix("trackr.aggregate."))
        XCTAssertTrue(agg.content.body.contains("2"),
                      "expected count in body: \(agg.content.body)")
    }

    func test_twoRequestsDifferentDays_remainSeparate() {
        let dayA = Date(timeIntervalSince1970: 1_700_000_000)
        let dayB = Date(timeIntervalSince1970: 1_700_000_000 + 86_400 * 2)
        let a = req(id: "trackr.sub.A.lead.3", fire: dayA)
        let b = req(id: "trackr.sub.B.lead.3", fire: dayB)
        let out = SameDayAggregator.aggregate([a, b], leadDay: 3, calendar: Self.utc)
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(Set(out.map(\.identifier)),
                       ["trackr.sub.A.lead.3", "trackr.sub.B.lead.3"])
    }

    func test_aggregateTitleAndBody() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let reqs = [req(id: "trackr.sub.A.lead.7", fire: day),
                    req(id: "trackr.sub.B.lead.7", fire: day),
                    req(id: "trackr.sub.C.lead.7", fire: day)]
        let out = SameDayAggregator.aggregate(reqs, leadDay: 7, calendar: Self.utc)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].content.title, "3 subscriptions renew soon")
        XCTAssertTrue(out[0].content.body.contains("in 7 days"),
                      "body: \(out[0].content.body)")
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'SameDayAggregator'`.

- [ ] **Step 3: Implement `SameDayAggregator.swift`**

Create `Trackr/Core/Notifications/SameDayAggregator.swift`:
```swift
import Foundation
import UserNotifications

/// Collapses multiple per-subscription requests that fire on the same calendar
/// day + hour into a single aggregate request. Single-item groups pass through
/// unchanged.
enum SameDayAggregator {

    static func aggregate(
        _ requests: [UNNotificationRequest],
        leadDay: Int,
        calendar: Calendar
    ) -> [UNNotificationRequest] {

        let buckets = Dictionary(grouping: requests, by: dayHourKey(in: calendar))

        return buckets.flatMap { (_, group) -> [UNNotificationRequest] in
            guard group.count >= 2 else { return group }
            return [collapse(group, leadDay: leadDay, calendar: calendar)]
        }
    }

    // MARK: - private

    private static func dayHourKey(in calendar: Calendar) -> (UNNotificationRequest) -> String {
        return { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
                return request.identifier
            }
            let c = trigger.dateComponents
            return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)T\(c.hour ?? 0)"
        }
    }

    private static func collapse(
        _ group: [UNNotificationRequest],
        leadDay: Int,
        calendar: Calendar
    ) -> UNNotificationRequest {
        // Pull a representative trigger from the first request — they all share
        // the same day/hour by construction.
        let trigger = group[0].trigger as! UNCalendarNotificationTrigger
        let dayString = dayString(from: trigger, calendar: calendar)

        let content = UNMutableNotificationContent()
        content.title = "\(group.count) subscriptions renew soon"
        let when = leadDay == 1 ? "tomorrow" : "in \(leadDay) days"
        content.body = "\(group.count) subscriptions renew \(when)"
        content.userInfo = ["aggregateDay": dayString,
                            "leadDay": leadDay]
        content.sound = .default

        let newTrigger = UNCalendarNotificationTrigger(
            dateMatching: trigger.dateComponents,
            repeats: false
        )

        // Reuse the same calendar day for the identifier so two refresh()
        // passes with the same data produce the same ID (idempotency).
        var comps = trigger.dateComponents
        comps.timeZone = calendar.timeZone
        let anchor = calendar.date(from: comps) ?? .distantFuture

        return UNNotificationRequest(
            identifier: NotificationIdentifier.aggregate(fireDay: anchor, leadDay: leadDay),
            content: content,
            trigger: newTrigger
        )
    }

    private static func dayString(
        from trigger: UNCalendarNotificationTrigger,
        calendar: Calendar
    ) -> String {
        let c = trigger.dateComponents
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 114 + 4 = 118 tests.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Notifications/SameDayAggregator.swift \
        TrackrTests/SameDayAggregator_Tests.swift
git commit -m "feat(notifications): add SameDayAggregator with TDD"
```

---

### Task 5: `LocalNotificationScheduler` (TDD)

**Files:**
- Create: `Trackr/Core/Notifications/LocalNotificationScheduler.swift`
- Create: `TrackrTests/LocalNotificationScheduler_Tests.swift`

Wires the pieces together. `refresh(subscriptions:settings:)`:
1. Cancel all pending Trackr identifiers.
2. For every active subscription × every leadDay in settings, build a `UNNotificationRequest` (skip nil).
3. Group with `SameDayAggregator` per leadDay.
4. Add each surviving request to the center.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/LocalNotificationScheduler_Tests.swift`:
```swift
import XCTest
import UserNotifications
@testable import Trackr

@MainActor
final class LocalNotificationSchedulerTests: XCTestCase {

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func sub(name: String, billingDaysFromNow: Int, currency: String = "USD") -> Subscription {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let billing = Self.utc.date(byAdding: .day, value: billingDaysFromNow, to: now)!
        return Subscription(
            name: name, amount: 10, currency: currency,
            billingCycle: .monthly,
            nextBillingDate: billing,
            startDate: Date(timeIntervalSince1970: 0),
            category: .other
        )
    }

    func test_refresh_addsRequestsForEachActiveSubAndLeadDay() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)
        let settings = UserSettings(leadDays: [3, 1], notifyHour: 9)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        try await scheduler.refresh(
            subscriptions: [sub(name: "Netflix", billingDaysFromNow: 10)],
            settings: settings,
            now: now
        )

        XCTAssertEqual(fake.addedRequests.count, 2)
        let ids = Set(fake.addedRequests.map(\.identifier))
        XCTAssertTrue(ids.contains(where: { $0.hasSuffix(".lead.3") }))
        XCTAssertTrue(ids.contains(where: { $0.hasSuffix(".lead.1") }))
    }

    func test_refresh_cancelsTrackrPendingFirst() async throws {
        let fake = FakeNotificationCenter()
        fake.pendingRequests = [
            UNNotificationRequest(identifier: "trackr.sub.OLD.lead.1",
                                  content: UNMutableNotificationContent(),
                                  trigger: nil),
            UNNotificationRequest(identifier: "widget.refresh",
                                  content: UNMutableNotificationContent(),
                                  trigger: nil),
        ]
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)

        try await scheduler.refresh(
            subscriptions: [],
            settings: UserSettings(),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(fake.removedIdentifiers, ["trackr.sub.OLD.lead.1"],
                       "should only remove our own identifiers")
    }

    func test_refresh_skipsInactiveSubscriptions() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)
        var paused = sub(name: "Paused", billingDaysFromNow: 10)
        paused.isActive = false

        try await scheduler.refresh(
            subscriptions: [paused],
            settings: UserSettings(leadDays: [1], notifyHour: 9),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(fake.addedRequests.count, 0)
    }

    func test_refresh_aggregatesSameDayAcrossSubs() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)

        try await scheduler.refresh(
            subscriptions: [
                sub(name: "A", billingDaysFromNow: 5),
                sub(name: "B", billingDaysFromNow: 5),
                sub(name: "C", billingDaysFromNow: 5),
            ],
            settings: UserSettings(leadDays: [1], notifyHour: 9),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(fake.addedRequests.count, 1)
        XCTAssertTrue(fake.addedRequests[0].identifier.hasPrefix("trackr.aggregate."))
    }

    func test_refresh_requestsAuthorizationIfNotYet() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: Self.utc)

        try await scheduler.refresh(
            subscriptions: [],
            settings: UserSettings(),
            now: .now
        )

        XCTAssertEqual(fake.requestedOptions, [.alert, .sound, .badge])
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'LocalNotificationScheduler'`.

- [ ] **Step 3: Implement `LocalNotificationScheduler.swift`**

Create `Trackr/Core/Notifications/LocalNotificationScheduler.swift`:
```swift
import Foundation
import UserNotifications

/// Owns the actual "cancel everything we scheduled, then re-add the desired set"
/// loop. Stateless across calls — every `refresh()` is a full replan, which keeps
/// the system honest at the cost of O(n) work on each save.
final class LocalNotificationScheduler {

    private let center: NotificationCenterProtocol
    private let calendar: Calendar

    init(center: NotificationCenterProtocol, calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    func refresh(
        subscriptions: [Subscription],
        settings: UserSettings,
        now: Date = .now
    ) async throws {
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])

        // Cancel our own pending identifiers.
        let pending = await center.pendingNotificationRequests()
        let trackrIds = pending.map(\.identifier).filter(NotificationIdentifier.isTrackrIdentifier)
        if !trackrIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: trackrIds)
        }

        // Build per-(sub, leadDay) requests, then aggregate per leadDay.
        for leadDay in settings.leadDays {
            let perSub = subscriptions.compactMap { sub in
                NotificationRequestBuilder.build(
                    subscription: sub,
                    leadDay: leadDay,
                    notifyHour: settings.notifyHour,
                    calendar: calendar,
                    now: now
                )
            }
            let final = SameDayAggregator.aggregate(perSub, leadDay: leadDay, calendar: calendar)
            for request in final {
                try await center.add(request)
            }
        }
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 118 + 5 = 123 tests.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Notifications/LocalNotificationScheduler.swift \
        TrackrTests/LocalNotificationScheduler_Tests.swift
git commit -m "feat(notifications): add LocalNotificationScheduler with refresh() TDD"
```

---

### Task 6: `AppDeepLinkRouter` + `NotificationCoordinator` (TDD)

**Files:**
- Create: `Trackr/Features/Routing/AppDeepLinkRouter.swift`
- Create: `Trackr/Core/Notifications/NotificationCoordinator.swift`
- Create: `TrackrTests/AppDeepLinkRouter_Tests.swift`
- Create: `TrackrTests/NotificationCoordinator_Tests.swift`

The router is an `@Observable` that holds at most one pending detail-target UUID. Anything that wants to deep-link writes into it; `HomeView` (Task 8) watches it. The coordinator is the single entry point feature views call after a write — it pulls the latest subscription list and settings from SwiftData, then asks the scheduler to refresh.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/AppDeepLinkRouter_Tests.swift`:
```swift
import XCTest
@testable import Trackr

@MainActor
final class AppDeepLinkRouterTests: XCTestCase {

    func test_initialState_noPendingTarget() {
        let router = AppDeepLinkRouter()
        XCTAssertNil(router.pendingSubscriptionID)
    }

    func test_request_setsPendingID() {
        let router = AppDeepLinkRouter()
        let id = UUID()
        router.requestOpen(subscriptionID: id)
        XCTAssertEqual(router.pendingSubscriptionID, id)
    }

    func test_consume_clearsAndReturnsID() {
        let router = AppDeepLinkRouter()
        let id = UUID()
        router.requestOpen(subscriptionID: id)
        XCTAssertEqual(router.consume(), id)
        XCTAssertNil(router.pendingSubscriptionID)
    }

    func test_consume_whenEmpty_returnsNil() {
        let router = AppDeepLinkRouter()
        XCTAssertNil(router.consume())
    }
}
```

Create `TrackrTests/NotificationCoordinator_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class NotificationCoordinatorTests: XCTestCase {

    private var container: ModelContainer!
    private var fake: FakeNotificationCenter!
    private var coordinator: NotificationCoordinator!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: utc)
        coordinator = NotificationCoordinator(scheduler: scheduler, container: container)
    }

    override func tearDownWithError() throws {
        coordinator = nil
        fake = nil
        container = nil
        try super.tearDownWithError()
    }

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func seed(active: Bool, billingDaysAhead: Int) throws {
        let billing = utc.date(byAdding: .day, value: billingDaysAhead, to: Date(timeIntervalSince1970: 1_700_000_000))!
        let sub = Subscription(
            name: "Netflix", amount: 10, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: billing,
            startDate: Date(timeIntervalSince1970: 0),
            category: .other,
            isActive: active
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()
    }

    func test_refresh_addsRequestsForActiveSub() async throws {
        try seed(active: true, billingDaysAhead: 10)
        try await coordinator.refresh(now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertFalse(fake.addedRequests.isEmpty,
                       "expected scheduler to be called via coordinator")
    }

    func test_refresh_skipsInactive() async throws {
        try seed(active: false, billingDaysAhead: 10)
        try await coordinator.refresh(now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(fake.addedRequests.isEmpty)
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'AppDeepLinkRouter' / 'NotificationCoordinator'`.

- [ ] **Step 3: Implement `AppDeepLinkRouter.swift`**

Create `Trackr/Features/Routing/AppDeepLinkRouter.swift`:
```swift
import Foundation
import Observation

/// One-shot mailbox for "open this subscription's Detail screen". The notification
/// delegate writes the target UUID here; `HomeView` reads it and presents Detail.
@Observable
@MainActor
final class AppDeepLinkRouter {
    private(set) var pendingSubscriptionID: UUID?

    func requestOpen(subscriptionID: UUID) {
        pendingSubscriptionID = subscriptionID
    }

    /// Returns and clears the pending target. Call site is responsible for
    /// actually opening the screen.
    func consume() -> UUID? {
        defer { pendingSubscriptionID = nil }
        return pendingSubscriptionID
    }
}
```

- [ ] **Step 4: Implement `NotificationCoordinator.swift`**

Create `Trackr/Core/Notifications/NotificationCoordinator.swift`:
```swift
import Foundation
import SwiftData

/// Single seam features call after a write to keep notifications in sync.
/// Fetches the latest subscription list + user settings, then asks the
/// scheduler to refresh.
@MainActor
final class NotificationCoordinator {

    private let scheduler: LocalNotificationScheduler
    private let container: ModelContainer

    init(scheduler: LocalNotificationScheduler, container: ModelContainer) {
        self.scheduler = scheduler
        self.container = container
    }

    func refresh(now: Date = .now) async throws {
        let context = container.mainContext
        let subs = try context.fetch(FetchDescriptor<Subscription>())
        let settings = try SettingsRepository(context: context).currentSettings()
        try await scheduler.refresh(subscriptions: subs, settings: settings, now: now)
    }
}
```

- [ ] **Step 5: Run, verify tests pass**

Expected: 123 + 4 + 2 = 129 tests.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Routing Trackr/Core/Notifications/NotificationCoordinator.swift \
        TrackrTests/AppDeepLinkRouter_Tests.swift \
        TrackrTests/NotificationCoordinator_Tests.swift
git commit -m "feat(notifications): add AppDeepLinkRouter and NotificationCoordinator"
```

---

### Task 7: Wire scheduler into the M3 write paths

**Files:**
- Modify: `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift` (submit calls coordinator)
- Modify: `Trackr/Features/Detail/SubscriptionDetailView.swift` (edit/pause/delete call coordinator)
- Create: `TrackrTests/NotificationWriteHooks_Tests.swift`

The coordinator is injected via `@Environment(\.notificationCoordinator)`. We add a custom environment key and have `TrackrApp` populate it (Task 9). For now the views call it via the environment; tests inject a coordinator directly into a captured environment value.

The static `submit` / `applyEdits` / `togglePause` / `performDelete` helpers all gain a `coordinator: NotificationCoordinator?` parameter (optional so existing test sites that don't care continue to compile with `nil`). When non-nil, they call `coordinator.refresh()` after the SwiftData save.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/NotificationWriteHooks_Tests.swift`:
```swift
import XCTest
import SwiftData
@testable import Trackr

@MainActor
final class NotificationWriteHooksTests: XCTestCase {

    private var container: ModelContainer!
    private var fake: FakeNotificationCenter!
    private var coordinator: NotificationCoordinator!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try makeInMemoryContainer()
        fake = FakeNotificationCenter()
        let utc = {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "UTC")!
            return c
        }()
        let scheduler = LocalNotificationScheduler(center: fake, calendar: utc)
        coordinator = NotificationCoordinator(scheduler: scheduler, container: container)
    }

    override func tearDownWithError() throws {
        coordinator = nil
        fake = nil
        container = nil
        try super.tearDownWithError()
    }

    func test_addSubscriptionSubmit_callsCoordinatorRefresh() async throws {
        var draft = SubscriptionDraft.empty(defaultCurrency: "USD")
        draft.name = "Netflix"
        draft.amountString = "10"

        let result = await AddSubscriptionSheet.submit(
            draft: draft,
            context: container.mainContext,
            coordinator: coordinator,
            onDismiss: {}
        )
        XCTAssertNil(result)
        XCTAssertFalse(fake.addedRequests.isEmpty,
                       "submit should reschedule notifications")
    }

    func test_detailDelete_callsCoordinatorRefresh() async throws {
        let sub = Subscription(
            name: "X", amount: 1, currency: "USD",
            billingCycle: .monthly,
            nextBillingDate: .distantFuture,
            startDate: .now, category: .other
        )
        container.mainContext.insert(sub)
        try container.mainContext.save()
        // Seed a stale pending request so we can observe the cancellation.
        fake.pendingRequests = [
            UNNotificationRequest(
                identifier: NotificationIdentifier.perSubscription(subscriptionID: sub.id, leadDay: 1),
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        ]
        try await SubscriptionDetailView.performDelete(
            subscription: sub,
            context: container.mainContext,
            coordinator: coordinator,
            onDismiss: {}
        )
        XCTAssertFalse(fake.removedIdentifiers.isEmpty,
                       "delete should cancel pending notifications")
    }
}
```

(The test file references `import UserNotifications` indirectly via `FakeNotificationCenter`; add `import UserNotifications` at the top of the new test file.)

- [ ] **Step 2: Modify `AddSubscriptionSheet.submit`**

Change the signature to accept an optional `coordinator` and call it on success.

In `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift`, replace the existing `static func submit(...)`:
```swift
    @discardableResult
    static func submit(draft: SubscriptionDraft,
                       context: ModelContext,
                       coordinator: NotificationCoordinator? = nil,
                       onDismiss: () -> Void) async -> String? {
        do {
            let sub = try draft.makeSubscription()
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

(Yes, `submit` is now `async`. Update its single existing caller `attemptSave()`:
```swift
    private func attemptSave() {
        Task {
            if let msg = await Self.submit(draft: draft,
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
Add an `@Environment(\.notificationCoordinator) private var coordinator` at the top of the view, alongside `context` and `dismiss`.)

Also update the existing `AddSubscriptionSheetSubmitTests` callers — they need `await` and the new `coordinator: nil` argument. In `TrackrTests/AddSubscriptionSheet_Submit_Tests.swift` replace both `let result = AddSubscriptionSheet.submit(...)` lines with their async equivalents:

```swift
let result = await AddSubscriptionSheet.submit(
    draft: draft,
    context: container.mainContext,
    coordinator: nil,
    onDismiss: { dismissed = true }
)
```

And mark the two test methods `async throws` instead of `throws`.

- [ ] **Step 3: Modify `SubscriptionDetailView` actions**

In `Trackr/Features/Detail/SubscriptionDetailView.swift`:

(a) Add `@Environment(\.notificationCoordinator) private var coordinator` near the existing environment properties.

(b) Replace `applyEdits` with an async version that calls coordinator on success:
```swift
    @discardableResult
    static func applyEdits(to subscription: Subscription,
                           draft: SubscriptionDraft,
                           context: ModelContext,
                           coordinator: NotificationCoordinator? = nil) async -> String? {
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
            if let coordinator { try? await coordinator.refresh() }
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

Replace `togglePause` with:
```swift
    static func togglePause(subscription: Subscription,
                            context: ModelContext,
                            coordinator: NotificationCoordinator? = nil) async throws {
        subscription.isActive.toggle()
        subscription.updatedAt = .now
        try context.save()
        if let coordinator { try? await coordinator.refresh() }
    }
```

Replace `performDelete` with:
```swift
    static func performDelete(subscription: Subscription,
                              context: ModelContext,
                              coordinator: NotificationCoordinator? = nil,
                              onDismiss: () -> Void) async throws {
        try SubscriptionRepository(context: context).delete(subscription)
        if let coordinator { try? await coordinator.refresh() }
        onDismiss()
    }
```

(c) Update the three instance-method callers to wrap in `Task { ... }`:
```swift
    private func commitEdits() {
        Task {
            if await Self.applyEdits(to: subscription,
                                      draft: draft,
                                      context: context,
                                      coordinator: coordinator) == nil {
                editing = false
            }
        }
    }

    private func togglePause() {
        Task {
            try? await Self.togglePause(subscription: subscription,
                                        context: context,
                                        coordinator: coordinator)
        }
    }

    private func performDelete() {
        Task {
            try? await Self.performDelete(subscription: subscription,
                                          context: context,
                                          coordinator: coordinator,
                                          onDismiss: { dismiss() })
        }
    }
```

(d) Update the existing Detail tests (`SubscriptionDetailView_Edit_Tests`, `_Pause_Tests`, `_Delete_Tests`) to be `async throws` and pass `coordinator: nil` plus `await` each call.

For example in `TrackrTests/SubscriptionDetailView_Edit_Tests.swift`, change:
```swift
let error = SubscriptionDetailView.applyEdits(to: sub, draft: draft, context: ctx)
```
to:
```swift
let error = await SubscriptionDetailView.applyEdits(to: sub, draft: draft, context: ctx, coordinator: nil)
```
and the test method to `async throws`. Apply equivalent changes to the Pause and Delete test files.

- [ ] **Step 4: Add the environment key**

In `Trackr/Features/Routing/AppDeepLinkRouter.swift`, append below the class:
```swift
import SwiftUI

private struct NotificationCoordinatorKey: EnvironmentKey {
    static let defaultValue: NotificationCoordinator? = nil
}

extension EnvironmentValues {
    var notificationCoordinator: NotificationCoordinator? {
        get { self[NotificationCoordinatorKey.self] }
        set { self[NotificationCoordinatorKey.self] = newValue }
    }
}
```

- [ ] **Step 5: Run, verify build + tests pass**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 129 + 2 = 131 tests. Existing M3 tests should remain green (their `coordinator: nil` calls go through the new optional branch).

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/AddSubscription/AddSubscriptionSheet.swift \
        Trackr/Features/Detail/SubscriptionDetailView.swift \
        Trackr/Features/Routing/AppDeepLinkRouter.swift \
        TrackrTests/NotificationWriteHooks_Tests.swift \
        TrackrTests/AddSubscriptionSheet_Submit_Tests.swift \
        TrackrTests/SubscriptionDetailView_Edit_Tests.swift \
        TrackrTests/SubscriptionDetailView_Pause_Tests.swift \
        TrackrTests/SubscriptionDetailView_Delete_Tests.swift
git commit -m "feat(notifications): hook coordinator into create/edit/pause/delete paths"
```

---

### Task 8: Wire up `TrackrApp` — install coordinator, router, and delegate

**Files:**
- Modify: `Trackr/TrackrApp.swift`
- Create: `Trackr/Features/Routing/TrackrNotificationDelegate.swift`

The app instantiates one `NotificationCoordinator` and one `AppDeepLinkRouter`, sets up a `UNUserNotificationCenterDelegate`, and injects both via SwiftUI environment.

- [ ] **Step 1: Implement the delegate**

Create `Trackr/Features/Routing/TrackrNotificationDelegate.swift`:
```swift
import Foundation
import UserNotifications

/// Catches notification taps and forwards the target subscription UUID into the
/// shared `AppDeepLinkRouter` so SwiftUI can react.
@MainActor
final class TrackrNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    let router: AppDeepLinkRouter

    init(router: AppDeepLinkRouter) {
        self.router = router
    }

    // Foreground presentation: show the banner + play sound.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completion([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completion: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let raw = userInfo["subscriptionID"] as? String, let uuid = UUID(uuidString: raw) {
            Task { @MainActor in
                router.requestOpen(subscriptionID: uuid)
                completion()
            }
        } else {
            completion()
        }
    }
}
```

- [ ] **Step 2: Replace `TrackrApp.swift`**

Overwrite `Trackr/TrackrApp.swift` with:
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
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(router)
                .environment(\.notificationCoordinator, coordinator)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 3: Run build + tests**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet build 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Both: exit 0; 131 tests pass.

- [ ] **Step 4: Commit**

```bash
git add Trackr/TrackrApp.swift Trackr/Features/Routing/TrackrNotificationDelegate.swift
git commit -m "feat(app): install NotificationCoordinator and notification delegate"
```

---

### Task 9: `HomeView` observes router → presents Detail (snapshot baseline updated)

**Files:**
- Modify: `Trackr/Features/Home/HomeView.swift`
- Modify: `TrackrTests/HomeView_Snapshot_Tests.swift` (delete stale baseline so it re-records)

`HomeView` already presents Detail via `@State private var selected`. Add a `.onChange(of: router.pendingSubscriptionID)` that opens the Detail sheet when the router fires, and consumes the pending value once handled.

- [ ] **Step 1: Update `HomeView.swift`**

In `Trackr/Features/Home/HomeView.swift`:

(a) Add a new environment property near the existing ones:
```swift
    @Environment(AppDeepLinkRouter.self) private var router
```

(b) At the end of the outermost `ZStack` (after the existing `.sheet(item:) { ... }` block), append:
```swift
        .onChange(of: router.pendingSubscriptionID) { _, newValue in
            guard let id = newValue else { return }
            // Look up the subscription in the current @Query result so the
            // sheet binds to the live SwiftData object.
            if let match = subscriptions.first(where: { $0.id == id }) {
                selected = match
            }
            _ = router.consume()
        }
```

- [ ] **Step 2: Update the snapshot tests to inject the router**

In `TrackrTests/HomeView_Snapshot_Tests.swift`, change `host()` so it wraps with `.environment(AppDeepLinkRouter())`:
```swift
    private func host() -> some View {
        HomeView()
            .modelContainer(container)
            .environment(AppDeepLinkRouter())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }
```

Likewise update `TrackrTests/DesignSystemSnapshot_Tests.swift`'s `test_homeView_iPhone15` host wrapping with the same `.environment(AppDeepLinkRouter())`.

Delete the existing HomeView baselines so they re-record:
```bash
rm TrackrTests/__Snapshots__/HomeView_Snapshot_Tests/test_emptyState_render.1.png
rm TrackrTests/__Snapshots__/HomeView_Snapshot_Tests/test_populated_render.1.png
rm TrackrTests/__Snapshots__/DesignSystemSnapshot_Tests/test_homeView_iPhone15.1.png
```

- [ ] **Step 3: Run snapshots twice (record + verify)**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/HomeViewSnapshotTests \
              -only-testing:TrackrTests/DesignSystemSnapshotTests/test_homeView_iPhone15 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/HomeViewSnapshotTests \
              -only-testing:TrackrTests/DesignSystemSnapshotTests/test_homeView_iPhone15 2>&1 | tail -3
```

Second run: passes (visual output should be identical to M3 — the router observer is invisible).

- [ ] **Step 4: Full suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 131 tests, **TEST SUCCEEDED**.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Features/Home/HomeView.swift \
        TrackrTests/HomeView_Snapshot_Tests.swift \
        TrackrTests/DesignSystemSnapshot_Tests.swift \
        TrackrTests/__Snapshots__/HomeView_Snapshot_Tests \
        TrackrTests/__Snapshots__/DesignSystemSnapshot_Tests
git commit -m "feat(home): observe AppDeepLinkRouter and re-record snapshot baselines"
```

---

### Task 10: `SettingsView` — `leadDays` + `notifyHour` form (snapshot)

**Files:**
- Create: `Trackr/Features/Settings/SettingsView.swift`
- Create: `TrackrTests/SettingsView_Snapshot_Tests.swift`

A new screen reachable from the gear icon in `HomeView`'s top bar (Task 11 wires the icon). Three controls:
- Multi-select for `leadDays`: chips for `1`, `3`, `7` days.
- `notifyHour`: `Picker` over `0...23`.
- "Default currency": three-letter `TextField` (uppercased on input, same shape as Add sheet's CCY field).

Tapping CLOSE saves via `SettingsRepository` and calls the coordinator's `refresh()`.

- [ ] **Step 1: Write the failing snapshot test**

Create `TrackrTests/SettingsView_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
import SwiftData
@testable import Trackr

@MainActor
final class SettingsViewSnapshotTests: XCTestCase {

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

    private func host(leadDays: [Int] = [3, 1], hour: Int = 9) throws -> some View {
        let settings = try SettingsRepository(context: container.mainContext).currentSettings()
        settings.leadDays = leadDays
        settings.notifyHour = hour
        try container.mainContext.save()
        return SettingsView()
            .modelContainer(container)
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }

    func test_defaults_render() throws {
        assertSnapshot(of: try host(), as: .image)
    }

    func test_allLeadDaysAndLateHour_render() throws {
        assertSnapshot(of: try host(leadDays: [7, 3, 1], hour: 22), as: .image)
    }
}
```

- [ ] **Step 2: Run, expect baseline-missing failure**

- [ ] **Step 3: Implement `SettingsView.swift`**

Create `Trackr/Features/Settings/SettingsView.swift`:
```swift
import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.notificationCoordinator) private var coordinator

    @State private var leadDays: Set<Int> = [3, 1]
    @State private var notifyHour: Int = 9
    @State private var currency: String = "USD"

    var body: some View {
        ZStack {
            TrackrColors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().background(TrackrColors.border)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        leadDaysSection
                        notifyHourSection
                        currencySection
                    }
                    .padding(20)
                }
            }
        }
        .onAppear { hydrateFromStore() }
    }

    private var header: some View {
        HStack {
            Button("CLOSE") { saveAndDismiss() }
                .font(TrackrTypography.pixel(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.accent)
            Spacer()
            PixelText("SETTINGS", size: TrackrTypography.Scale.title, tracking: 2)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(20)
    }

    private var leadDaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText("REMIND ME",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            HStack(spacing: 8) {
                ForEach([7, 3, 1], id: \.self) { d in
                    chip(label: "\(d) DAY\(d == 1 ? "" : "S") BEFORE",
                         isOn: leadDays.contains(d)) {
                        toggle(day: d)
                    }
                }
            }
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var notifyHourSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText("AT", size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            Picker("", selection: $notifyHour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d:00", h)).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText("DEFAULT CURRENCY",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            TextField("USD", text: $currency)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .textFieldStyle(.plain)
                .foregroundStyle(TrackrColors.fg)
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .frame(width: 80)
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private func chip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PixelText(label,
                      size: TrackrTypography.Scale.caption,
                      color: isOn ? TrackrColors.onAccent : TrackrColors.fg,
                      tracking: 1.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isOn ? TrackrColors.accent : TrackrColors.bg2)
                .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func toggle(day: Int) {
        if leadDays.contains(day) { leadDays.remove(day) } else { leadDays.insert(day) }
    }

    private func hydrateFromStore() {
        guard let s = try? SettingsRepository(context: context).currentSettings() else { return }
        leadDays = Set(s.leadDays)
        notifyHour = s.notifyHour
        currency = s.defaultCurrency
    }

    private func saveAndDismiss() {
        Task {
            await Self.commit(
                leadDays: Array(leadDays).sorted(by: >),
                notifyHour: notifyHour,
                currency: currency,
                context: context,
                coordinator: coordinator
            )
            dismiss()
        }
    }

    /// Pure-ish helper exposed for testing — writes to the store and refreshes notifications.
    static func commit(
        leadDays: [Int],
        notifyHour: Int,
        currency: String,
        context: ModelContext,
        coordinator: NotificationCoordinator?
    ) async {
        do {
            let s = try SettingsRepository(context: context).currentSettings()
            s.leadDays = leadDays
            s.notifyHour = notifyHour
            s.defaultCurrency = currency.uppercased()
            try context.save()
            if let coordinator { try? await coordinator.refresh() }
        } catch {
            // M4 ignores save failures — there's nowhere meaningful to surface
            // them yet. M8's onboarding adds an error banner.
        }
    }
}

#Preview { SettingsView().preferredColorScheme(.dark) }
```

- [ ] **Step 4: Build snapshots twice (record then verify)**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SettingsViewSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SettingsViewSnapshotTests 2>&1 | tail -3
```

Second run: 2 tests pass.

- [ ] **Step 5: Add a commit-path test**

Append to `TrackrTests/SettingsView_Snapshot_Tests.swift` (the file already has the right imports):
```swift
    func test_commit_writesSettingsAndRefreshes() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = LocalNotificationScheduler(center: fake)
        let coordinator = NotificationCoordinator(scheduler: scheduler, container: container)
        await SettingsView.commit(
            leadDays: [7, 3],
            notifyHour: 18,
            currency: "cny",
            context: container.mainContext,
            coordinator: coordinator
        )
        let s = try SettingsRepository(context: container.mainContext).currentSettings()
        XCTAssertEqual(s.leadDays, [7, 3])
        XCTAssertEqual(s.notifyHour, 18)
        XCTAssertEqual(s.defaultCurrency, "CNY")
        XCTAssertEqual(fake.requestedOptions, [.alert, .sound, .badge])
    }
```

Run only that test:
```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SettingsViewSnapshotTests/test_commit_writesSettingsAndRefreshes 2>&1 | tail -3
```

Expected: 1 test passes.

- [ ] **Step 6: Run full suite**

Expected: 131 + 2 snapshot + 1 commit = 134 tests, **TEST SUCCEEDED**.

- [ ] **Step 7: Commit**

```bash
git add Trackr/Features/Settings \
        TrackrTests/SettingsView_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/SettingsView_Snapshot_Tests
git commit -m "feat(settings): add SettingsView form with leadDays, notifyHour, currency"
```

---

### Task 11: Wire the gear icon → `SettingsView` + E2E + tag

**Files:**
- Modify: `Trackr/Features/Home/HomeView.swift` (wrap gear icon in a `Button`, present `SettingsView` sheet)
- Modify: `TrackrTests/HomeView_Snapshot_Tests.swift` (delete stale baselines so they re-record)

- [ ] **Step 1: Wire the gear icon**

In `Trackr/Features/Home/HomeView.swift`:

(a) Add a state flag near the existing ones:
```swift
    @State private var showingSettings = false
```

(b) Replace the gear-overlay block in `topBar` (the second `Color.clear.frame(width: 32, height: 32)` chain) with a `Button`:
```swift
                Button { showingSettings = true } label: {
                    Color.clear.frame(width: 32, height: 32)
                        .overlay(PixelText("⚙", size: 14, color: TrackrColors.fg2, tracking: 0))
                        .overlay(Rectangle().stroke(TrackrColors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
```

(c) Add a third sheet just before the `.onChange(...)` block from Task 9:
```swift
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .modelContext(context)
                .environment(\.notificationCoordinator, coordinator)
        }
```

(d) Add the environment property at the top of the view (next to the others):
```swift
    @Environment(\.notificationCoordinator) private var coordinator
```

- [ ] **Step 2: Re-record affected baselines**

```bash
rm TrackrTests/__Snapshots__/HomeView_Snapshot_Tests/*.png
rm TrackrTests/__Snapshots__/DesignSystemSnapshot_Tests/test_homeView_iPhone15.1.png
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/HomeViewSnapshotTests \
              -only-testing:TrackrTests/DesignSystemSnapshotTests/test_homeView_iPhone15 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/HomeViewSnapshotTests \
              -only-testing:TrackrTests/DesignSystemSnapshotTests/test_homeView_iPhone15 2>&1 | tail -3
```

Second run: passes. (Visual diff vs. M3 should be near-zero — the gear icon just gained a tappable hit area.)

- [ ] **Step 3: Full suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 134 tests, **TEST SUCCEEDED**.

- [ ] **Step 4: Manual happy-path smoke in the simulator**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
xcrun simctl boot 'iPhone 16' 2>/dev/null || true
xcrun simctl uninstall booted com.placeholder.trackr 2>/dev/null || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.placeholder.trackr
sleep 2
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m4-home.png
```

Then in the simulator, by hand:
1. Tap the gear icon → SettingsView opens with `[3 DAYS BEFORE, 1 DAY BEFORE]` highlighted and `09:00` selected.
2. Toggle `7 DAYS BEFORE`. Pick `21:00`. Tap CLOSE.
3. Tap the FAB. Create a subscription with `Name = Demo`, `Amount = 1.00`, set `Starts` to ~2 minutes from now. Tap SAVE. Approve the notification prompt.
4. Wait ~2 minutes (or change the device clock forward). Notification fires.
5. Tap the notification on the lock screen / banner. App opens directly into the Demo Detail screen.

Take a final screenshot:
```bash
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m4-deeplink.png
```

- [ ] **Step 5: Tag**

```bash
git add Trackr/Features/Home/HomeView.swift \
        TrackrTests/__Snapshots__/HomeView_Snapshot_Tests \
        TrackrTests/__Snapshots__/DesignSystemSnapshot_Tests
git commit -m "feat(home): wire gear icon to SettingsView sheet"

git tag m4-notifications
git tag --list 'm*'
git show m4-notifications --stat --no-patch
```

Expected tags: `m1-foundation`, `m2-data`, `m3-crud-ui`, `m4-notifications`.

- [ ] **Step 6: Acceptance inventory**

```bash
echo '=== M4 new feature files ==='
git ls-files Trackr/Core/Notifications Trackr/Features/Routing Trackr/Features/Settings
echo
echo '=== Test files added since m3-crud-ui ==='
git diff --name-only m3-crud-ui HEAD -- TrackrTests | sort
echo
echo '=== Commit count m3-crud-ui..HEAD ==='
git rev-list m3-crud-ui..HEAD --count
```

---

## M4 Acceptance Summary

- `LocalNotificationScheduler` wraps `UNUserNotificationCenter` behind `NotificationCenterProtocol`, with `FakeNotificationCenter` powering deterministic tests.
- Pure `NotificationRequestBuilder` and `SameDayAggregator` carry the heavy lifting; both fully TDD'd.
- `NotificationCoordinator.refresh()` is the single seam features call; it's wired into `AddSubscriptionSheet.submit`, `SubscriptionDetailView.applyEdits` / `togglePause` / `performDelete`, and `SettingsView.commit`.
- Notifications carry the subscription UUID in `userInfo`; `TrackrNotificationDelegate` forwards taps into `AppDeepLinkRouter`; `HomeView` presents the matching Detail.
- New `SettingsView` exposes lead-days chips, notify-hour wheel, and default currency.
- Net new tests: 30 (1 wrapper smoke + 3 identifier + 6 builder + 4 aggregator + 5 scheduler + 4 router + 2 coordinator + 2 write-hooks + 2 settings snapshot + 1 settings commit). Total: **134 tests, 0 failures**.
- `git tag m4-notifications` set. Ready to scope M5 (preset library + AI price-change alerts).
