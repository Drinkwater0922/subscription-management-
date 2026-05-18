# PennyLoop IAP setup — App Store Connect playbook

Everything you need to paste into App Store Connect to register the single
in-app purchase. PennyLoop ships with **one** non-consumable product; no
subscriptions.

ASC URL: https://appstoreconnect.apple.com/apps → PennyLoop → **Monetization**

---

## PennyLoop Pro Lifetime (Non-Consumable)

**ASC → In-App Purchases → "+" → Non-Consumable**

| Field | Value |
|---|---|
| Reference Name | `PennyLoop Pro Lifetime` |
| Product ID | `com.jingxue.pennyloop.pro.lifetime` |
| Price | **Tier 8** — $7.99 USD (≈ ¥58 CNY in China region) |
| Availability | All territories |
| Family Sharing | ✅ Enable |
| Tax Category | Match main app |

### Localizations

**English (U.S.)** — primary

- **Display Name**: `PennyLoop Pro`
- **Description** (≤ 45 chars if ASC enforces the short limit, otherwise the long form below):

```
Lifetime access to every Pro feature. One-time buy.
```

Long form (if the description field allows 255 chars):

```
One-time purchase. Lifetime access to every Pro feature:

• Unlimited tracked subscriptions
• Push notifications when a tracked service raises its price
• Insights: monthly total, yearly projection, category breakdown
• iCloud sync across all your devices

No recurring charge. Restore on any device signed into the same Apple ID.
```

**Chinese (Simplified)**

- **Display Name**: `PennyLoop Pro`
- **Description** (短版):

```
一次买断，终身解锁所有 Pro 功能。无续费。
```

长版（如果字数允许）:

```
一次买断，终身解锁所有 Pro 功能：

• 不限数量的订阅追踪
• 价格变动时推送通知
• 数据洞察：月度总额 / 年度预估 / 分类汇总
• 跨设备 iCloud 同步

无续费。同一 Apple ID 在任意设备恢复购买。
```

### Review Information

- **Screenshot**: `docs/release/iap-paywall-screenshot.png` (640×920 minimum; current snapshot is comfortably above).
- **Review Notes**:

```
PennyLoop Pro Lifetime is a one-time, non-consumable purchase that unlocks:
1. Unlimited tracked subscriptions (free tier capped at 5)
2. Local push notifications for tracked-service price changes
3. The Insights screen (monthly total, yearly projection, category breakdown)
4. CloudKit-based sync across the user's own devices

To reproduce the purchase flow:
1. Launch the app and add 5 subscriptions from the home screen (+ button).
2. Tap + again to add a 6th subscription — the paywall appears.
3. Tap the "LIFETIME" card → Apple's sandbox payment sheet appears.
4. After purchase, the 6th subscription saves successfully and Settings shows "PRO LIFETIME".

Restore is available via the "RESTORE PURCHASES" button at the bottom of the paywall.
No recurring charges. Family Sharing is enabled.
```

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
4. Trigger paywall → tap LIFETIME → Apple's sandbox payment sheet
   appears → tap **Buy** → no real charge

---

## After the product is saved

The product will sit in "**Ready to Submit**" state. For TestFlight sandbox
purchases to work, it needs to be either:

- "Ready to Submit" + attached to a build, OR
- "Approved" (after going through App Review)

For the first time, attach the IAP to the next build submission and it will
go through review together with the app binary.

---

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Paywall shows no price, just an empty button | Product not yet registered in ASC, OR using your real Apple ID instead of sandbox tester | Register product + sign in with sandbox account in Settings → App Store |
| "Cannot connect to iTunes Store" | Sandbox account is from a different region than the device | Match the country in Settings → App Store → Sandbox Account |
| Purchase succeeds but app doesn't unlock | `ProEntitlement` didn't refresh — try Settings → RESTORE PURCHASES | Should auto-refresh; if not, force-quit + relaunch |
