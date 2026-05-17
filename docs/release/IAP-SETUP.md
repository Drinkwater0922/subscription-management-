# PennyLoop IAP setup — App Store Connect playbook

Everything you need to paste into App Store Connect to register the two
in-app purchases. Two products total; both are required for the Pro
flow to function in TestFlight.

ASC URL: https://appstoreconnect.apple.com/apps → PennyLoop → **Monetization**

---

## Product 1 — PennyLoop Pro Lifetime (Non-Consumable)

**ASC → In-App Purchases → "+" → Non-Consumable**

| Field | Value |
|---|---|
| Reference Name | `PennyLoop Pro Lifetime` |
| Product ID | `com.jingxue.pennyloop.pro.lifetime` |
| Price | **Tier 30** — $29.99 USD |
| Availability | All territories |
| Family Sharing | ✅ Enable |

### Localizations

**English (U.S.)** — primary

- **Display Name**: `PennyLoop Pro`
- **Description**:

```
One-time purchase. Lifetime access to every Pro feature:

• Unlimited tracked subscriptions
• Push notifications when a tracked service raises its price
• Insights screen: monthly total, yearly projection, category breakdown
• iCloud sync across all your devices

No recurring charge. Restore on any device signed into the same Apple ID.
```

**Chinese (Simplified)**

- **Display Name**: `PennyLoop Pro`
- **Description**:

```
一次买断，终身解锁所有 Pro 功能：

• 不限数量的订阅追踪
• 价格变动时推送通知
• 数据洞察：月度总额 / 年度预估 / 分类汇总
• 跨设备 iCloud 同步

无续费。同一 Apple ID 在任意设备恢复购买。
```

### Review Information

- **Screenshot**: see "Screenshot to upload" section below
- **Review Notes**:

```
PennyLoop Pro Lifetime is a one-time purchase that unlocks:
1. Unlimited tracked subscriptions (free tier capped at 5)
2. Local push notifications for tracked-service price changes
3. The Insights screen showing monthly/yearly totals and category breakdown
4. CloudKit-based sync across user's own devices

To test:
- Open the app
- Add 5 subscriptions
- Try to add a 6th → paywall appears
- Tap "LIFETIME" → buy with sandbox tester
- The 6th sub adds successfully + Settings shows "PRO LIFETIME"
```

---

## Product 2 — PennyLoop Pro Monthly (Auto-Renewable Subscription)

**ASC → Subscriptions → "+" Create Subscription Group → then "+" inside the group**

### Step 2a: Create the subscription group

| Field | Value |
|---|---|
| Reference Name | `PennyLoop Pro` |
| Localized Display Name (en) | `PennyLoop Pro` |
| Localized Display Name (zh-Hans) | `PennyLoop Pro` |

(The group is just a container; PennyLoop only has one subscription
inside it, but Apple still requires a group.)

### Step 2b: Add the subscription to the group

| Field | Value |
|---|---|
| Reference Name | `PennyLoop Pro Monthly` |
| Product ID | `com.jingxue.pennyloop.pro.monthly` |
| Subscription Duration | **1 Month** |
| Price | **Tier 3** — $2.99 USD / month |
| Availability | All territories |
| Family Sharing | ✅ Enable |

### Localizations

**English (U.S.)**

- **Display Name**: `Monthly`
- **Description**:

```
Monthly subscription. Auto-renews until cancelled.

Unlocks every Pro feature:

• Unlimited tracked subscriptions
• Push notifications when a tracked service raises its price
• Insights screen: monthly total, yearly projection, category breakdown
• iCloud sync across all your devices

Cancel anytime in Settings → Apple ID → Subscriptions.
```

**Chinese (Simplified)**

- **Display Name**: `按月订阅`
- **Description**:

```
按月订阅，自动续费直到取消。

解锁所有 Pro 功能：

• 不限数量的订阅追踪
• 价格变动时推送通知
• 数据洞察：月度总额 / 年度预估 / 分类汇总
• 跨设备 iCloud 同步

随时在「设置 → Apple ID → 订阅」中取消。
```

### Review Information

- **Screenshot**: same paywall screenshot as the lifetime product
- **Review Notes**:

```
PennyLoop Pro Monthly is a $2.99/month auto-renewing subscription
in the "PennyLoop Pro" subscription group. Unlocks the same Pro
features as the lifetime IAP (unlimited subs, price-change push,
Insights, iCloud sync). Cancel anytime via iOS Settings → Apple ID →
Subscriptions.

To test:
- Open the app
- Add 5 subscriptions
- Try to add a 6th → paywall appears
- Tap "MONTHLY" → buy with sandbox tester
- The 6th sub adds successfully + Settings shows "PRO MONTHLY"
```

---

## Screenshot to upload (for BOTH products)

File: `docs/release/iap-paywall-screenshot.png`

Same image works for both — it shows the PennyLoop Pro paywall with
all 4 feature bullets and the two purchase tiers, which is exactly
what App Review wants to see for each product.

Apple's minimum spec for IAP review screenshots: 640×920. Our snapshot
is comfortably above that.

---

## Sandbox tester (for end-to-end testing without real charges)

**ASC → Users and Access → Sandbox → Testers → "+"**

| Field | Value |
|---|---|
| First Name | Test |
| Last Name | One |
| Email | `pennyloop+sandbox1@<your-mail-domain>` |
| Password | (a fresh password, not your real Apple ID password) |
| Date of Birth | Any past date (must be 18+ for IAP) |
| App Store Country | United States |

**On the iPhone:**

1. Open **Settings** → **App Store** → scroll down to **Sandbox Account**
2. Sign in with the sandbox email + password above
3. Open PennyLoop (via TestFlight)
4. Trigger paywall → tap LIFETIME or MONTHLY → Apple's sandbox payment
   sheet appears → tap **Buy** → no real charge

Sandbox subscriptions accelerate time for testing — a "monthly"
subscription renews every ~5 minutes in sandbox, so you can verify the
auto-renewal flow quickly.

---

## After both products are saved

Both products will sit in "**Ready to Submit**" state. For TestFlight
sandbox purchases to work, the product needs to be either:

- "Ready to Submit" + attached to a build, OR
- "Approved" (after going through App Review)

For the first time, attach both IAPs to the next build submission and
they'll go through review together with the app binary.

---

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Paywall shows no prices, just empty buttons | Products not yet registered in ASC, OR using your real Apple ID instead of sandbox tester | Register products + sign in with sandbox account in Settings → App Store |
| "Cannot connect to iTunes Store" | Sandbox account is from a different region than the device | Match the country in Settings → App Store → Sandbox Account |
| Purchase succeeds but app doesn't unlock | `ProEntitlement` didn't refresh — try Settings → RESTORE PURCHASES | Should auto-refresh; if not, force-quit + relaunch |
| "Subscription not eligible for introductory offer" | We don't offer one; safe to ignore | — |
