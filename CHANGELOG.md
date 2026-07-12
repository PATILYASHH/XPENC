# Changelog

All notable changes to XPENC are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Release process: see [docs/RELEASING.md](docs/RELEASING.md).

## [Unreleased]

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
