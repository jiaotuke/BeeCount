# BeeCount · Android Payment Capture

[中文](README.md)

A personal adaptation of BeeCount focused on capturing payment information without manually taking screenshots. Notifications and readable payment-success pages become local candidates that the user reviews before saving a transaction.

**The customized source is on the [`payment-auto-capture` branch](https://github.com/jiaotuke/BeeCount/tree/payment-auto-capture).** The `main` branch serves as the project overview; switch to the feature branch to inspect or build this version.

Only source code is published here. No APK or app-store distribution is provided.

## What this version adds

| Addition | Implementation |
| --- | --- |
| Payment notification listener | Reads authorized payment notification text from WeChat and Alipay to create candidate expenses. |
| Payment-success page reader | Uses Android accessibility to read visible text on supported success pages. It does not require a manual screenshot, click buttons, or initiate payments. |
| Local review inbox | Native services persist candidates with their source, time, original text, amount, and merchant. |
| Ambiguous amount handling | Missing or multiple amounts remain unresolved until the user checks the actual paid amount. |
| Duplicate handling | Deduplicates matching order identifiers or notification events and flags same-app, same-amount pending records within a short time window. |
| Confirm before saving | Reuses the transaction editor for amount, category, and account review. Saving removes the candidate; canceling retains it. |
| Save recovery | Associates a stable candidate identifier with the saved transaction to reduce duplicate saves after an interrupted acknowledgement. |
| Separate controls and permissions | Both capture modes are off by default, with explanations, Android settings links, and permission status. |
| Validation tools | Adds payment parser tests, review-page tests, native compilation checks, and APK inspection scripts. |

The existing ledger, account, category, reporting, and import/export structures are inherited from upstream.

## How to use

1. Build and install the personal test version from the feature branch, then create a local ledger.
2. Open **Mine → Automation → Payment capture (experimental)**. The new settings page currently uses Chinese labels.
3. Enable the desired capture modes and grant notification access and/or accessibility permission in Android settings.
4. After paying, return to the capture page and refresh the pending list.
5. Check the original text, amount, category, and account before saving. Ignore unwanted or duplicate candidates.

Disable either in-app switch to stop its processing, or revoke the corresponding Android permission.

## Limitations

- This version provides **automatic capture followed by user confirmation**, not unattended transaction posting.
- Initial parsing targets CNY expenses from WeChat and Alipay. Transfers, refunds, top-ups, and repayments are skipped.
- Missing or hidden notifications, inaccessible page text, and Android background restrictions may cause missed captures.
- Without an order identifier, cross-source records cannot always be matched reliably. Equal amounts may represent separate purchases.
- The pending inbox holds up to 500 records. Capture pauses at capacity; reconcile payments made during that interval against the original payment history.
- Background behavior depends on the system keeping the native services available and still requires device testing.

## Data handling

The added capture flow uses local text rules and does not depend on AI or upload notification/page text. Candidates are stored in application-private SharedPreferences, not an additional encrypted vault.

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

Static analysis of the affected Dart pages, parser tests, and three review-page widget tests passed. A complete ARM64 debug APK was built and its signature, ZIP alignment, payload, and payment service declarations were checked.

Device installation, startup, actual payment capture, and background survival have not been verified. See the [implementation and validation notes](https://github.com/jiaotuke/BeeCount/blob/payment-auto-capture/docs/payment-capture-prototype.md) for details.

## Attribution and license

Based on [TNT-Likely/BeeCount source](https://github.com/TNT-Likely/BeeCount), authored by **sunxiao (TNT-Likely)**. Original copyright: **Copyright (c) 2024–2026 sunxiao**.

Original author, copyright, license, and third-party notices are retained. Use, modification, and distribution remain subject to [LICENSE](LICENSE), [LICENSE_EN](LICENSE_EN), and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). This adaptation does not change the upstream license terms.
