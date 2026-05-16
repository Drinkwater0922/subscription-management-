# Milestone 8 — Onboarding, Localization, Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A first-launch onboarding flow, a Settings screen complete enough to ship, English + Simplified Chinese localization for every user-visible string, a placeholder app icon, polished empty-state copy, and haptic feedback on the high-frequency interactions (FAB tap, SAVE, DELETE).

**Architecture:**
- 3-screen onboarding (brand → value pitch → notification permission) lives in `Trackr/Features/Onboarding/`. Completion writes `UserSettings.onboardingCompletedAt` so it's persistent and CloudKit-synced. `TrackrApp` shows `OnboardingView` as a full-screen overlay when the timestamp is `nil`.
- Localization uses Apple's `Localizable.xcstrings` String Catalog. We hand-author the file with `en` + `zh-Hans` for the entire user-visible string set (onboarding, paywall, settings, empty states, key buttons). SwiftUI's `Text("KEY")` and `LocalizedStringKey` automatically look up entries when the file is in the bundle.
- The existing `UserSettings.language` field (`"auto" | "en" | "zh-Hans"`) drives a `.environment(\.locale, ...)` override at the SwiftUI root, letting the user pick a language without changing system settings.
- Settings expands to include: language picker, Pro status row (with "Manage Subscription" link to the system sheet), Restore Purchases button, and Privacy Policy / Terms of Service links (placeholder URLs until M9).
- App icon ships as a single 1024×1024 placeholder PNG (pixel-style monogram of "TR") plus an `AppIcon.appiconset` `Contents.json` that points at it. Xcode 14+ accepts a single-size app icon and auto-generates intermediate sizes at archive time. Final icon art is design work; M8 ships engineering-grade placeholder.
- A small `Haptics` utility wraps `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` so we can inject a fake in tests and call concrete styles (`.light`, `.medium`, `.success`) from view code without re-instantiating generators.
- Empty-state polish: `HomeView`'s "NO SUBS TRACKED" gets a one-line example hint and (optionally) a small "Try Netflix · $15.49/mo" tappable shortcut that pre-fills the Add Subscription sheet.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData (iOS 17), UIKit (haptics), XCTest, swift-snapshot-testing. No new third-party deps.

---

## File Structure

After M8 the new code looks like this (only new + modified files shown):

```
Trackr/
├─ Core/
│  ├─ Haptics/
│  │  ├─ Haptics.swift                            # NEW — protocol + system impl
│  │  └─ FakeHaptics.swift                        # test target lives in TrackrTests, not here
│  └─ Localization/
│     └─ LocaleResolver.swift                     # NEW — Locale lookup from UserSettings.language
├─ Features/
│  ├─ Onboarding/
│  │  ├─ OnboardingView.swift                     # NEW — 3-screen TabView
│  │  ├─ OnboardingBrandPage.swift                # NEW
│  │  ├─ OnboardingValuePage.swift                # NEW
│  │  └─ OnboardingPermissionPage.swift           # NEW
│  ├─ Settings/SettingsView.swift                 # MODIFIED — language picker, Pro row, links
│  └─ Home/HomeView.swift                         # MODIFIED — polished empty state, locale override
└─ Resources/
   └─ Localizable.xcstrings                       # NEW — en + zh-Hans string table

Trackr/Assets.xcassets/AppIcon.appiconset/
├─ Contents.json                                  # NEW — single-size declaration
└─ icon-1024.png                                  # NEW — placeholder pixel monogram

Trackr/TrackrApp.swift                            # MODIFIED — onboarding gate, locale env

project.yml                                        # MODIFIED — Localizable.xcstrings as resource

TrackrTests/
├─ FakeHaptics.swift                              # test fake (no `_Tests` suffix)
├─ Haptics_Tests.swift
├─ LocaleResolver_Tests.swift
├─ OnboardingView_Snapshot_Tests.swift
└─ SettingsView_Snapshot_Tests.swift              # MODIFIED — re-record after new sections
```

---

### Task 1: `Haptics` utility (TDD)

**Files:**
- Create: `Trackr/Core/Haptics/Haptics.swift`
- Create: `TrackrTests/FakeHaptics.swift`
- Create: `TrackrTests/Haptics_Tests.swift`

Narrow protocol the views call. Real impl wraps `UIImpactFeedbackGenerator` + `UINotificationFeedbackGenerator`. Fake records the events.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/FakeHaptics.swift`:
```swift
import Foundation
@testable import Trackr

/// In-memory `Haptics` stand-in for tests. Records every event so call sites
/// can assert "yes, the FAB tap triggered a `.light` impact" without actually
/// asking UIKit to vibrate the simulator.
final class FakeHaptics: Haptics {
    private(set) var events: [HapticEvent] = []

    func play(_ event: HapticEvent) {
        events.append(event)
    }
}
```

Create `TrackrTests/Haptics_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class HapticsTests: XCTestCase {

    func test_fake_recordsEventsInOrder() {
        let fake = FakeHaptics()
        fake.play(.lightImpact)
        fake.play(.success)
        fake.play(.warning)
        XCTAssertEqual(fake.events, [.lightImpact, .success, .warning])
    }

    func test_systemHaptics_constructsWithoutCrashing() {
        // The real generator can't be exercised in unit tests (UIKit binding),
        // but constructing it must not crash on the simulator.
        _ = SystemHaptics()
        // No assertion — survives is enough.
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

Expected: `cannot find 'Haptics' / 'SystemHaptics' / 'HapticEvent' / 'FakeHaptics'`.

- [ ] **Step 3: Implement `Haptics.swift`**

Create `Trackr/Core/Haptics/Haptics.swift`:
```swift
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The four flavors of feedback Trackr uses. Add cases here as new
/// interactions need haptics — never call UIKit generators directly.
enum HapticEvent: Equatable {
    case lightImpact     // FAB tap, picker change
    case mediumImpact    // sheet present
    case success         // save succeeded
    case warning         // gate trip (limit hit, validation error)
}

/// Narrow seam over UIKit's feedback generators. Tests inject `FakeHaptics`;
/// the SwiftUI views consume this protocol via `@Environment(\.haptics)`.
protocol Haptics: AnyObject {
    func play(_ event: HapticEvent)
}

/// Production `Haptics` implementation. Lazily holds the three generator
/// types — `prepare()` warms them on first call so the response feels snappy.
@MainActor
final class SystemHaptics: Haptics {

    #if canImport(UIKit)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    init() {
        #if canImport(UIKit)
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
        #endif
    }

    nonisolated func play(_ event: HapticEvent) {
        Task { @MainActor in
            #if canImport(UIKit)
            switch event {
            case .lightImpact:  lightImpact.impactOccurred()
            case .mediumImpact: mediumImpact.impactOccurred()
            case .success:      notification.notificationOccurred(.success)
            case .warning:      notification.notificationOccurred(.warning)
            }
            #endif
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

Expected: 196 + 2 = 198 tests passing.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Haptics/Haptics.swift \
        TrackrTests/FakeHaptics.swift \
        TrackrTests/Haptics_Tests.swift
git commit -m "feat(haptics): add Haptics protocol with UIKit-backed system impl"
```

---

### Task 2: `LocaleResolver` (TDD)

**Files:**
- Create: `Trackr/Core/Localization/LocaleResolver.swift`
- Create: `TrackrTests/LocaleResolver_Tests.swift`

Pure function: given `UserSettings.language` (`"auto" | "en" | "zh-Hans"`) and the system's preferred locale, returns the `Locale` SwiftUI should render with. `"auto"` defers to the system; explicit values force the override.

- [ ] **Step 1: Write the failing tests**

Create `TrackrTests/LocaleResolver_Tests.swift`:
```swift
import XCTest
@testable import Trackr

final class LocaleResolverTests: XCTestCase {

    private let systemEN = Locale(identifier: "en_US")
    private let systemZH = Locale(identifier: "zh-Hans_CN")

    func test_auto_defersToSystem() {
        XCTAssertEqual(
            LocaleResolver.resolve(languagePreference: "auto", systemLocale: systemEN),
            systemEN
        )
        XCTAssertEqual(
            LocaleResolver.resolve(languagePreference: "auto", systemLocale: systemZH),
            systemZH
        )
    }

    func test_en_alwaysReturnsEnglish() {
        let resolved = LocaleResolver.resolve(languagePreference: "en", systemLocale: systemZH)
        XCTAssertEqual(resolved.language.languageCode?.identifier, "en")
    }

    func test_zhHans_alwaysReturnsSimplifiedChinese() {
        let resolved = LocaleResolver.resolve(languagePreference: "zh-Hans", systemLocale: systemEN)
        XCTAssertEqual(resolved.language.languageCode?.identifier, "zh")
        XCTAssertEqual(resolved.language.script?.identifier, "Hans")
    }

    func test_unknownPreference_defersToSystem() {
        XCTAssertEqual(
            LocaleResolver.resolve(languagePreference: "fr", systemLocale: systemEN),
            systemEN
        )
    }
}
```

- [ ] **Step 2: Run, verify build fails**

Expected: `cannot find 'LocaleResolver'`.

- [ ] **Step 3: Implement `LocaleResolver.swift`**

Create `Trackr/Core/Localization/LocaleResolver.swift`:
```swift
import Foundation

/// Maps `UserSettings.language` (a free-form string) to a concrete `Locale` so
/// SwiftUI can override the rendering locale at the app root.
///
/// Recognized values:
///   - `"auto"` → use the supplied system locale.
///   - `"en"`   → force English (`en_US`).
///   - `"zh-Hans"` → force Simplified Chinese (`zh-Hans_CN`).
///   - anything else → defer to system (defensive default).
enum LocaleResolver {
    static func resolve(languagePreference: String, systemLocale: Locale) -> Locale {
        switch languagePreference {
        case "en":      return Locale(identifier: "en_US")
        case "zh-Hans": return Locale(identifier: "zh-Hans_CN")
        default:        return systemLocale
        }
    }
}
```

- [ ] **Step 4: Run, verify tests pass**

Expected: 198 + 4 = 202 tests.

- [ ] **Step 5: Commit**

```bash
git add Trackr/Core/Localization/LocaleResolver.swift \
        TrackrTests/LocaleResolver_Tests.swift
git commit -m "feat(localization): add LocaleResolver with TDD"
```

---

### Task 3: `OnboardingView` 3-screen flow (snapshot)

**Files:**
- Create: `Trackr/Features/Onboarding/OnboardingView.swift`
- Create: `Trackr/Features/Onboarding/OnboardingBrandPage.swift`
- Create: `Trackr/Features/Onboarding/OnboardingValuePage.swift`
- Create: `Trackr/Features/Onboarding/OnboardingPermissionPage.swift`
- Create: `TrackrTests/OnboardingView_Snapshot_Tests.swift`

3-page `TabView` with page-style indicators. Each page has its own SwiftUI view. The host `OnboardingView` owns the `selectedPage` state and the "Get Started" / "Continue" / "Enable Notifications" CTAs.

- [ ] **Step 1: Write the failing snapshot tests**

Create `TrackrTests/OnboardingView_Snapshot_Tests.swift`:
```swift
import XCTest
import SnapshotTesting
import SwiftUI
@testable import Trackr

@MainActor
final class OnboardingViewSnapshotTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await withSnapshotTesting(record: .missing) {}
    }

    func test_brandPage_render() {
        let view = OnboardingBrandPage()
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    func test_valuePage_render() {
        let view = OnboardingValuePage()
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }

    func test_permissionPage_render() {
        let view = OnboardingPermissionPage(onEnable: {}, onSkip: {})
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
        assertSnapshot(of: view, as: .image)
    }
}
```

- [ ] **Step 2: Run, expect build failure / baseline missing**

Expected: `cannot find 'OnboardingBrandPage' / 'OnboardingValuePage' / 'OnboardingPermissionPage'`.

- [ ] **Step 3: Implement `OnboardingBrandPage.swift`**

Create `Trackr/Features/Onboarding/OnboardingBrandPage.swift`:
```swift
import SwiftUI

struct OnboardingBrandPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            HStack(spacing: 10) {
                Rectangle().fill(TrackrColors.accent).frame(width: 16, height: 16)
                PixelText("TRACKR",
                          size: TrackrTypography.Scale.hero,
                          tracking: 4)
            }
            PixelText("EVERY SUBSCRIPTION,\nNEVER A SURPRISE.",
                      size: TrackrTypography.Scale.title,
                      color: TrackrColors.fg2,
                      tracking: 2)
                .multilineTextAlignment(.leading)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(TrackrColors.bg)
    }
}

#Preview { OnboardingBrandPage().preferredColorScheme(.dark) }
```

- [ ] **Step 4: Implement `OnboardingValuePage.swift`**

Create `Trackr/Features/Onboarding/OnboardingValuePage.swift`:
```swift
import SwiftUI

struct OnboardingValuePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            PixelText("WHY TRACKR",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText("ONE PLACE\nFOR ALL YOUR SUBS",
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            VStack(alignment: .leading, spacing: 16) {
                bullet("SEE YOUR MONTHLY TOTAL AT A GLANCE")
                bullet("GET NOTIFIED BEFORE EVERY RENEWAL")
                bullet("CATCH PRICE CHANGES THE MOMENT THEY HAPPEN")
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(TrackrColors.bg)
    }

    private func bullet(_ label: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PixelText("◆",
                      size: TrackrTypography.Scale.body,
                      color: TrackrColors.accent,
                      tracking: 0)
            PixelText(label,
                      size: TrackrTypography.Scale.body,
                      tracking: 1.5)
        }
    }
}

#Preview { OnboardingValuePage().preferredColorScheme(.dark) }
```

- [ ] **Step 5: Implement `OnboardingPermissionPage.swift`**

Create `Trackr/Features/Onboarding/OnboardingPermissionPage.swift`:
```swift
import SwiftUI

struct OnboardingPermissionPage: View {
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            PixelText("ONE MORE THING",
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2,
                      tracking: 2)
            PixelText("TURN ON NOTIFICATIONS\nSO TRACKR CAN REMIND YOU",
                      size: TrackrTypography.Scale.title,
                      tracking: 2)
            Text("We'll only ping you a few days before each renewal — never spam.")
                .font(TrackrTypography.sans(size: TrackrTypography.Scale.body))
                .foregroundStyle(TrackrColors.fg2)
            Spacer()
            VStack(spacing: 12) {
                TrackrButton("ENABLE NOTIFICATIONS", action: onEnable)
                TrackrButton("MAYBE LATER", variant: .outlined, action: onSkip)
            }
            Spacer().frame(height: 20)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(TrackrColors.bg)
    }
}

#Preview {
    OnboardingPermissionPage(onEnable: {}, onSkip: {})
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 6: Implement `OnboardingView.swift`**

Create `Trackr/Features/Onboarding/OnboardingView.swift`:
```swift
import SwiftUI
import UserNotifications

/// 3-page onboarding shown on cold launch. `onComplete` fires when the user
/// finishes the permission page (regardless of grant/deny). The host
/// (`TrackrApp`) is responsible for writing `UserSettings.onboardingCompletedAt`.
struct OnboardingView: View {

    let onComplete: () -> Void

    @State private var selectedPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedPage) {
                OnboardingBrandPage().tag(0)
                OnboardingValuePage().tag(1)
                OnboardingPermissionPage(
                    onEnable: enableThenComplete,
                    onSkip: onComplete
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            footer
        }
        .background(TrackrColors.bg.ignoresSafeArea())
    }

    private var footer: some View {
        VStack(spacing: 16) {
            pageDots
            if selectedPage < 2 {
                TrackrButton(selectedPage == 0 ? "GET STARTED" : "CONTINUE") {
                    withAnimation { selectedPage += 1 }
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 32)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { idx in
                Rectangle()
                    .fill(idx == selectedPage ? TrackrColors.accent : TrackrColors.fg3)
                    .frame(width: 16, height: 4)
            }
        }
    }

    private func enableThenComplete() {
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            onComplete()
        }
    }
}

#Preview { OnboardingView(onComplete: {}).preferredColorScheme(.dark) }
```

- [ ] **Step 7: Build snapshots twice (record + verify)**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/OnboardingViewSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/OnboardingViewSnapshotTests 2>&1 | tail -3
```

Second run: 3 tests pass.

- [ ] **Step 8: Run full suite**

Expected: 202 + 3 = 205 tests.

- [ ] **Step 9: Commit**

```bash
git add Trackr/Features/Onboarding \
        TrackrTests/OnboardingView_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/OnboardingViewSnapshotTests
git commit -m "feat(onboarding): add 3-page brand/value/permission flow with snapshot baselines"
```

---

### Task 4: Wire `OnboardingView` into `TrackrApp` (gate on `UserSettings.onboardingCompletedAt`)

**Files:**
- Modify: `Trackr/TrackrApp.swift`

`TrackrApp.body` reads `UserSettings.onboardingCompletedAt`. If `nil`, present `OnboardingView` as a `.fullScreenCover` over `HomeView`. The completion handler writes the timestamp and dismisses the cover.

- [ ] **Step 1: Update `TrackrApp.swift`**

Read `Trackr/TrackrApp.swift` first to confirm its current shape. Then make these edits:

(a) Wrap `HomeView()` in a new root view that owns the onboarding state. Replace the `WindowGroup` body with:
```swift
        WindowGroup {
            RootView()
                .environment(router)
                .environment(\.notificationCoordinator, coordinator)
                .environment(\.presetSync, presetSync)
                .environment(entitlement)
                .environment(paywallTrigger)
                .preferredColorScheme(.dark)
                .task { await entitlement.start() }
        }
        .modelContainer(container)
```

(b) Add this new struct at the bottom of `TrackrApp.swift` (below the `TrackrApp` struct, alongside `readCachedProStatus()`):
```swift
/// Root coordinator: shows the onboarding flow as a full-screen cover on
/// first launch (`UserSettings.onboardingCompletedAt == nil`), and `HomeView`
/// otherwise. Writing the completion timestamp through SwiftData triggers
/// re-evaluation of `needsOnboarding` and the cover dismisses.
private struct RootView: View {

    @Environment(\.modelContext) private var context
    @Query private var settings: [UserSettings]

    var body: some View {
        HomeView()
            .fullScreenCover(isPresented: .constant(needsOnboarding)) {
                OnboardingView(onComplete: completeOnboarding)
            }
    }

    private var needsOnboarding: Bool {
        // Treat missing settings row as "not yet onboarded". `SettingsRepository`
        // creates the row on first access; until then we should onboard.
        guard let row = settings.first else { return true }
        return row.onboardingCompletedAt == nil
    }

    private func completeOnboarding() {
        do {
            let row = try SettingsRepository(context: context).currentSettings()
            row.onboardingCompletedAt = .now
            try context.save()
        } catch {
            // M8 ignores this — worst case the user sees the onboarding once
            // more. We don't have a UX surface for repository errors here.
        }
    }
}
```

(c) `OnboardingView.swift` is already in the test target via `Trackr/Features/Onboarding/`. No project.yml change needed.

- [ ] **Step 2: Build + tests**

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

Both: exit 0; 205 tests pass (no net new — wiring only).

The existing `HomeView` snapshot tests instantiate `HomeView()` directly (not `RootView`), so they bypass the onboarding gate. They keep passing without changes.

- [ ] **Step 3: Commit**

```bash
git add Trackr/TrackrApp.swift
git commit -m "feat(onboarding): present OnboardingView until UserSettings.onboardingCompletedAt is set"
```

---

### Task 5: `Localizable.xcstrings` for `en` + `zh-Hans`

**Files:**
- Create: `Trackr/Resources/Localizable.xcstrings`
- Modify: `project.yml` (add the catalog as a resource)

We hand-author the catalog with every user-visible string the task list converts to `NSLocalizedString` / `Text(LocalizedStringKey)`. Apple's `.xcstrings` is JSON; Xcode reads / writes it. Authoring it directly is fine.

We localize the highest-traffic visible strings:
- Onboarding (brand tagline, value bullets, permission CTAs)
- HomeView empty state
- AddSubscriptionSheet CANCEL / SAVE
- Settings labels (REMIND ME, AT, DEFAULT CURRENCY, LANGUAGE)
- Paywall CTAs (UPGRADE, RESTORE PURCHASES, LIFETIME, MONTHLY)
- Common buttons (CLOSE, DELETE, PAUSE, RESUME, EDIT, DONE)

Strings used only in error messages or in pixel-font micro-labels (e.g. "MONTHLY · USD") stay in source for now — most are codes or technical abbreviations the user doesn't need translated.

- [ ] **Step 1: Create `Localizable.xcstrings`**

Create `Trackr/Resources/Localizable.xcstrings`:
```json
{
  "sourceLanguage" : "en",
  "version" : "1.0",
  "strings" : {
    "EVERY SUBSCRIPTION,\nNEVER A SURPRISE." : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "EVERY SUBSCRIPTION,\nNEVER A SURPRISE." } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "管好每一笔订阅，\n再无意外扣款。" } }
      }
    },
    "WHY TRACKR" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "WHY TRACKR" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "为什么选 TRACKR" } }
      }
    },
    "ONE PLACE\nFOR ALL YOUR SUBS" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "ONE PLACE\nFOR ALL YOUR SUBS" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "一个地方\n管所有订阅" } }
      }
    },
    "SEE YOUR MONTHLY TOTAL AT A GLANCE" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "SEE YOUR MONTHLY TOTAL AT A GLANCE" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "一眼看清每月总开销" } }
      }
    },
    "GET NOTIFIED BEFORE EVERY RENEWAL" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "GET NOTIFIED BEFORE EVERY RENEWAL" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "续费前提前提醒" } }
      }
    },
    "CATCH PRICE CHANGES THE MOMENT THEY HAPPEN" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "CATCH PRICE CHANGES THE MOMENT THEY HAPPEN" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "价格变动第一时间收到" } }
      }
    },
    "ONE MORE THING" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "ONE MORE THING" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "还有一件事" } }
      }
    },
    "TURN ON NOTIFICATIONS\nSO TRACKR CAN REMIND YOU" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "TURN ON NOTIFICATIONS\nSO TRACKR CAN REMIND YOU" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "打开通知\n让 TRACKR 提醒你" } }
      }
    },
    "We'll only ping you a few days before each renewal — never spam." : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "We'll only ping you a few days before each renewal — never spam." } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "我们只会在每次续费前几天通知你 —— 绝不打扰。" } }
      }
    },
    "ENABLE NOTIFICATIONS" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "ENABLE NOTIFICATIONS" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "打开通知" } }
      }
    },
    "MAYBE LATER" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "MAYBE LATER" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "稍后再说" } }
      }
    },
    "GET STARTED" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "GET STARTED" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "开始使用" } }
      }
    },
    "CONTINUE" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "CONTINUE" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "继续" } }
      }
    },
    "NO SUBS\nTRACKED" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "NO SUBS\nTRACKED" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "暂无\n订阅记录" } }
      }
    },
    "Tap + to add your first subscription" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Tap + to add your first subscription" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "点击 + 添加第一个订阅" } }
      }
    },
    "SETTINGS" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "SETTINGS" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "设置" } }
      }
    },
    "REMIND ME" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "REMIND ME" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "提醒我" } }
      }
    },
    "DEFAULT CURRENCY" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "DEFAULT CURRENCY" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "默认货币" } }
      }
    },
    "LANGUAGE" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "LANGUAGE" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "语言" } }
      }
    },
    "AUTO" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "AUTO" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "跟随系统" } }
      }
    },
    "ENGLISH" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "ENGLISH" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "英文" } }
      }
    },
    "简体中文" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "简体中文" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "简体中文" } }
      }
    },
    "CLOSE" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "CLOSE" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "关闭" } }
      }
    },
    "UPGRADE" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "UPGRADE" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "升级 PRO" } }
      }
    },
    "RESTORE PURCHASES" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "RESTORE PURCHASES" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "恢复购买" } }
      }
    },
    "PRIVACY POLICY" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "PRIVACY POLICY" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "隐私政策" } }
      }
    },
    "TERMS OF SERVICE" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "TERMS OF SERVICE" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "服务条款" } }
      }
    },
    "MANAGE SUBSCRIPTION" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "MANAGE SUBSCRIPTION" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "管理订阅" } }
      }
    },
    "PRO STATUS" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "PRO STATUS" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "PRO 状态" } }
      }
    },
    "FREE" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "FREE" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "免费版" } }
      }
    },
    "PRO MONTHLY" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "PRO MONTHLY" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "PRO 月度" } }
      }
    },
    "PRO LIFETIME" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "PRO LIFETIME" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "PRO 终身" } }
      }
    }
  }
}
```

- [ ] **Step 2: Wire the catalog into the app bundle in `project.yml`**

Open `/Users/jingxue/Downloads/CC/subscription/project.yml`. Find the `Trackr:` target's `sources:` block. The presets JSON was added via `buildPhase: resources` in M5 — do the same for the new file. Replace the existing presets sources entry with both entries:

```yaml
    sources:
      - path: Trackr
        excludes:
          - "Resources/presets.bundled.json"
          - "Resources/Localizable.xcstrings"
      - path: Trackr/Resources/presets.bundled.json
        buildPhase: resources
      - path: Trackr/Resources/Localizable.xcstrings
        buildPhase: resources
```

The `excludes:` keeps both files out of the default-globbed Swift sources. The two explicit `buildPhase: resources` entries put them in the Copy Bundle Resources phase.

If the existing `project.yml` already has an `excludes:` block under the Trackr target's `sources:`, merge the new exclude path into the existing array. Don't duplicate.

- [ ] **Step 3: Regenerate + run tests**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 205 tests still pass. No net new — strings haven't been wired to look up from the catalog yet (Task 6 covers the call-site swap). The catalog just ships in the bundle now.

If `xcodebuild` reports `multiple commands produce ... Localizable.xcstrings`, the file's been double-included (once via the broad `sources` glob, once via the explicit `buildPhase: resources` entry). Adjust the `excludes:` block to drop the file from the implicit glob.

- [ ] **Step 4: Commit**

```bash
git add Trackr/Resources/Localizable.xcstrings project.yml
git commit -m "feat(localization): ship Localizable.xcstrings with en + zh-Hans"
```

---

### Task 6: Swap visible strings to `LocalizedStringKey`

**Files:**
- Modify: `Trackr/Features/Onboarding/OnboardingBrandPage.swift`
- Modify: `Trackr/Features/Onboarding/OnboardingValuePage.swift`
- Modify: `Trackr/Features/Onboarding/OnboardingPermissionPage.swift`
- Modify: `Trackr/Features/Onboarding/OnboardingView.swift`
- Modify: `Trackr/Features/Home/HomeView.swift` (empty state)
- Modify: `Trackr/Features/Settings/SettingsView.swift` (existing labels — language picker added in T8)

`PixelText` currently takes a `String`. We need it to accept `LocalizedStringKey` so the entries in the catalog get looked up. The cleanest fix is overloading `PixelText.init`.

- [ ] **Step 1: Add a `LocalizedStringKey` overload to `PixelText`**

Read `Trackr/DesignSystem/Components/PixelText.swift`. Currently the init signature is:
```swift
init(_ text: String, size: CGFloat = ..., color: Color = ..., tracking: CGFloat = ...)
```

Add a second overload that accepts `LocalizedStringKey` and emits `Text(key)`:
```swift
init(_ key: LocalizedStringKey, size: CGFloat = TrackrTypography.Scale.body,
     color: Color = TrackrColors.fg, tracking: CGFloat = 1.5) {
    // Reuse the string init for storage — but mark localized via a flag.
    self.size = size
    self.color = color
    self.tracking = tracking
    self.text = ""
    self.localizedKey = key
}
```

This requires changing `PixelText` from a String-only struct into one that holds either a String or a LocalizedStringKey. The minimum-effort change: store an enum `PixelTextSource` and branch in `body`. Replace `PixelText` entirely with:

```swift
import SwiftUI

/// Renders text in the VT323 pixel font with a default 1.5pt tracking.
/// Use for all-caps labels, numeric values, and section headers.
struct PixelText: View {
    private enum Source {
        case raw(String)
        case localized(LocalizedStringKey)
    }
    private let source: Source
    let size: CGFloat
    let color: Color
    let tracking: CGFloat

    init(
        _ text: String,
        size: CGFloat = TrackrTypography.Scale.body,
        color: Color = TrackrColors.fg,
        tracking: CGFloat = 1.5
    ) {
        self.source = .raw(text)
        self.size = size
        self.color = color
        self.tracking = tracking
    }

    init(
        _ key: LocalizedStringKey,
        size: CGFloat = TrackrTypography.Scale.body,
        color: Color = TrackrColors.fg,
        tracking: CGFloat = 1.5
    ) {
        self.source = .localized(key)
        self.size = size
        self.color = color
        self.tracking = tracking
    }

    var body: some View {
        textView
            .font(TrackrTypography.pixel(size: size))
            .foregroundStyle(color)
            .tracking(tracking)
    }

    @ViewBuilder
    private var textView: some View {
        switch source {
        case .raw(let s):
            Text(verbatim: s)
        case .localized(let key):
            Text(key)
        }
    }
}
```

Note the use of `Text(verbatim:)` for the raw case — it bypasses the localization machinery, so existing `PixelText("MONTHLY · USD")` call sites (which are programmatically composed strings) don't try to look up the assembled string in the catalog.

- [ ] **Step 2: Convert the onboarding pages to localized keys**

In `Trackr/Features/Onboarding/OnboardingBrandPage.swift`, replace:
```swift
            PixelText("TRACKR",
```
with:
```swift
            PixelText(LocalizedStringKey("TRACKR"),
```
…and similarly for the tagline `"EVERY SUBSCRIPTION,\nNEVER A SURPRISE."`.

In `OnboardingValuePage.swift`, convert each title + bullet to `LocalizedStringKey(...)`.

In `OnboardingPermissionPage.swift`, convert the heading, subhead, and button labels.

In `OnboardingView.swift`, convert the `TrackrButton` label string passed at the bottom (`"GET STARTED"`, `"CONTINUE"`). NOTE: `TrackrButton` takes a `String` label — to preserve that interface, just wrap with `String(localized:)`:
```swift
            TrackrButton(String(localized: selectedPage == 0 ? "GET STARTED" : "CONTINUE")) {
                withAnimation { selectedPage += 1 }
            }
```

`String(localized:)` is the Foundation-level lookup that consults the catalog.

Apply the same `String(localized:)` pattern to the `TrackrButton("ENABLE NOTIFICATIONS", ...)` and `TrackrButton("MAYBE LATER", ...)` calls in `OnboardingPermissionPage.swift`.

- [ ] **Step 3: Convert HomeView empty state**

In `Trackr/Features/Home/HomeView.swift`, find the empty-state block:
```swift
            PixelText("NO SUBS\nTRACKED",
                      size: TrackrTypography.Scale.title,
                      color: TrackrColors.fg3,
                      tracking: 3)
```
Replace the string literal with `LocalizedStringKey("NO SUBS\nTRACKED")`.

Find:
```swift
            Text("Tap + to add your first subscription")
```
Replace with:
```swift
            Text(LocalizedStringKey("Tap + to add your first subscription"))
```

(SwiftUI's `Text(LocalizedStringKey)` is the standard pattern.)

- [ ] **Step 4: Convert the SettingsView labels**

In `Trackr/Features/Settings/SettingsView.swift`, find these `PixelText` literals in the existing sections:
- `"SETTINGS"` (header)
- `"REMIND ME"` (lead-days section label)
- `"AT"` (notify-hour section label) — keep as-is; "AT" is too generic to localize meaningfully, but you can still wrap it
- `"DEFAULT CURRENCY"` (currency section label)
- Button label `"CLOSE"` — wrap with `String(localized:)`

Convert each to `LocalizedStringKey(...)` or `String(localized:)` as appropriate.

Don't touch the chip labels (`"7 DAYS BEFORE"` etc.) — they're programmatically composed and not in the catalog. Leave them as English-only for M8.

- [ ] **Step 5: Build + test**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 205 tests pass. Existing en-locale snapshot tests render the same pixels because the strings match the catalog's en values verbatim. If a snapshot diff appears for `HomeView_Snapshot_Tests` or onboarding, re-record the baselines (delete the PNG, run twice).

- [ ] **Step 6: Commit**

```bash
git add Trackr/DesignSystem/Components/PixelText.swift \
        Trackr/Features/Onboarding \
        Trackr/Features/Home/HomeView.swift \
        Trackr/Features/Settings/SettingsView.swift \
        TrackrTests/__Snapshots__
git commit -m "feat(localization): swap visible strings to LocalizedStringKey lookups"
```

(The `TrackrTests/__Snapshots__` add covers any baselines that needed re-recording.)

---

### Task 7: Locale override at the root via `UserSettings.language`

**Files:**
- Modify: `Trackr/TrackrApp.swift` (apply `.environment(\.locale, ...)` to root)

The `RootView` from Task 4 reads `UserSettings.language` and applies `LocaleResolver.resolve(...)` to override the SwiftUI locale environment.

- [ ] **Step 1: Update `RootView` in `TrackrApp.swift`**

Locate the `RootView` struct added in Task 4. Replace its `body` with:

```swift
    var body: some View {
        HomeView()
            .environment(\.locale, resolvedLocale)
            .fullScreenCover(isPresented: .constant(needsOnboarding)) {
                OnboardingView(onComplete: completeOnboarding)
                    .environment(\.locale, resolvedLocale)
            }
    }

    private var resolvedLocale: Locale {
        let preference = settings.first?.language ?? "auto"
        return LocaleResolver.resolve(
            languagePreference: preference,
            systemLocale: Locale.current
        )
    }
```

- [ ] **Step 2: Build + tests**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 205 tests pass. The locale defaults to `Locale.current` for fresh installs (settings row's `language = "auto"`), which matches the simulator's English locale → snapshots stay green.

- [ ] **Step 3: Commit**

```bash
git add Trackr/TrackrApp.swift
git commit -m "feat(localization): override SwiftUI locale at root from UserSettings.language"
```

---

### Task 8: Settings — language picker, Pro row, links

**Files:**
- Modify: `Trackr/Features/Settings/SettingsView.swift`
- Modify: `TrackrTests/SettingsView_Snapshot_Tests.swift` (delete stale baselines so they re-record)

Add three new sections below the existing "DEFAULT CURRENCY":

1. **Language picker** — 3 options ("AUTO", "ENGLISH", "简体中文") mapping to `"auto" | "en" | "zh-Hans"`. Writes through to `UserSettings.language` on save.
2. **Pro status row** — shows current tier (FREE / PRO MONTHLY / PRO LIFETIME). For non-free, a "Manage Subscription" button links to `https://apps.apple.com/account/subscriptions`. For free, an UPGRADE button presents the paywall via `paywallTrigger`.
3. **Restore Purchases** button — calls `entitlement.refresh()`.
4. **Links** — Privacy Policy and Terms of Service (placeholder URLs `https://trackr.placeholder/privacy` / `/terms` — M9 replaces with real URLs).

- [ ] **Step 1: Update the snapshot test host to inject the new env values**

Read `TrackrTests/SettingsView_Snapshot_Tests.swift`. Update `host()` to inject `ProEntitlement` + `PaywallTriggerCoordinator`:

```swift
    private func host(leadDays: [Int] = [3, 1], hour: Int = 9) throws -> some View {
        let settings = try SettingsRepository(context: container.mainContext).currentSettings()
        settings.leadDays = leadDays
        settings.notifyHour = hour
        try container.mainContext.save()
        let entitlement = ProEntitlement(client: FakeStoreKitClient(), container: container)
        return SettingsView()
            .modelContainer(container)
            .environment(entitlement)
            .environment(PaywallTriggerCoordinator())
            .frame(width: 390, height: 844)
            .preferredColorScheme(.dark)
    }
```

If the existing host already injects entitlement / paywall from a previous milestone, leave it; otherwise add the lines above.

Delete the stale baselines:
```bash
rm TrackrTests/__Snapshots__/SettingsView_Snapshot_Tests/*.png
```

- [ ] **Step 2: Add the new state properties to `SettingsView`**

Read `Trackr/Features/Settings/SettingsView.swift`. Near the existing `@State` properties (`leadDays`, `notifyHour`, `currency`), add:

```swift
    @State private var language: String = "auto"
    @Environment(ProEntitlement.self) private var entitlement
    @Environment(PaywallTriggerCoordinator.self) private var paywallTrigger
```

Update `hydrateFromStore()` to read the language:
```swift
    private func hydrateFromStore() {
        guard let s = try? SettingsRepository(context: context).currentSettings() else { return }
        leadDays = Set(s.leadDays)
        notifyHour = s.notifyHour
        currency = s.defaultCurrency
        language = s.language
    }
```

Update `saveAndDismiss()` and `commit(...)` to include `language`. Change the `commit` signature:

```swift
    static func commit(
        leadDays: [Int],
        notifyHour: Int,
        currency: String,
        language: String,
        context: ModelContext,
        coordinator: NotificationCoordinator?
    ) async {
        do {
            let s = try SettingsRepository(context: context).currentSettings()
            s.leadDays = leadDays
            s.notifyHour = notifyHour
            s.defaultCurrency = currency.uppercased()
            s.language = language
            try context.save()
            if let coordinator { try? await coordinator.refresh() }
        } catch {
            // M4 ignores save failures — there's nowhere meaningful to surface
            // them yet.
        }
    }
```

Update `saveAndDismiss()`:
```swift
    private func saveAndDismiss() {
        Task {
            await Self.commit(
                leadDays: Array(leadDays).sorted(by: >),
                notifyHour: notifyHour,
                currency: currency,
                language: language,
                context: context,
                coordinator: coordinator
            )
            dismiss()
        }
    }
```

Update the existing `test_commit_writesSettingsAndRefreshes` test in `SettingsView_Snapshot_Tests.swift` to pass `language: "auto"`. Find:
```swift
        await SettingsView.commit(
            leadDays: [7, 3],
            notifyHour: 18,
            currency: "cny",
            context: container.mainContext,
            coordinator: coordinator
        )
```
Replace with:
```swift
        await SettingsView.commit(
            leadDays: [7, 3],
            notifyHour: 18,
            currency: "cny",
            language: "auto",
            context: container.mainContext,
            coordinator: coordinator
        )
```

- [ ] **Step 3: Add the new sections to the `body`**

After the existing `currencySection` in the `ScrollView`'s `VStack`, append:
```swift
                        languageSection
                        proStatusSection
                        linksSection
```

Add the new section properties to the struct:

```swift
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText(LocalizedStringKey("LANGUAGE"),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            HStack(spacing: 8) {
                languageChip(value: "auto",     labelKey: "AUTO")
                languageChip(value: "en",       labelKey: "ENGLISH")
                languageChip(value: "zh-Hans",  labelKey: "简体中文")
            }
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    @ViewBuilder
    private func languageChip(value: String, labelKey: LocalizedStringKey) -> some View {
        let isOn = language == value
        Button(action: { language = value }) {
            PixelText(labelKey,
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

    private var proStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PixelText(LocalizedStringKey("PRO STATUS"),
                      size: TrackrTypography.Scale.sectionLabel,
                      color: TrackrColors.fg2, tracking: 2)
            HStack {
                PixelText(proStatusLabel,
                          size: TrackrTypography.Scale.value,
                          color: entitlement.current == .free ? TrackrColors.fg2 : TrackrColors.accent,
                          tracking: 1.5)
                Spacer()
                if entitlement.current == .free {
                    Button(action: { paywallTrigger.present(reason: .manual) }) {
                        PixelText(LocalizedStringKey("UPGRADE"),
                                  size: TrackrTypography.Scale.body,
                                  color: TrackrColors.accent, tracking: 1.5)
                    }.buttonStyle(.plain)
                } else {
                    Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                        PixelText(LocalizedStringKey("MANAGE SUBSCRIPTION"),
                                  size: TrackrTypography.Scale.body,
                                  color: TrackrColors.accent, tracking: 1.5)
                    }
                }
            }
            TrackrButton(String(localized: "RESTORE PURCHASES"), variant: .outlined) {
                Task { await entitlement.refresh() }
            }
            Rectangle().fill(TrackrColors.border).frame(height: 1)
        }
    }

    private var proStatusLabel: LocalizedStringKey {
        switch entitlement.current {
        case .free:        return LocalizedStringKey("FREE")
        case .proMonthly:  return LocalizedStringKey("PRO MONTHLY")
        case .proLifetime: return LocalizedStringKey("PRO LIFETIME")
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Link(destination: URL(string: "https://trackr.placeholder/privacy")!) {
                PixelText(LocalizedStringKey("PRIVACY POLICY"),
                          size: TrackrTypography.Scale.body,
                          color: TrackrColors.fg2, tracking: 1.5)
            }
            Link(destination: URL(string: "https://trackr.placeholder/terms")!) {
                PixelText(LocalizedStringKey("TERMS OF SERVICE"),
                          size: TrackrTypography.Scale.body,
                          color: TrackrColors.fg2, tracking: 1.5)
            }
        }
    }
```

- [ ] **Step 4: Re-record snapshots twice**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SettingsViewSnapshotTests 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test -only-testing:TrackrTests/SettingsViewSnapshotTests 2>&1 | tail -3
```

Second run: 3 tests pass with new baselines.

- [ ] **Step 5: Run full suite**

```bash
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 205 tests still pass (no net new — Settings tests are existing).

- [ ] **Step 6: Commit**

```bash
git add Trackr/Features/Settings/SettingsView.swift \
        TrackrTests/SettingsView_Snapshot_Tests.swift \
        TrackrTests/__Snapshots__/SettingsView_Snapshot_Tests
git commit -m "feat(settings): add language picker, Pro status, restore, privacy/terms links"
```

---

### Task 9: App icon placeholder

**Files:**
- Create: `Trackr/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Trackr/Assets.xcassets/AppIcon.appiconset/icon-1024.png` (binary placeholder — 1024×1024 PNG)

Xcode 14+ accepts a single 1024×1024 image for the app icon and auto-generates intermediate sizes. We ship a placeholder PNG (pixel-style "TR" monogram on the brand color) so the project compiles. Final icon art is design work that M9 polishes.

- [ ] **Step 1: Create the `Contents.json`**

Create `Trackr/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 2: Generate the placeholder PNG via `swift` script**

The icon should be 1024×1024 with the brand black background (`#000000`) and a pixel-style "TR" monogram in lime (`#C7F284`). Generate it inline with a one-shot Swift script:

```bash
cd /Users/jingxue/Downloads/CC/subscription
mkdir -p Trackr/Assets.xcassets/AppIcon.appiconset
cat <<'EOF' > /tmp/gen_icon.swift
import Foundation
import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor.black.setFill()
NSRect(origin: .zero, size: size).fill()

let lime = NSColor(red: 0xC7/255.0, green: 0xF2/255.0, blue: 0x84/255.0, alpha: 1.0)
let font = NSFont(name: "Menlo-Bold", size: 480) ?? NSFont.systemFont(ofSize: 480, weight: .heavy)
let para = NSMutableParagraphStyle()
para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: lime,
    .paragraphStyle: para,
    .kern: 8
]
let text = NSAttributedString(string: "TR", attributes: attrs)
let textSize = text.size()
let rect = NSRect(
    x: (size.width - textSize.width) / 2,
    y: (size.height - textSize.height) / 2 - 30,
    width: textSize.width,
    height: textSize.height
)
text.draw(in: rect)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to render icon\n", stderr)
    exit(1)
}
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: outURL)
print("wrote \(outURL.path)")
EOF
swift /tmp/gen_icon.swift Trackr/Assets.xcassets/AppIcon.appiconset/icon-1024.png
file Trackr/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

Expected: the script prints `wrote ...` and `file` confirms a `PNG image data, 1024 x 1024` payload. If the script fails (no Menlo-Bold, AppKit issues), fall back to a simpler 1024×1024 solid-color PNG via `sips` or a minimal Pillow-style approach. The plan accepts any valid 1024×1024 PNG — the goal is to unblock the build, not to ship final art.

- [ ] **Step 3: Update `project.yml` to recognize the appiconset**

xcodegen automatically picks up `*.xcassets` directories under the target's source path. No YAML change should be needed; the Trackr target's `sources: - path: Trackr` glob covers `Trackr/Assets.xcassets/`. Confirm with `xcodegen generate` + `xcodebuild build` — Xcode logs `Process compiled-asset-catalog` and links the icon into the bundle.

If the build complains the asset catalog doesn't have an AppIcon entry, ensure the `AppIcon.appiconset/Contents.json` was created (Step 1).

Also flip `project.yml` so the Trackr target's `ASSETCATALOG_COMPILER_APPICON_NAME` is `AppIcon` (the default). Most projects don't need an explicit setting — confirm the existing `settings: base:` block doesn't override it.

- [ ] **Step 4: Build + test**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet build 2>&1 | tail -3
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Both: exit 0; 205 tests pass.

- [ ] **Step 5: Verify icon installation in the simulator**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
xcrun simctl boot 'iPhone 16' 2>/dev/null || true
xcrun simctl uninstall booted com.placeholder.trackr 2>/dev/null || true
xcrun simctl install booted "$APP_PATH"
sleep 1
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m8-springboard.png
```

Open `.m8-springboard.png` (or rely on the next acceptance task) and confirm the Trackr tile shows the dark-with-lime-TR icon instead of the gray placeholder.

- [ ] **Step 6: Commit**

```bash
git add Trackr/Assets.xcassets/AppIcon.appiconset
git commit -m "feat(branding): add placeholder app icon (1024x1024 pixel TR)"
```

---

### Task 10: Empty-state polish + haptics integration

**Files:**
- Modify: `Trackr/Features/Home/HomeView.swift` (haptic on FAB tap; empty-state copy)
- Modify: `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift` (haptic on SAVE success / failure)
- Modify: `Trackr/Features/Detail/SubscriptionDetailView.swift` (haptic on DELETE confirm)
- Modify: `Trackr/TrackrApp.swift` (instantiate `SystemHaptics`, inject via env)
- Modify: `Trackr/Features/Routing/AppDeepLinkRouter.swift` (env key for `Haptics`)

The empty-state copy is already localized (Task 6). This task adds:
1. An environment key for `Haptics`.
2. Live `SystemHaptics` instance in `TrackrApp`.
3. Three call sites: FAB tap → `.lightImpact`; submit success → `.success`; submit failure → `.warning`; delete confirm → `.mediumImpact`.

- [ ] **Step 1: Add the env key**

Open `Trackr/Features/Routing/AppDeepLinkRouter.swift`. Append below the existing key blocks:

```swift
private struct HapticsKey: EnvironmentKey {
    static let defaultValue: Haptics? = nil
}

extension EnvironmentValues {
    var haptics: Haptics? {
        get { self[HapticsKey.self] }
        set { self[HapticsKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Instantiate `SystemHaptics` in `TrackrApp`**

In `Trackr/TrackrApp.swift`, add a property:
```swift
    private let haptics: Haptics
```

In `init()`, after the existing initializations:
```swift
        self.haptics = SystemHaptics()
```

In `body`, add the environment injection:
```swift
                .environment(\.haptics, haptics)
```

- [ ] **Step 3: Wire FAB**

In `Trackr/Features/Home/HomeView.swift`:

(a) Add an environment property near the others:
```swift
    @Environment(\.haptics) private var haptics
```

(b) Replace the FAB action:
```swift
            FloatingActionButton(action: {
                haptics?.play(.lightImpact)
                showingAdd = true
            })
            .padding(24)
```

- [ ] **Step 4: Wire SAVE in AddSubscriptionSheet**

In `Trackr/Features/AddSubscription/AddSubscriptionSheet.swift`:

(a) Add environment property:
```swift
    @Environment(\.haptics) private var haptics
```

(b) In `attemptSave()`, emit `.success` on `msg == nil`, `.warning` on `msg != nil`:
```swift
    private func attemptSave() {
        Task {
            if let msg = await Self.submit(draft: draft,
                                            presetId: pendingPresetId,
                                            proStatus: entitlement.current,
                                            context: context,
                                            coordinator: coordinator,
                                            onLimitExceeded: handleLimitExceeded,
                                            onDismiss: { dismiss() }) {
                haptics?.play(.warning)
                errorMessage = msg
            } else {
                haptics?.play(.success)
                errorMessage = nil
            }
        }
    }
```

- [ ] **Step 5: Wire DELETE in `SubscriptionDetailView`**

In `Trackr/Features/Detail/SubscriptionDetailView.swift`:

(a) Add environment property:
```swift
    @Environment(\.haptics) private var haptics
```

(b) Find the `confirmationDialog` block. Add a haptic to the destructive button:
```swift
            Button("Delete", role: .destructive) {
                haptics?.play(.mediumImpact)
                performDelete()
            }
```

- [ ] **Step 6: Build + test**

```bash
xcodegen generate
xcodebuild -project Trackr.xcodeproj -scheme Trackr \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.1' \
  -quiet test 2>&1 | grep -E "Executed [0-9]+ tests|TEST (FAIL|SUCC)" | tail -3
```

Expected: 205 tests pass. Snapshot tests still don't inject a `Haptics` env value (it's optional via the env-key default of `nil`), so they remain green.

If the existing HomeView / AddSubscriptionSheet / Detail snapshot hosts inject `Haptics` somehow (they don't — the env key is fresh), update them; otherwise skip.

- [ ] **Step 7: Commit**

```bash
git add Trackr/TrackrApp.swift \
        Trackr/Features/Routing/AppDeepLinkRouter.swift \
        Trackr/Features/Home/HomeView.swift \
        Trackr/Features/AddSubscription/AddSubscriptionSheet.swift \
        Trackr/Features/Detail/SubscriptionDetailView.swift
git commit -m "feat(haptics): emit light/medium/success/warning on key interactions"
```

---

### Task 11: E2E + tag

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

Expected: 205 tests, **TEST SUCCEEDED**.

- [ ] **Step 3: Manual smoke**

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Trackr-*/Build/Products/Debug-iphonesimulator -name "Trackr.app" -type d 2>/dev/null | head -1)
xcrun simctl boot 'iPhone 16' 2>/dev/null || true
xcrun simctl uninstall booted com.placeholder.trackr 2>/dev/null || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.placeholder.trackr
sleep 2
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m8-onboarding.png
```

The first screenshot should show the OnboardingView's brand page (TRACKR logo + tagline). By hand in the simulator:
1. Swipe / tap GET STARTED → value page → tap CONTINUE → permission page.
2. Tap ENABLE NOTIFICATIONS. Approve / deny the system prompt. The cover should dismiss to HomeView.
3. Take screenshot:
```bash
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m8-home.png
```
4. Open Settings (gear icon). Scroll to LANGUAGE. Tap 简体中文. CLOSE the sheet. HomeView strings ("TAP + TO ADD YOUR FIRST SUBSCRIPTION" → "点击 + 添加第一个订阅") should reflow.
5. Take final screenshot:
```bash
xcrun simctl io booted screenshot /Users/jingxue/Downloads/CC/subscription/.m8-zh.png
```

The home-screen springboard tile should display the lime "TR" placeholder icon.

- [ ] **Step 4: Tag**

```bash
git tag m8-polish
git tag --list 'm*'
git show m8-polish --stat --no-patch
```

Expected tags: `m1-foundation`, `m2-data`, `m3-crud-ui`, `m4-notifications`, `m5-presets`, `m6-iap`, `m7-widget-sync`, `m8-polish`.

- [ ] **Step 5: Acceptance inventory**

```bash
echo '=== M8 new feature files ==='
git diff --name-only --diff-filter=A m7-widget-sync HEAD -- Trackr | sort
echo
echo '=== Resources / icon ==='
git ls-files Trackr/Resources Trackr/Assets.xcassets
echo
echo '=== Test files added since m7-widget-sync ==='
git diff --name-only --diff-filter=A m7-widget-sync HEAD -- TrackrTests | sort
echo
echo '=== Commit count m7-widget-sync..HEAD ==='
git rev-list m7-widget-sync..HEAD --count
```

---

## M8 Acceptance Summary

- 3-page onboarding (`OnboardingBrandPage`, `OnboardingValuePage`, `OnboardingPermissionPage`) presented as a full-screen cover at first launch. Completion writes `UserSettings.onboardingCompletedAt` and dismisses.
- `Localizable.xcstrings` ships en + zh-Hans entries for the visible string set (onboarding, empty state, settings labels, paywall CTAs, common buttons).
- `LocaleResolver` (pure, TDD'd) maps `UserSettings.language` (`"auto" | "en" | "zh-Hans"`) to a `Locale`, which `RootView` applies via `.environment(\.locale, ...)`.
- Settings expands to include language picker, Pro status row (Manage Subscription / Upgrade), Restore Purchases button, Privacy / Terms links (placeholder URLs until M9).
- App icon placeholder: 1024×1024 pixel-style "TR" PNG + `AppIcon.appiconset/Contents.json`.
- `Haptics` protocol + `SystemHaptics` (UIKit-backed) + `FakeHaptics` fired on FAB tap (light), SAVE success (success), SAVE failure (warning), DELETE confirm (medium).

**Net new tests:** 9 (2 Haptics + 4 LocaleResolver + 3 OnboardingView snapshot). Total: **205 tests, 0 failures**.

**Open / out-of-scope for M8:**
- Detail / Add / Library strings stay English-only — full localization sweep is a separate effort. M8 covers the highest-traffic surfaces.
- Real app icon art is design work, not engineering — the placeholder is shipped.
- Privacy / Terms URLs are placeholders (`https://trackr.placeholder/*`); M9 swaps in real URLs once the legal docs are published.
- Sensory feedback on Settings chip taps / picker changes is deferred — the high-frequency interactions (FAB, save, delete) are covered.

`git tag m8-polish` set. Ready to scope M9 (name lock, legal, App Store assets, beta).
