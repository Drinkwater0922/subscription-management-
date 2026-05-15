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
