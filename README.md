# Trackr (working name)

iOS subscription tracker for AI / developer tool subscriptions.

- **Spec:** `docs/superpowers/specs/2026-05-14-subscription-tracker-design.md`
- **Roadmap:** `docs/superpowers/plans/2026-05-14-roadmap.md`
- **Minimum iOS:** 17.0
- **Stack:** SwiftUI / SwiftData / CloudKit / StoreKit 2 / WidgetKit — no runtime third-party deps.

## Build

Prerequisites: Xcode 15.3+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
```

Generate the Xcode project from `project.yml`, then open it:

```sh
xcodegen generate
open Trackr.xcodeproj
```

`Cmd+R` to run on an iOS 17+ simulator, `Cmd+U` to test.

The `.xcodeproj` is gitignored. The source of truth is `project.yml`; regenerate any time it changes.
