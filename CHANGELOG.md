# Changelog

All notable changes to XPENC are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Release process: see [docs/RELEASING.md](docs/RELEASING.md).

## [Unreleased]

Beta track for 1.4.0 — everything below is on the `BETA` branch, not yet
tagged or released.

### Added
- **Envelope Mode** — an opt-in, per-account "every rupee has a job" budget.
  Turn it on for one account (Settings live on that account's own detail
  page) and every expense on it needs a category, whose balance is funded
  from that account's own Ready to Assign. A transfer or lending payment out
  of an envelope account that would dip into an already-claimed category
  now asks which one to draw the difference from, instead of letting the
  envelope silently keep claiming money that already left. Dashboard shows
  Ready to Assign per envelope account.
- **Budget Detail page** — tapping a category on Budgets now opens a
  dedicated page: every transaction in it this period, an Edit shortcut, and
  its own PDF statement download.
- **Combined account statement** — a new Statement action on the Accounts
  screen exports every account's transactions in one PDF, merged
  chronologically rather than grouped by account, with transfers clearly
  marked.
- **Onboarding**: a currency step up front, and first-launch auto-detection
  of an existing XPENC backup on the phone — offers to restore it (with the
  usual folder-access confirmation) before you ever fill in an account.
- **Biweekly recurring rules** — a frequency between weekly and monthly, for
  a loan repayment or anything else that lands every two weeks (#24).
- **Variable-amount recurring rules** — a rule (e.g. a salary that depends on
  hours worked) can be marked "amount varies each time": it still posts on
  schedule using the usual amount as a placeholder, but the posted
  transaction is flagged for review instead of silently trusting a guess
  (#19).
- **Screenshot blocking** — a Settings toggle that blocks screenshots and
  screen recording, and blanks the recent-apps thumbnail, via Android's
  native `FLAG_SECURE` (#15).
- **Savings Goals redesign** — a goal is now a real account, funded and
  drawn down by ordinary transfers, instead of a passive tracker that only
  read another account's balance. Counts toward net worth and stays out of
  income/expense automatically, same as every other account. Start a fresh
  goal, or turn an existing account into one; Add funds / Withdraw
  shortcuts sit right on the goal screen (#30).
- **Budget notes** — an optional note field on any budget, for context on
  what it's for or anything to remember about it (#34).
- Two more category icons: bar chart and currency exchange (#31).

### Fixed
- Every amount field that hardcoded the ₹ symbol now reads the currency you
  actually picked in Settings — it was wrong for anyone not using rupees,
  most visibly on the Persons lending/borrowing screen (#33).
- Several bottom sheets only left room for the keyboard, never the system
  navigation bar, so content could sit flush against — or behind — a
  3-button nav bar. Invisible on gesture navigation, obvious on a real
  button bar (#14).
- The calendar view now shows a plain dot per direction (income/expense)
  instead of the actual amount — reads clearer at a glance and shows
  nothing if the screen is glimpsed by someone else (#28).
- Dropped the unused `ACCESS_NETWORK_STATE` permission — a WorkManager
  default XPENC never needed, since the app makes no network calls (#27).

## [1.3.0] — 2026-08-05

Full backward compatible: the database migrates itself in place (v8 → v18,
additive columns and five new tables), so updating over an existing install
keeps every account, transaction and setting.

### Added
- **Passcode lock** — **Settings → Security**: a 4–6 digit PIN gates the app
  on open, with an optional biometric (fingerprint/face) unlock on top. A
  backup taken before a passcode existed never silently turns the lock off
  on restore — the passcode is device-local and survives a backup/restore
  untouched.
- **Home screen widget** — an Android widget showing net worth at a glance,
  updated whenever the ledger changes; tapping it opens the app.
- **Savings goals** — a new **Goals** hub for saving toward a target amount,
  with progress and a running history of contributions.
- **Tags** — free-form labels on any transaction, beyond category. A **Tags**
  shortcut sits in the Add Transaction app bar (always visible, not buried
  below the keypad) with an autocomplete drawn from tags already used.
- **Receipt attachments** — attach a photo to any transaction from the same
  always-visible app-bar shortcut. Picked through the system file picker, not
  the camera, so no new permission is needed; the image is copied into the
  app's own storage immediately.
- **Shopping lists** — shopping is now shopping *lists*: named, colour-coded
  lists instead of one flat list. Existing items migrate onto a default list
  automatically.
- **Archived Accounts / Archived Persons** — dedicated screens (**More →
  Accounts/Persons → Archived**) to review and unarchive anything archived
  earlier, instead of it just disappearing.
- **Prepaid Balance account type** — for a canteen key fob, gift card or
  transit card: money you already loaded onto it. Unlike Pay-later, it is
  **not** a liability — spending it draws down a real balance, exactly like
  Cash or Bank.
- **Durable, automatic backups** — backups now live in the public
  `Download/BACKUP XPENC` folder (via Android's MediaStore), so they survive
  the app being uninstalled — no storage permission needed. An optional
  schedule (daily / monthly / custom) runs opportunistically on app open,
  with configurable retention. "Find existing backups" recovers the on-device
  index after a reinstall with one folder-picker consent.
- **Clear all data** — **Settings → Clear all data** wipes the ledger back to
  the same defaults a new install gets (after an automatic safety backup).
  Preferences and backup history are left alone.
- **Income & Expense Report PDF** — download a period summary (category
  breakdown plus the same headline numbers Stats shows) from the Stats
  screen, alongside the existing per-account and per-budget statement PDFs.
- **Editable person ledger entries** — tap an entry on a person's ledger to
  edit it (direction, account, amount, date), instead of only delete-and-redo.
- **Budget parent/child cap** — a subcategory's budget can no longer exceed
  its parent's, in either direction (raising a child above its parent, or
  shrinking a parent below an existing child). The Budgets screen threads
  subcategories under their parent, indented with a connecting line.

### Changed
- Tags and Receipt moved to always-visible app-bar shortcuts on Add
  Transaction, instead of cards buried at the bottom of a scrollable list —
  every feature now stays reachable without scrolling past the keypad.

### Fixed
- The on-screen numpad no longer overlaps the system keyboard when entering a
  split expense's per-category amount.
- Editing any existing budget no longer crashes — `upsertBudget`'s
  insert-on-conflict only ever targeted the primary key, so the real
  constraint (one budget per category) raised an uncaught database error
  instead of updating the row.
- **Budget totals no longer double-count a parent and its children.** A
  subcategory's budget is a sub-allocation within its parent's cap, not
  additional spend — Food ₹2,000 with Junk food ₹1,000 and Dinner ₹1,000
  now reads ₹2,000 budgeted, not ₹4,000. Fixed in both the Budgets screen's
  "This month" summary and the budget statement PDF.
- **Backup/restore no longer drops Recurring Rules.** The Auto (recurring
  payments/income) feature was missing from the backup format entirely, so
  restoring a backup silently deleted every recurring rule. It now round-trips
  like everything else.

### Upgrade notes
- **No reinstall needed.** The schema migrates automatically (v8 → v18,
  additive only). Existing data is untouched; new features start empty
  (no tags, no goals, no passcode, auto-backup off) until you use them.

## [1.2.1] — 2026-07-30

Full backward compatible: the database migrates itself in place (v6 → v8,
additive columns and one new table), so updating over an existing install
keeps every account, transaction and setting.

### Added
- **Payee** — record who an expense was paid to, with autocomplete drawn from
  past entries. Searchable/visible on the Transactions list and transaction
  detail. A new **Payees** hub (**More → Payees**) lists everyone you've paid,
  ranked by total spent, with a tap-through history and a rename action that
  merges two spellings of the same payee into one.
- **Auto** (recurring payments) — a new **Auto** hub (**More → Auto**) for
  fixed expenses and income that post themselves on a schedule (daily,
  weekly, or monthly on a chosen day), with no confirmation step. Notifies a
  configurable number of days ahead of the balance an auto-payment will need.
  Missed occurrences (app closed for a few days) are backfilled with their
  correct historical dates the next time the app opens. A rule can be paused
  or deleted without touching transactions it already posted.
- **Account removal** — holding an account now offers **Archive** (reversible,
  hides it) or **Remove** (permanent). Removal only succeeds on an account
  nothing has touched yet — one with no transaction history, no debit card
  drawing from it, and no reminder, merchant rule or Auto rule naming it;
  anything used must be archived instead.
- **Statements** — download a PDF from any account's detail screen (This
  month / Last month / a custom range) shaped like a bank statement: opening
  balance, a dated Debit/Credit/Balance table, closing balance. The Budgets
  screen can similarly download a per-month budget statement (Budgeted /
  Spent / Remaining per category). Both go through the same local-file →
  share-sheet flow as the existing CSV/JSON export — nothing leaves the
  device unless you choose to send it.

### Upgrade notes
- **No reinstall needed.** The schema migrates automatically (v6 → v8,
  additive only). Existing transactions simply have no payee and no
  recurring-rule link until you use the new features.

## [1.2.0] — 2026-07-21

The first **feature** release since 1.1.0 — subcategories, money you're owed on
the dashboard, any world currency, and one-tap import to move to a new phone.
Fully backward compatible: the database migrates itself in place, so updating
over an existing install keeps every account, transaction and setting.

### Added
- **Subcategories** — categories can now nest one level deep (e.g. *Food →
  Groceries, Restaurants*). A subcategory's spending rolls up into its parent
  across the dashboard, Stats and reports, and a budget set on a parent covers
  its whole subtree. Manage them in **More → Categories**; pick them while
  adding a transaction by drilling into a parent.
- **Dues & owes on the dashboard** — a new **People** section shows what you'll
  get and what you'll pay, over the people who still owe you or whom you owe.
- **All world currencies** — choose from ~90 currencies (Bangladeshi Taka
  included) in **Settings → Currency**. Amounts reformat everywhere instantly.
  A **Show currency symbol** switch renders plain numbers for any currency
  whose symbol isn't carried.
- **Import a backup file** — **More → Backup & Restore → Import from file**
  loads a backup the app didn't write, so you can move your whole ledger from
  one phone to another: export on the old phone, send the file across, import
  on the new one. A safety copy of current data is saved before every import.

### Changed
- **Spending breakdowns group by top-level category.** With subcategories in
  play, the dashboard *Spending* card and the Stats pie now attribute a child's
  spend to its parent.
- `share_plus` pinned to `^12.0.2` so it shares `win32 ^5` with the new
  `file_picker` dependency. No behavioural change.

### Upgrade notes
- **No reinstall needed.** The schema migrates automatically (v4 → v6, additive
  columns only). Existing categories become top-level; currency stays INR with
  its symbol shown until you change it.
- **Export a backup first anyway** (**More → Download Data → Export JSON**). If
  you install a build signed with a *different* key than the one on your phone,
  Android forces an uninstall, which wipes data — import the backup afterwards.
- See the [Upgrade Guide](wiki/Upgrade-Guide.md) and
  [Release Notes](wiki/Release-Notes-1.2.0.md) for the full walkthrough.

## [1.1.3] — 2026-07-14

Packaging fix for F-Droid, from the fdroiddata review. **No functional
changes** since 1.1.2.

### Changed
- The Android Gradle Plugin's **"Dependency metadata" signing block** is now
  excluded from the APK (`dependenciesInfo { includeInApk = false }` in
  `android/app/build.gradle.kts`). F-Droid's APK scanner rejects that block;
  it has no effect on the app.

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

[Unreleased]: https://github.com/PATILYASHH/XPENC/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/PATILYASHH/XPENC/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/PATILYASHH/XPENC/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/PATILYASHH/XPENC/compare/v1.1.3...v1.2.0
[1.1.3]: https://github.com/PATILYASHH/XPENC/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/PATILYASHH/XPENC/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/PATILYASHH/XPENC/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/PATILYASHH/XPENC/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/PATILYASHH/XPENC/releases/tag/v1.0.0
