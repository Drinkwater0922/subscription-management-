---
layout: default
title: Privacy Policy — PennyLoop
---

# PennyLoop Privacy Policy

*Last updated: 2026-05-16*

PennyLoop is a local-first subscription tracker. We have designed it so that the developer never sees your personal data. This document explains exactly what data the app handles, where it stays, and what (limited) network traffic the app makes.

## 1. Data we collect about you

**None on our servers.** We do not run a backend that stores your data. We have no user accounts, no signup, no analytics SDK, no advertising SDK, no third-party tracking.

Everything you enter into PennyLoop (subscription names, prices, billing dates, categories, notes, URLs) is stored **locally on your device** in Apple's SwiftData store.

## 2. iCloud sync (optional, Pro only)

If you upgrade to PennyLoop Pro **and** are signed into iCloud on your device, your subscription data may sync across your devices via **Apple's CloudKit**. This data is stored in your personal iCloud account, encrypted by Apple. **We never see it.** You can disable sync by signing out of iCloud on your device or by remaining on the free tier.

## 3. Photo "Import from Photo"

When you pick a photo to import a subscription:

- The image is processed **entirely on-device** by Apple's Vision framework.
- The image data **does not leave your device**.
- We do not retain the image; once the form is filled, the image is discarded.

## 4. Notifications

Local notifications are scheduled by the app on your device. We do not run a push server. The free tier uses only local notifications; the Pro tier may schedule additional local notifications for price-change alerts.

## 5. Outgoing network traffic

PennyLoop makes a small number of outgoing requests, **none of which include any personally identifiable information**:

| Purpose | Endpoint | What we send |
|---|---|---|
| FX rate lookup (when you add a foreign-currency sub) | `api.frankfurter.app` | Currency codes (e.g. `USD`, `CNY`) + date |
| Preset catalog refresh (optional) | A static catalog URL | None |
| In-app purchase | Apple StoreKit | Handled by Apple — we do not see card info |

We do not log IP addresses, do not set cookies, and do not have any analytics.

## 6. In-app purchases

PennyLoop Pro is purchased through Apple's StoreKit. The transaction (including any card information) is handled entirely by Apple. We receive only an entitlement receipt indicating that you are a paid subscriber.

## 7. Data retention and deletion

Because the developer does not store your data, there is no "delete my account" request to make. To delete all PennyLoop data:

1. Delete the app from your device. All local data is removed.
2. If you used iCloud sync, also delete the data from iCloud at **Settings → [your name] → iCloud → Manage Storage → PennyLoop**.

## 8. Children's privacy

PennyLoop is not directed at children under 13. We do not knowingly collect data from anyone, let alone children.

## 9. Changes to this policy

We may update this policy. The "Last updated" date at the top will reflect any change. Material changes will be announced in-app.

## 10. Contact

Open an issue at <https://github.com/Drinkwater0922/subscription-management-/issues>.

---

# PennyLoop 隐私政策

*最后更新:2026-05-16*

PennyLoop 是一款"本地优先"的订阅追踪器。我们设计它的目标是 —— **开发者永远看不到你的数据**。本文说明 app 处理什么数据、数据存在哪里,以及 app 会发出哪些(极少的)网络请求。

## 1. 我们收集你的什么数据

**我们的服务器一概不收集。** 我们没有后端、没有账号系统、没有注册、没有 analytics SDK、没有广告 SDK、没有任何第三方追踪。

你在 PennyLoop 里输入的所有数据(订阅名、金额、续费日期、分类、备注、网址)都通过 Apple 的 SwiftData 框架**只存在你自己的设备上**。

## 2. iCloud 同步(可选,仅 Pro)

如果你升级了 PennyLoop Pro **且**在设备上登录了 iCloud,你的订阅数据可能通过 **Apple 的 CloudKit** 在你的设备之间同步。数据存在你个人的 iCloud 账号里,由 Apple 加密。**我们看不到任何内容。** 退出 iCloud 或继续使用免费版即可关闭同步。

## 3. 「从照片导入」

当你选一张照片导入订阅时:

- 图片由 Apple Vision 框架**完全在设备本地处理**。
- 图片数据**不会离开你的设备**。
- 我们不保留图片;表单填好后图片即被丢弃。

## 4. 通知

通知由 app 在你的设备上本地排程。我们没有推送服务器。免费版只使用本地通知;Pro 版可能会为价格变动额外排一些本地通知。

## 5. 对外网络请求

PennyLoop 会发起少量网络请求,**任何一个都不包含个人身份信息**:

| 用途 | 接口 | 发送内容 |
|---|---|---|
| 汇率查询(添加外币订阅时) | `api.frankfurter.app` | 货币代码(如 `USD`、`CNY`)+ 日期 |
| 订阅预设目录刷新(可选) | 一个静态目录 URL | 无 |
| 内购 | Apple StoreKit | 由 Apple 处理 — 我们看不到任何银行卡信息 |

我们不记录 IP、不设置 cookie、不做 analytics。

## 6. 内购

PennyLoop Pro 通过 Apple StoreKit 购买。包括银行卡信息在内的全部交易流程都由 Apple 处理。我们只收到一个"已付费"的凭证。

## 7. 数据保留与删除

由于开发者根本不存你的数据,所以没有"删除账号"这种事。删除 PennyLoop 全部数据的方式:

1. 从设备删除 app — 本地数据全部消失。
2. 如果你启用了 iCloud 同步,另外去 **设置 → [你的名字] → iCloud → 管理储存空间 → PennyLoop** 删除 iCloud 端数据。

## 8. 儿童隐私

PennyLoop 不针对 13 岁以下儿童设计。我们不会有意收集任何人的数据,儿童也包括在内。

## 9. 政策变更

我们可能更新本政策。顶部的"最后更新"日期会反映任何更改。重大变更会在 app 内提示。

## 10. 联系方式

请到 <https://github.com/Drinkwater0922/subscription-management-/issues> 提 issue。
