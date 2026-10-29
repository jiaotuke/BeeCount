# BeeCount · Android Income and Expense Capture

[中文](README.md)

A personal adaptation of BeeCount that captures outgoing payments and incoming receipts through notifications, readable success pages, and optional local screenshot OCR. Candidates require user review before saving income or expenses.

**The customized source is on the [`payment-auto-capture` branch](https://github.com/jiaotuke/BeeCount/tree/payment-auto-capture).** The `main` branch serves as the project overview; switch to the feature branch to inspect or build this version.

Only source code is published here. No APK or app-store distribution is provided.

## What this version adds

| Addition | Implementation |
| --- | --- |
| Payment notification listener | Reads authorized WeChat and Alipay payment and receipt notifications to create candidate expenses and income. |
| Incoming payment detection | Recognizes explicit receipt-success or credited-payment text, including transfers explicitly marked as received by you. Pending transfers, QR requests, and generic balance alerts are not inferred as income. |
| Success-page reader | Uses Android accessibility to read visible text on supported outgoing-payment and receipt-success pages. It does not require a manual screenshot, click buttons, or initiate payments. |
| Optional local screenshot OCR | Off by default, with separate consent. Android 11+ only; initially restricted to the WeChat received-transfer detail activity. Bundled Chinese OCR processes the approved window in memory without uploading recognition inputs/outputs or saving screenshots. |
| Local review inbox | Native services persist candidates with their source, time, original text, amount, and merchant. |
| Ambiguous amount handling | Missing or multiple amounts remain unresolved until the user checks the actual paid amount. |
| Duplicate handling | Separates income and expense identities before deduplicating order identifiers or notification events. Flags same-app, same-amount, same-direction pending records within a short time window. |
| Confirm before saving | Shows income and expense candidates separately and opens the corresponding category selector. Reuses the transaction editor for amount, category, and account review. Saving removes the candidate; canceling retains it. |
| Save recovery | Associates a stable candidate identifier with the saved transaction to reduce duplicate saves after an interrupted acknowledgement. |
| Separate controls and permissions | Both capture modes are off by default, with explanations, Android settings links, and permission status. |
| Validation tools | Adds payment parser tests, review-page tests, native compilation checks, and APK inspection scripts. |

The existing ledger, account, category, reporting, and import/export structures are inherited from upstream.

## How to use

1. Build and install the personal test version from the feature branch, then create a local ledger.
2. Open **Mine → Automation → Payment capture (experimental)**. The new settings page currently uses Chinese labels.
3. Enable the desired capture modes and grant notification access and/or accessibility permission in Android settings. If page text is unavailable, optionally enable local screenshot OCR after reviewing its separate explanation.
4. After paying or receiving money, return to the capture page and refresh the pending income/expense list.
5. Check the original text, amount, category, and account before saving. Ignore unwanted or duplicate candidates.

Disable either in-app switch to stop its processing, or revoke the corresponding Android permission.

## Limitations

- This version provides **automatic capture followed by user confirmation**, not unattended transaction posting.
- Screenshot fallback is restricted to the explicitly supported WeChat transfer-detail activity. Chats, password pages, QR requests, generic WebViews, Alipay, and other payment pages are not enabled for screenshot OCR. Secure-window capture errors stop the attempt.
- Parsing targets CNY expenses and explicit receipts from WeChat and Alipay. Refunds, top-ups, withdrawals, repayments, unconfirmed transfers, and generic transfer alerts are skipped. An explicitly received personal transfer still needs review: ignore transfers between your own accounts.
- Missing or hidden notifications, inaccessible page text, and Android background restrictions may cause missed captures.
- Without an order identifier, cross-source records cannot always be matched reliably. Equal amounts may represent separate purchases.
- The pending inbox holds up to 500 records. Capture pauses at capacity; reconcile payments made during that interval against the original payment history.
- Background behavior depends on the system keeping the native services available and still requires device testing.

## Data handling

Notifications and page text use local rules. Optional screenshot fallback uses a bundled ML Kit Chinese OCR model without cloud LLM calls. Screenshots are processed in memory and released, never added to the gallery; recognized candidate text is stored in application-private SharedPreferences, not an encrypted vault.

Recognition images and text are not uploaded. ML Kit may transmit SDK performance/utilization metrics or request compatibility information; see [third-party notices](THIRD-PARTY-NOTICES.md). Turning off page capture also stops screenshot fallback.

Confirmed transactions follow the original application's storage and synchronization behavior, according to the user's ledger and cloud settings.

## Build

The verified toolchain was Flutter 3.27.3, Dart 3.6.1, Java 17, Android SDK 36, and Build Tools 35.

```bash
git clone --branch payment-auto-capture https://github.com/jiaotuke/BeeCount.git
cd BeeCount
flutter pub get
flutter run --flavor dev
```

Build a local ARM64 debug APK:

```bash
flutter build apk --flavor dev --debug --target-platform android-arm64
```

On Windows, use an ASCII build path to avoid native shader compiler path issues. Configure toolchains and dependency caches in the D-drive project directory before downloading them.

## Verification status

Affected-page static analysis, income/expense parser and screenshot-scope tests, and nine widget tests passed, including separate screenshot consent, default-off behavior, OS restrictions, income categories, and legacy candidates. Full Android builds also compile the ML Kit screenshot service.

USB inspection on Honor MTN-AN80 confirmed installation, permissions, and bound services. WeChat 8.0.79 exposed only one empty node on the received-transfer page, motivating the opt-in OCR fallback. See the [implementation and validation notes](https://github.com/jiaotuke/BeeCount/blob/payment-auto-capture/docs/payment-capture-prototype.md) for the actual device results and remaining limitations.

Version 0.2.2 successfully captured one real received WeChat transfer as pending income with the correct displayed amount. It did not post the transaction automatically. Other payment pages, Alipay screenshot OCR, real notification triggers, and long-term background behavior remain unverified by this test.

## Attribution and license

Based on [TNT-Likely/BeeCount source](https://github.com/TNT-Likely/BeeCount), authored by **sunxiao (TNT-Likely)**. Original copyright: **Copyright (c) 2024–2026 sunxiao**.

Original author, copyright, license, and third-party notices are retained. Use, modification, and distribution remain subject to [LICENSE](LICENSE), [LICENSE_EN](LICENSE_EN), and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). This adaptation does not change the upstream license terms.
