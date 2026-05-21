# PennyLoop — Product Roadmap

A living strategy doc. Every feature decision should pass the three moat
checks in "North Star" below; anything that fails one is cut, no matter how
attractive it looks.

---

## North Star

**"A subscription companion that lowers anxiety instead of adding to it."**

PennyLoop is not trying to be Mint or Rocket Money. It competes on three
things, and every roadmap decision is checked against them:

1. **Local-first, zero tracking.** Data lives on-device (SwiftData), optional
   sync uses the user's own private CloudKit. No accounts, no servers we
   operate, no analytics SDK.
2. **Pixel-art identity.** Black + lime + VT323. When every finance app looks
   like a bank portal, looking like an NES game is the memory hook.
3. **One-time purchase.** A $7.99 / ¥58 lifetime unlock. In 2026 this is
   itself a statement.

If a proposed feature breaks any of the three, it is rejected — see
"Permanent Non-Goals."

---

## Positioning — Ride the Subscription-Fatigue Wave

Subscription fatigue is a trend-level consumer story in 2026: ~47% of
consumers cancelled at least one subscription in the past year, US households
average $200+/month, ~20% don't know how many subscriptions they pay for,
and "subscription rotation" (subscribe → use → cancel) is now normal
behavior.

**This trend validates PennyLoop's existence — adopt it fully in marketing
and ASO.** Lean into "subscription fatigue / 反订阅 / 订阅瘦身" as a
positioning and keyword theme.

**But take the trend, not the typical solution.** The common product spec
for this opportunity — auto-detect subscriptions from bank statements +
recommend alternatives — is built for people who will hand a third-party app
their bank login. Rocket Money / Truebill already own that audience with
that exact mechanism.

PennyLoop's wedge is the *opposite* audience: the large set of people who
distrust bank-linking and therefore never adopted Rocket Money. The pitch:

> You're already anxious about subscriptions — don't also hand your bank
> login to another app. PennyLoop never connects to your bank, needs no
> account, and keeps every byte on your device.

The trend is ours. The bank-linked solution is not.

---

## Phase 1 — v1.0.x — Make the core excellent

Stabilize the launch. No new surface area; make what shipped feel polished.

- OCR import robustness — drive screenshot-import failure rate below ~10%
  using real user screenshots.
- Preset library expansion — grow toward 200+ entries; China-region
  services are the biggest gap (网易云黑胶 SVIP, 哔哩哔哩大会员, 抖音,
  知识星球, Keep, 得到, 喜马拉雅, …).
- Renewal-reminder copy with context ("Netflix renews in 3 days · ¥58 ·
  tracked 8 months") instead of a bare amount.
- Fill the remote price-change catalog so price-drift detection actually
  fires.
- Treat every 1–3 star review and GitHub issue as a fix queue.

## Phase 2 — v2.0 — Insight that earns trust

Once there is a real user base (~1k+), deepen the "knows my subscriptions
better than I do" story — all on-device.

- **Cost-per-use / unused-subscription alerts.** With the user's permission,
  use the iOS Screen Time API to surface low-value subscriptions:
  "You haven't opened Headspace in 60 days — that's ¥68/month for nothing."
  High share-ability, strong save-money motivation, and **fully compatible
  with the local-first moat** (Screen Time data is read on-device).
- Year-over-year spend trends — the data lock-in that drives retention.
- Annual "subscription year in review" — a shareable card each December.
- "Bundle / consolidate" hints (e.g. Netflix + Disney+ + HBO detected
  together).
- CSV / PDF export for taxes or sharing.

Any "AI" in this phase runs through Apple Intelligence on-device. No
OpenAI/remote calls — the privacy story cannot break.

## Phase 3 — v3.0+ — Platform expansion

Only after Phase 2 retention is proven.

- Mac companion app (free, same iCloud account; focused on export/analysis).
- Apple Watch complication — next-renewal countdown.
- iPad-specific 2-pane layout.
- Lock-screen widget + Live Activity for upcoming renewals.

No web app — a server/account system would destroy the local-first story.

---

## Permanent Non-Goals

| Rejected | Why |
|---|---|
| Bank / credit-card linking (Plaid, etc.) | Destroys moat #1 (privacy) and fights Rocket Money on its home turf with its own weapon. **Hard red line — never.** |
| Switching to subscription pricing | Destroys moat #3 (one-time purchase). |
| Ads or analytics SDKs | Destroys moat #1. |
| General budgeting / expense tracking | Scope explosion; loses to Copilot/Monarch head-on. |
| "Modern minimal" visual redesign | Destroys moat #2 (pixel-art identity). |
| Social / public leaderboards / reviews | High maintenance, low value. |
| An alternatives-recommendation engine | Drifts into editorial/affiliate + a database to maintain. If revisited, do it lightweight — e.g. a "has a one-time-purchase tier" tag on presets — not a recommender. |

---

## Decision Log

- **2026-05** — Subscription-fatigue trend reviewed. Adopt the trend for
  positioning/ASO; reject the bank-statement-detection solution. PennyLoop's
  angle is the privacy-respecting, no-bank-login tracker plus on-device
  usage insight. Bank-API integration recorded as a permanent red line.
