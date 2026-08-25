# Changelog

All notable changes to XPENC are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Release process: see [docs/RELEASING.md](docs/RELEASING.md).

## [1.5.0] — Unreleased

### Added
- **Persons: Pay/Request via UPI (Beta)** — a person's page offers a "Pay"
  or "Request" button, whichever way the balance runs, pre-filled with the
  outstanding amount. One tap opens a `upi://` intent Android hands to
  whatever app is installed. Google Pay's and PhonePe's own deep-link
  schemes are tried first, falling back to the generic intent either way.
- **Edit person** — a real edit flow at last (previously only Add, Archive
  and Remove existed): UPI ID, phone number, contact and note.
- **Customizable bottom nav** (#70) — pick which two destinations sit in
  the two flexible slots next to the ➕ button, from seven choices
  (Transactions, Persons, Calendar, Budgets, Accounts, Stats, Payees).
  Dashboard and More stay pinned. Every configurable destination also
  gained its own `/more/*` route so it's reachable even when swapped out of
  both slots. Labels under each icon can be turned off.
- **Goals & Loans hub** — Savings Goals is now Goals & Loans, tracking
  money borrowed as a loan alongside goals saved toward, in one place.
- The most-funded goal automatically sorts to the top of the list; goals
  can also carry their own note.
- **Font settings** — Settings → Font: text size, boldness and font family,
  applied app-wide with a live preview.
- **Bold theme** — a near-black theme with a coral-and-gold accent and
  Sora/Manrope typography.
- **Master recovery phrase** (#74) — a 10-word backup unlock method; the
  number of wrong PIN attempts before it's required instead is configurable.
- **Customize Dashboard** — choose which accounts count toward the
  Dashboard's Net Worth figure.
- **Calendar day totals** — selecting a day shows that day's total money
  in and out (Settings → Calendar).
- **Linked transactions** (#68) — link two or more related transactions
  together, and filter the Transactions list to only linked ones with a
  new "Linked" quick-filter chip.
- **Split cash-expense change across two accounts** (#55) — an expense's
  change no longer has to land entirely in one account.
- **Interactive dashboard pie charts** — the Budgets and Spending charts
  drop their permanent legend; tap or hold a wedge to see its name and
  amount centred on the chart instead. A category over its budget gets a
  diagonal hazard-stripe pattern on its wedge, not just a thin ring.
- Redesigned Dashboard hero card, switching between metrics (Total Money,
  Net Worth) via tabs.
- **Bottom spacing** (Settings → Customize bottom nav) — a manual slider
  for phones that misreport their on-screen navigation bar's size, so it
  doesn't overlap the bottom nav bar or the PIN lock screen's keypad (#78).
- **What's New** (More hub) — see what shipped in the current version,
  with where to find it and what it does.

### Changed
- A paused Auto rule moves to an Archived list instead of cluttering the
  active one (#61), the same pattern Accounts and Persons already use.

### Fixed
- The PIN lock screen's keypad could render clipped under the system
  navigation bar on some devices, or mis-position entirely depending on an
  earlier fix's own layout approach — replaced with a scrollable,
  predictably-sized layout (#78).

## [1.4.5] — 2026-08-20

### Added
- **PIN lock timeout** — Settings → Security → "Lock after" lets XPENC wait
  before re-locking instead of always locking the instant it's backgrounded:
  Immediately, or after 1/5/10/15/30/60 minutes (#60).
- **Payee on income** — the Payee field, its autocomplete and the Payees hub
  are no longer expense-only; a salary or any other income can now name who
  paid it, e.g. an employer (#62). The Payees hub shows each payee's net
  flow (income minus expense) instead of assuming every payee is a spend.
- **Preset tags on an Auto rule** — a recurring rule can now carry its own
  set of tags, stamped automatically onto every transaction it posts (#63).

### Fixed
- About screen: the footer could sit right against the system navigation bar
  on a 3-button-nav device — the same class of bug as #14, fixed the same
  way (reading the nav bar inset explicitly) for this screen (#53).

## [1.4.4] — 2026-08-19

### Fixed
- Screenshot OCR (`flutter_tesseract_ocr`) no longer depends on a vendored
  prebuilt `tesseract4android-release.aar` binary blob — the upstream
  pub.dev package bundled it directly in `android/libs/`, which itself
  failed F-Droid's build policy the same way ML Kit did (#57). A local
  fork (`packages/flutter_tesseract_ocr_floss`) resolves the identical
  library from JitPack instead, a trusted repository under F-Droid's
  Inclusion Policy. No Dart-side or user-facing change — verified on a
  real device build that OCR still reads screenshots correctly.

## [1.4.3] — 2026-08-19

### Added
- **OCR corrections** — Settings → Message Capture → OCR corrections lets you
  test a payment-app screenshot against the real on-device OCR+parser
  pipeline, mark whether it read correctly, and optionally send the
  correction (extracted text only, never the image) to help improve parsing
  for more apps and countries over time.
- **Calendar: transfer and upcoming-event dots** — a day with a transfer now
  shows a blue dot alongside the existing income/expense ones, and any open
  reminder or active Auto rule due on a day shows a yellow dot ahead of time,
  turning red once the day arrives or it's overdue (#67).
- **Calendar → transaction detail** — tapping a transaction under a selected
  day now opens its detail screen, the same destination a tap in the
  Transactions tab already opens (#56).
- Double-tap the Transactions tab to scroll its list back to the top (#66).

### Changed
- Screenshot OCR now uses Tesseract instead of Google ML Kit — ML Kit's
  trained-model blobs are proprietary even in the bundled, no-Play-Services
  form, which blocked F-Droid distribution (#57). Fully on-device either way;
  no behavior change for existing users beyond OCR accuracy.
- Website moved to its own domain, **xpenc.in** (was `getxpenc.vercel.app`,
  which still resolves to the same site).

### Fixed
- Release builds no longer request the `INTERNET` permission — a transitive
  declaration from a plugin's Android library that 1.4.2 shipped with, even
  though nothing in XPENC's own code makes a network call (#59).

## [1.4.2] — 2026-08-13

### Added
- **Share a payment screenshot straight into XPENC** — pick XPENC from the
  Share sheet on a Paytm/Google Pay/PhonePe "payment successful" or
  "transaction details" screenshot and it's read entirely on-device (ML Kit
  text recognition, no network call) and parsed into the Review Inbox, the
  same way a shared bank SMS already is. Tuned against real screenshots from
  all three apps — a misread currency glyph glued onto the amount, a stray
  avatar-initial letter next to it, and a "transaction details" layout with
  no sent/received verb at all are all handled (#25).
- **A new theme: Cove** — an ocean-blue accent over noticeably bigger,
  softer "squircle" cards and bolder headlines, in the spirit of Samsung's
  One UI 9. Settings → Theme; every existing theme renders exactly as
  before.
- **Hide amounts, right where they're shown** — a small eye icon now sits
  next to every hero balance (the Dashboard's Total Money card, the
  Accounts screen's total, an account's own balance) instead of one
  disconnected toggle in the top bar. Tapping any one of them still masks
  every amount app-wide.

### Changed
- **The top bar is decluttered and consolidated.** Dashboard, Persons and
  More used to render their own full-size title bar directly underneath the
  persistent top bar — nearly 190dp of stacked chrome before any real
  content appeared. Their titles now live in the shared bar itself, which
  stays a standard toolbar height; every screen reached from the More hub
  (Accounts, Auto, Payees, ...) had its own oversized title bar shrunk to
  match, so the whole app now has one consistent chrome height instead of
  three different ones. Search and Filter on the Transactions tab moved
  into the same shared bar instead of sitting in a separate title row of
  their own. The redundant Calendar shortcut was dropped from the bar
  (still one tap away via More → Calendar & Reminders); Review Inbox
  stayed, since it has no other entry point at all.

### Fixed
- **F-Droid's reproducible build could fail on a drifted lock file** — our
  release and CI workflows ran a plain `flutter pub get`, which silently
  rewrites `pubspec.lock` if it's ever out of sync with `pubspec.yaml`.
  F-Droid's own build enforces strict lock-file fidelity with no such
  fallback, so a drift invisible to us here could break their build only
  after a tag was already published. All three workflows now enforce that
  same strictness themselves, so a drift fails our own CI immediately
  instead (#57).

## [1.4.1] — 2026-08-11

### Fixed
- **Database migration crash on update** — a database whose stored version
  undercounted its real (already-migrated) shape — for example, a build from
  the rolling BETA-branch APK channel that applied a step under a version
  number later reused for something else — could hit `duplicate column name`
  and never open again. Every migration step now checks whether its
  column/table already exists before touching it, so a mismatch like this is
  a no-op instead of a crash (#49, #50).
- **Couldn't edit a transaction's amount** — opening an existing transaction
  prefilled the keypad with its amount (e.g. "15.44"), which already has two
  decimal digits — the keypad's own two-decimal-place guard then rejected
  every digit tap from the moment the screen opened, so only backspace
  appeared to work. The first tap after loading now clears the stale value
  and starts fresh, same as a calculator after a result (#45).
- **Goals from a 1.3.0 → 1.4.0 upgrade could open "already funded"** — that
  migration seeded a goal's starting balance from its old linked account's
  whole balance, with nothing to explain how it got there. Goal detail's ⋮
  menu now has "Fix starting amount" to correct it directly (#44).
- **No way back in from Download Data** — that screen could export a JSON
  backup but not import one, and a file exported from it wasn't recognised
  as a "known backup" anywhere else in the app either. Download Data now has
  its own Import action, sharing the exact same restore path as the Backup
  screen.

### Added
- **Share a bank SMS straight into XPENC** — pick XPENC from the Share sheet
  on a message in your SMS/bank app and it's parsed into the Review Inbox,
  same as auto-capture — a Play-compliant way in that needs no READ_SMS
  permission at all (#26).
- **Import transactions from a bank CSV statement** — a signed Amount column
  or separate Withdrawal/Deposit columns are both auto-detected from the
  file's own headers (covers most Indian bank exports), with a mapping
  screen to check or correct before anything is imported. New entry point
  in Download Data (#17).
- **Split payment across accounts** — one purchase paid from more than one
  account (part bank, part cash, ...) posts as linked transactions sharing
  one category, with a banner on each leg's detail page pointing at the
  others so the full picture is always one tap away (#43).
- **Quick add from a notification** — an opt-in (Settings → Notifications)
  standing notification with "Add expense" / "Add income" buttons. Reply
  with an amount and it posts immediately — no need to open the app.
  Deliberately uncategorised (there's no UI for that in a reply) and posts
  to an account you choose in Settings, defaulting to your first one (#38).
- **Two new home-screen widgets** — Budgets (your top budgets, closest to
  their limit first) and Quick Add (just the "+ Expense" / "+ Income"
  shortcuts, enlarged), alongside the existing Balance widget. New
  Settings → Widgets screen to add any of them straight from the app where
  the launcher supports it.
- **Calendar "today" button** — jumps straight back to the current month
  (#46).
- **Archive inactive Auto rules** — paused rules collapse into a single "N
  paused" row instead of crowding out what's still running, with a tap to
  reveal them (#51).
- **Configurable PIN length** — Settings → Security now offers a 4, 5 or
  6-digit passcode instead of a fixed 4 (#18).
- **Subcategory spending breakdown** — Stats' "Spending by category" pie can
  now show every subcategory individually instead of only rolling up to its
  parent (#40).

## [1.4.0] — 2026-08-08

### Fixed
- **Release signing** — every GitHub release build was falling back to a
  fresh, randomly-generated debug key because no permanent release keystore
  existed. Each release was signed differently from the last, so Android
  refused to install an update over a previous version and forced an
  uninstall. From this release on, every build (beta and stable) is signed
  with the same permanent key. **One-time migration:** anyone updating from
  v1.3.0 or earlier must back up (Settings → Backup), uninstall, install
  this version, then restore — this is the last time that'll be necessary.

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
  [xpenc.in/privacy](https://xpenc.in/privacy) and linked
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

[Unreleased]: https://github.com/PATILYASHH/XPENC/compare/v1.4.5...HEAD
[1.4.5]: https://github.com/PATILYASHH/XPENC/compare/v1.4.4...v1.4.5
[1.4.4]: https://github.com/PATILYASHH/XPENC/compare/v1.4.3...v1.4.4
[1.4.3]: https://github.com/PATILYASHH/XPENC/compare/v1.4.2...v1.4.3
[1.4.2]: https://github.com/PATILYASHH/XPENC/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/PATILYASHH/XPENC/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/PATILYASHH/XPENC/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/PATILYASHH/XPENC/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/PATILYASHH/XPENC/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/PATILYASHH/XPENC/compare/v1.1.3...v1.2.0
[1.1.3]: https://github.com/PATILYASHH/XPENC/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/PATILYASHH/XPENC/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/PATILYASHH/XPENC/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/PATILYASHH/XPENC/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/PATILYASHH/XPENC/releases/tag/v1.0.0
