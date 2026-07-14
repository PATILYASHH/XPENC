# Changelog

All notable changes to XPENC are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Release process: see [docs/RELEASING.md](docs/RELEASING.md).

## [Unreleased]

## [1.1.2] — 2026-07-14

Packaging release for F-Droid, addressing the maintainer's review of the
fdroiddata submission. **No functional changes** since 1.1.1.

### Changed
- **Per-ABI versionCode scheme** is now `base × 10 + ABI` (armeabi-v7a = 1,
  arm64-v8a = 2, x86_64 = 3), overriding Flutter's default split offsets so the
  codes match F-Droid's standard `VercodeOperation`. Set in
  `android/app/build.gradle.kts`.
- The Flutter version in `.github/workflows/release.yml` is single-quoted so the
  F-Droid recipe can extract it and build with the same Flutter as CI.

### Note for sideload users
Because the versionCode scheme changed, installing 1.1.2 over a 1.1.1 APK from
GitHub may require an uninstall/reinstall. Your data survives via
**Backup → export** before, restore after.

## [1.1.1] — 2026-07-13

First release distributed on **Google Play** and **F-Droid**. No functional
changes since 1.1.0 — the app still requests no SMS and no internet permission,
runs no analytics, and shows no ads. This release adds the store metadata,
signing and tooling needed to publish.

### Added
- **F-Droid submission kit** — [docs/fdroid/](docs/fdroid/): inclusion-criteria
  audit, draft fdroiddata build recipe, submission guide; plus in-repo
  [fastlane metadata](fastlane/metadata/android/en-US/) (texts, per-versionCode
  changelogs, icon, feature graphic) that F-Droid reads directly.
- **Privacy policy** — [PRIVACY.md](PRIVACY.md), live at
  [getxpenc.vercel.app/privacy](https://getxpenc.vercel.app/privacy) and linked
  from the website footer.
- **Play Store submission kit** — [docs/playstore/](docs/playstore/): store
  listing copy, Data safety answers, content rating, declarations and a release
  checklist, all verified against Google's July 2026 requirements.
- `tool/generate_playstore_assets.py` — generates the 1024×500 Play feature
  graphic from the same geometry as the launcher icons.
- Release builds sign with the upload keystore when `android/key.properties`
  exists, falling back to debug signing otherwise (so `flutter run --release`
  still works for contributors).

### Fixed
- `tool/verify_apk.sh` had a stale, inverted check that **failed** the build
  when `READ_SMS` was absent (the 1.0 rule). It now fails if any SMS permission
  reappears — matching 1.1.0 and Play policy.
- `SECURITY.md` no longer claims the app reads bank SMS.
- Phone screenshots for the store listings (padded to 2:1 so the same set is
  valid on both Google Play and F-Droid).

## [1.1.0] — 2026-07-12

### Changed
- **Bank-SMS auto-capture is paused (coming back).** The `READ_SMS` permission
  made Google Play Protect block direct APK installs — users had to pause
  protection just to install the app. This build requests **no SMS permission
  at all**, so it installs cleanly. The capture pipeline (parser, dedupe,
  Review Inbox, learned rules) is intact behind the `MessageSource` interface
  and will return in a Play-compliant form; cards detected by 1.0.x remain
  reviewable.
- The Message Capture screen now explains the pause instead of offering
  controls; the app-wide **Notifications** toggle moved to Settings.
- Onboarding no longer promises SMS matching when adding a bank.

### Removed
- `READ_SMS` permission, the Kotlin SMS platform channel, and the Dart
  `SmsSource`. A regression test now fails the build if SMS permissions or
  SMS code ever reappear silently.

## [1.0.0] — 2026-07-12

First public release. 🎉

### Added
- **Accounts** — Cash / Bank / Card with opening balances; debit cards & UPI
  linked to their bank so money is never double-counted; credit cards carry
  their own (negative = owed) balance.
- **Transactions** — Income / Expense / Transfer, day-wise grouped list with
  daily totals, filters and search. Transfers are neither income nor expense.
- **Dashboard** — net worth, month in/out, account balances, recent activity.
- **Budgets** — per-category with period windows, live progress and
  once-per-period threshold (80%) / overspend alerts.
- **Bank-SMS auto-capture** — on-device parsing (IPPB template first) into a
  Review Inbox; account matching by last-4; UPI double-SMS dedupe;
  learned merchant rules with **Auto-Approve** (exact match only) and a real
  **Undo** that reverses the posted transaction.
- **Persons (dues & loans)** — they-owe / I-owe entries, optional real account
  movement, partial settlements, running balances. Lending is never expense.
- **Calendar & Cash Reminders** — day-wise in/out grid; reminders that post
  nothing until you confirm ("Mark as paid" opens a prefilled transaction).
- **Insights** — category pie, income vs expense bars, net-worth trend,
  per-account reports — one charting engine, several views.
- **Backup & export** — JSON backup/restore (symmetric — includes the review
  inbox), CSV export shaped for accountants / Tally.
- **Onboarding** — currency, first accounts, seeded default categories.
- Monochrome black/white theme with a true-black AMOLED dark mode.

### Security / correctness highlights
- All amounts stored as **integer paise** — no floating-point money anywhere.
- Ledger is the single source of truth; `recalculateBalances()` repair function.
- 116+ tests including invariant tests (transfers net-zero, no debit-card
  double-count, lending ≠ expense) and regression tests for the 8 defects found
  in the adversarial audit (see structure.md §11.5).
- `tool/verify_apk.sh` gates every shipped APK against the missing
  `libsqlite3.so` class of crash.

[Unreleased]: https://github.com/PATILYASHH/XPENC/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/PATILYASHH/XPENC/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/PATILYASHH/XPENC/releases/tag/v1.0.0
