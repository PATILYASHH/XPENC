# XPENC — Structure & Plan

> Everything about the app lives here.
> Personal daily money-tracking app: income, expenses, transfers, debts, budgets, alerts.
> *(Formerly "Money Manager" — see §0 for what the rename did and did not touch.)*

---

## 0. Brand & identity

| | |
|---|---|
| **Name** | **XPENC** — "Money, tracked honestly." |
| **applicationId** | `com.yash.xpenc` *(was `com.yash.money_manager`)* |
| **Developer** | Yash Patil · GitHub [@PATILYASHH](https://github.com/PATILYASHH) · [in/patilyasshh](https://www.linkedin.com/in/patilyasshh/) |
| **Mark** | White "X" on a near-black squircle. Two stadium bars crossed at right angles; the ascending bar is punched out of the descending one by a thin **transparent** seam, so the strokes stay legible at 48 dp instead of merging into a blob. |
| **Palette** | Monochrome. Ink `#FFFFFF`, tile `#17171A → #000000`. True black, AMOLED-friendly, matches the default `mono` theme. |

**One definition, every asset.** `tool/generate_icons.py` rasterises the legacy
launcher icons, the round icons, the adaptive foreground/background, the Android 13
themed (monochrome) vector, both splash marks and the web favicons from a single
`Geometry`. Adaptive framing is *derived* from the legacy one (`LEGACY.scaled(72/108)`)
so the two come out optically identical rather than hand-matched. Re-run it after
touching any constant. `lib/core/branding/brand_mark.dart` redraws the same geometry
as a `CustomPainter` for in-app use — the numbers are duplicated across the Python/Dart
boundary, and both files say so.

### ⚠️ Renamed vs. deliberately NOT renamed

The rename stopped at the skin. Three identifiers kept their old names because
they are **keys, not branding** — each has a comment in-code saying so:

| Identifier | Value | Why it survived |
|---|---|---|
| Drift database file | `money_manager` | A persistence key. No user sees it. Renaming it points the app at a fresh, empty DB and silently loses the ledger of anyone whose data directory carries over. |
| `MethodChannel` | `money_manager/sms` | Must match `MainActivity.CHANNEL` byte for byte. **No test covers the pairing** — Dart tests use `FakeMessageSource` — so a cosmetic rename kills SMS capture with nothing failing to warn you. |
| Backup `formatVersion` | *(unchanged)* | The backup format carries **no app-name magic string**; `importAll` validates `formatVersion` + the presence of `accounts`/`transactions`. Old "Money Manager" backups therefore restore into XPENC untouched. This is the migration path off the old `applicationId`. |

> **The applicationId change is the one destructive act.** Android treats a new
> `applicationId` as a different app: it installs *alongside* the old build with its
> own empty private data directory. Nothing migrates. The recovery path is
> **Backup & Restore** — export JSON from the old app, import it into XPENC.
> After the first Play Store upload the id can never change again, which is why it
> was done now.

**Version display.** `AppInfo.version` / `AppInfo.buildNumber` are constants mirroring
the pubspec's `version:` line, not a `package_info_plus` lookup — that plugin answers
over a platform channel, so every widget test rendering About would need a mock.
`test/branding_test.dart` parses `pubspec.yaml` and fails the build if they drift,
which buys the same guarantee for no dependency and no mocking.

---

## Decisions locked

| Decision | Choice | Why |
|---|---|---|
| Platform | **Flutter (Android)** | One codebase you already know; native local notifications; offline; log on the go. iOS later from same code. |
| Storage | **Local-first SQLite + optional backup** | Private, fast, fully offline. Money data stays on-device. Export/backup added later. |
| Scope | **MVP first, then expand** | Ship a working core fast, layer the rest in phases. |
| Currency | **₹ INR default** (configurable) | Kolhapur / India. |
| Money precision | **Integer paise (not double)** | Floats corrupt money math. Store `1250` = ₹12.50; format only at display. |

---

## 1. The mental model (the core — get this right first)

Four **separate** concepts. Apps that blur these end up with reports that lie.

- **Account** = *where money sits*. Every account has a **type: Cash / Bank / Card**. The three are *types*, not the accounts themselves — the user creates named accounts under each type and picks which one paid at transaction time:
  - **Cash** → "Cash" (add more if needed: wallet, home cash)
  - **Bank** → "Yes Bank", "IPOs", … (user adds each)
  - **Card** → "Yes Bank Credit Card", "Yes Bank Debit Card", … (user adds each)

  **The debit-card / UPI catch (money must stay honest):**
  - A **debit card** spends your *Bank* money — it is **not** a separate pot. Giving it its own balance double-counts the same rupees (Bank + Debit Card). So a debit card is **linked to a Bank account**: picking it at pay time deducts from that bank and records "paid via Yes Bank Debit Card". No independent balance.
  - **UPI / GPay** = same as a debit card — a payment *method* linked to a bank. Optional to add; never a storage location.
  - A **credit card** *is* separate — it's **borrowed** money. Its own account, balance goes **negative** (= what you owe). Paying the bill = transfer **Bank → Credit Card**. This is the only "Card" that holds its own balance.

  > Net worth sums only balance-holding accounts (Cash, Bank, Credit Card). Linked instruments (debit cards, UPI) are not summed — they draw from their bank.
- **Category** = *what a transaction was for*. Income categories (Salary, Profit, Gift…) and Expense categories (Rent, Food…). Categories **classify**; they don't hold balances.
- **Transaction** = one ledger entry. Three types:
  - **Income** → increases one account, tagged with an income category.
  - **Expense** → decreases one account, tagged with an expense category.
  - **Transfer** → moves money account→account. **Not** income, **not** expense. Must never count in budgets or income/expense reports.
- **Person (Due / Owe)** = a separate **Persons** section. Add a person by name, then log entries under them: **They owe** (you lent → they owe you) or **I owe** (you borrowed → you owe them). The app keeps each person's **running balance** and a total across everyone.
  - **Lending really moves money.** Picking an account creates a real ledger row (`personOut` / `personIn`), so your balance changes and the movement appears in **Transactions** and the account's history. Money is never seen to vanish.
  - It is still **never income or expense** — excluded from month totals, budgets and category spend. *Lending is not spending; being repaid is not earning.*
  - The **transaction** is the source of truth for money; the **person entry** is the source of truth for who owes whom. `recalculateBalances()` reads only transactions, so a loan can never be double-counted.
  - "Don't move money (just note it)" still exists, but is no longer the default.

> **Invariant:** total net worth = sum of all account balances. A transfer keeps that total unchanged; income raises it; expense lowers it. If the numbers ever disobey this, it's a bug.

**Persons — how it connects to money:**
- Each person has a **net balance**: **+** = they owe you (receivable), **−** = you owe them (payable). Sums to a headline "you'll get ₹X / you'll pay ₹Y".
- An entry can **optionally move real money** through an account (checkbox "money came from / went to <account>"). Lend Ram ₹500 cash → Cash −500 **and** Ram "they owe +500".
- **Lending/borrowing is NOT income or expense.** These account movements are tagged as *person movements* so they never count in expense budgets or income/expense reports (same way transfers don't).
- **Settle** = log the opposite entry (Ram repays ₹500 → account +500, his balance back to 0). Partial repayments supported.
- App-only mode: you can log a debt without touching an account (just noting "Ram owes me 500") — account linkage stays optional per entry.

---

## 2. Features

### MVP (Phase 1–2 — the shippable core)
- Multiple **accounts** with balances (Cash, Bank, Card) + opening balance
- Add **Income** / **Expense** / **Transfer** (transfer = cash↔bank etc.)
- **Categories** for income & expense (seeded defaults + custom, icon + color)
- **Transactions list** — grouped by day, daily totals, filter by account/type/category/date, search
- **Dashboard** — total net worth, this-month income vs expense, account balances, recent activity

### Phase 3+ (expand)
- **Budgets** per category (weekly / monthly / custom period, configurable start day)
- **Notifications** — budget nearing limit (e.g. 80%), overspent (>100%), debt due-date reminders, optional daily "log your spends" reminder
- **SMS Auto-Capture** — read bank transaction SMS on-device, parse them, queue as review cards; user assigns a category and it posts to the ledger (see §8)
- **Persons (Due & Owe)** — add persons, log "I owe / they owe" entries, per-person running balance, optional account movement, due dates, partial settlements, history
- **Reports / Insights** — spending by category (pie), income vs expense over time (bar), net-worth trend (line), per-account breakdown
- **Backup / Export** — JSON + SQLite file export/import; Google Drive backup later
- **Settings** — currency, theme (minimal black/white), budget start day, notification toggles

- **Auto Spend** — recurring expense / income / transfer on a fixed date (EMI, rent, salary), reconciled against SMS (see §9)
- **Calendar** — month grid with date-wise in/out; upcoming Auto Spends on future dates
- **Stats & Account Reports** — deeper analytics and per-account breakdowns
- **Download Data** — CSV / JSON export (accountant / Tally friendly)

### Nice-to-have (later)
- Attach photo receipt to a transaction
- Multi-currency, tags, split transactions
- App-lock (PIN / biometric) — sensible for a money app
- CSV export for accountant / Tally

---

## 3. Data model (SQLite via Drift)

```
accounts        (id, name, type[cash|bank|card], card_kind[credit|debit|null],
                 linked_account_id?   -- debit card / UPI → the bank it draws from
                 account_last4?, card_last4?, sms_senders[]   -- for SMS auto-matching (§8)
                 icon, color, opening_balance, current_balance, is_archived, sort, created_at)
categories      (id, name, kind[income|expense], icon, color, parent_id?, is_archived, sort)
transactions    (id, type[income|expense|transfer], amount, account_id,
                 to_account_id?  -- transfers only
                 category_id?    -- income/expense only
                 date, note, created_at, updated_at)
budgets         (id, category_id, amount, period[weekly|monthly|custom], start_date,
                 rollover, alert_threshold_pct, is_active)
persons         (id, name, contact?, note, is_archived, created_at)
person_entries  (id, person_id, direction[they_owe|i_owe], amount, date, due_date?, note,
                 account_id?          -- optional: account real money moved through
                 transaction_id?      -- link to the account ledger entry if money moved
                 created_at)
                 -- person net balance = Σ(they_owe) − Σ(i_owe); +=they owe you, −=you owe them
settings        (currency, first_day_of_week, budget_start_day, theme, notif prefs…)
recurring       (later)
```

Design rules:
- **Amounts = INTEGER paise.** One money formatter/parser in `core/`.
- **Balance integrity:** ledger is source of truth. `current_balance` is a cache updated *in the same DB transaction* as every write. Ship a `recalculateBalances()` repair function.
- **Archive, don't hard-delete** accounts/categories with history — preserves past transactions.
- **Budget "spent"** = SUM of expense transactions in that category within the current period window. Transfers excluded by definition.
- **Debit card / UPI** = instrument with `card_kind=debit` (or a UPI flag) + `linked_account_id`. A payment "on" it posts to the linked bank; the instrument itself carries no independent balance and is skipped in net-worth sums.
- **Credit card** = `type=card, card_kind=credit`, own balance (negative = outstanding). Spending increases what you owe; **paying the bill = a Transfer from a Cash/Bank account → the credit card** (reduces the owed balance).

---

## 4. Tech stack

| Concern | Choice | Note |
|---|---|---|
| State mgmt | **Riverpod** | Reactive, testable, less boilerplate than Bloc for this. |
| Local DB | **Drift** (SQLite) | Type-safe, **reactive queries** → balances/budgets auto-refresh in UI. |
| Routing | **go_router** | |
| Charts | **fl_chart** | Pie / bar / line for reports. |
| Notifications | **flutter_local_notifications** + **timezone** | Scheduled + instant alerts. |
| Periodic budget checks | **workmanager** (or android_alarm_manager_plus) | Background budget/debt checks. |
| Formatting | **intl** | ₹ + dates. |
| List actions | **flutter_slidable** | Swipe to edit/delete. |
| Backup (later) | **share_plus / file_picker** | Export/import. |
| SMS capture | **Kotlin BroadcastReceiver + platform channel** (or `another_telephony`) | Most reliable; works with app closed. Perms: `RECEIVE_SMS`, `READ_SMS`. |
| SMS fallback | **NotificationListenerService** | Play-safe path: read bank/UPI app notifications instead of SMS. |
| SMS parsing | Dart rule + regex engine, bank templates in config | New bank formats added without a code change. |

---

## 5. Architecture / folders

```
lib/
  core/          theme, money formatter, constants, result types, notifications service
  data/          drift db, tables, daos, seed data
  domain/        entities, repository interfaces (kept light)
  features/
    accounts/    screen + widgets + controller (Riverpod notifier)
    transactions/
    categories/
    budgets/
    debts/
    reports/
    dashboard/
    settings/
  app.dart       router, theme wiring
  main.dart
```

Feature-first structure — each feature owns its UI + controller; shared plumbing in `core`/`data`.

---

## 6. UI design

**Design language** (your taste: minimal, black/white, One UI / Samsung-inspired):
- Material 3. Large rounded cards, generous spacing, big top titles, controls reachable at bottom.
- Light + **true-black dark theme** (AMOLED-friendly). Monochrome chrome + **one accent**.
- Money color coding only where it means something: income **green**, expense **red**, transfer **neutral/blue**. Tabular figures for amounts.
**Bottom navigation (locked):** `Dashboard · Transactions · ➕(center) · Accounts · More`

| Tab | Purpose |
|---|---|
| **Dashboard** | Everything in **graphical form** — charts, trends, breakdowns. Pending **SMS review cards surface here at the top** when the app opens. |
| **Transactions** | All transactions, **grouped day-wise** with daily totals; filters + search. |
| **➕** | Add **Expense / Income / Transfer**. *(Transfer is required — cash→bank, and paying a credit-card bill.)* |
| **Accounts** | All accounts with balances + **total money the user has** (net worth). |
| **More** | Hub page → **Budgets · Auto Spend · Calendar · Stats · Account Reports · Persons · Categories · Download Data · Settings** (see §6.1). |

> **Note:** with Dashboard being the graphical view, the old standalone **Reports** screen is absorbed into it. Reports becomes a *drill-down* from Dashboard (date range, filters, deeper charts) — not a second destination rendering the same charts twice.

**Screens:**

*Top-level (bottom nav)*
1. **Dashboard** — **graphical view**: net-worth trend, spending by category (pie), income vs expense (bar), budget rings, month summary. **Pending SMS review cards appear at the top on open.** Tap any chart → Reports drill-down.
2. **Transactions** — grouped **day-wise** with daily totals; filter (type/account/category/range); search.
3. **➕ Add / Edit Transaction** — segmented toggle **Expense / Income / Transfer**; big amount keypad; account picker (from→to for transfer); category icon grid; date; note.
4. **Accounts** — **total money** headline + balance cards per account (Cash / Bank / Card); add/edit account; transfer; link debit card → bank; last-4 digits for SMS matching; tap → per-account history.
5. **More** — *(spec pending)* hub for the screens below.

*Under More / drill-downs*
6. **Review Inbox** *(SMS auto-capture)* — full list of detected-transaction cards: **amount · time · matched account · merchant**, **Money Out = red / Money In = green**. Tap → pick category → Approve (posts to ledger). Edit / Dismiss / Mark duplicate. Raw SMS expandable. Bulk approve. *(Top cards mirrored on Dashboard.)*
7. **Budgets** — per-category progress ring/bar, over/under, set amount + period + alert %.
8. **Auto Spend** *(recurring)* — see §9.
9. **Calendar & Reminders** — month grid, each day shows **in / out** totals; tap a day → that day's transactions; **future dates show Cash Reminders** (planned payments); optional heatmap intensity by spend. See §9.1.
10. **Stats** — deeper analytics: top categories, avg daily spend, biggest expense, month-over-month comparison, category trends.
11. **Account Reports** — per-account breakdown: in/out per account, balance over time, credit-card outstanding.
12. **Persons** — list of people with each one's net balance (color-coded: they owe you / you owe them) + headline totals; tap a person → entry history + running balance; add entry (They owe / I owe, amount, optional account, date, due date, note); settle button.
13. **Categories** — manage income & expense categories (icon, color, archive).
14. **Download Data** — export CSV / JSON (+ backup file); date-range + account filter. CSV shaped for accountant / Tally import.
15. **Settings** — currency, theme, budget start day, notifications, **SMS senders & auto-capture rules**, backup & restore, app-lock.
16. **Onboarding** *(first run)* — currency, create initial accounts + opening balances, seed default categories.

### 6.1 More — page layout

Grouped list (not a flat dump):

| Group | Items |
|---|---|
| **Money** | Budgets · Persons · *(Auto Spend — ⏸ parked)* |
| **Insights** | Calendar & Reminders · Stats · Account Reports |
| **Data** | Download Data · Backup & Restore |
| **Setup** | Categories · Accounts · Settings |

> **Overlap warning:** Dashboard, Stats, Account Reports and Reports all render charts. Build **one charting layer** with different views/filters — do not implement the same pie chart four times. Dashboard = glance; Stats / Account Reports = deep dive.

---

## 7. Notifications design

Local notifications (no server):
- **Budget threshold** — fire when a category crosses configurable % (default 80%).
- **Overspent** — fire when spent > 100% of budget.
- **Person reminder** — N days before a person entry's due date (you owe / to collect).
- **Daily log reminder** — optional, user-set time.

- **New transaction detected** — an SMS was parsed and is waiting in the Review Inbox.

Mechanism: a background worker (workmanager) runs a periodic budget/person-due check; instant alerts also fire in-app right after a transaction pushes a budget over threshold. Store "already alerted this period" flags so it doesn't spam.

---

## 8. Message Auto-Capture (SMS / Notifications)

> **⏸️ STATUS (1.1.0, 2026-07-12): SMS capture is PAUSED in shipped builds.**
> The "deferred" Play risk below bit earlier than expected — not via a Play
> Store review but via **Google Play Protect**, which blocks direct-download
> APKs that request SMS permissions. Users had to pause Play Protect just to
> install the APK, which killed the download funnel. `READ_SMS`, the Kotlin
> channel and Dart `SmsSource` were removed (`test/native_channel_test.dart`
> guards the removal); `messageSourceProvider` ships `NullMessageSource`. The
> entire pipeline below (parser, dedupe, Review Inbox, rules, tests) is intact
> — exactly the swap this section's interface was designed for. Capture returns
> via a Play-compliant source (`NotificationSource` is the candidate). The UI
> presents it as "coming soon".

**Goal:** the app reads incoming bank messages **on-device**, parses the transaction, and shows it as a card. When the user opens the app they see cards — **amount, time, account, merchant** — assign a category, and it posts to the ledger.

### Constraint 1 — Play Store policy: ⏭️ ~~DEFERRED, not a blocker~~ → became the blocker (see STATUS above)

**Decision (Yash, superseded):** message reading **stays in the app**. Play Store distribution is a later problem. Build now.

*Recorded risk (came true in 1.1.0):* Google's restricted-permissions policy does not generally permit `READ_SMS` for expense tracking — and Play Protect enforces it on sideloaded APKs too.

**As built:**

```
MessageSource (interface)  →  { body, sender, timestamp }
   ├── SmsSource            (MethodChannel → ContentResolver, READ_SMS)  ← ships now
   ├── NullMessageSource    (non-Android: capture no-ops)
   ├── FakeMessageSource    (drives the whole pipeline in tests)
   └── NotificationSource   (NotificationListenerService)   ← drop-in later, Play-legal
              ↓
        same parser · same dedupe · same cards
```

**No background receiver, no `RECEIVE_SMS`.** The requirement is *"cards appear when the user opens
the app"*, so we scan the inbox **on resume**, from a `lastMessageScanAt` watermark. One fewer
permission, no background-service fragility, and re-scans are idempotent.

Keeping `SmsSource` behind the interface means capture is a **swappable module** — a future Play
build can swap the source or strip the module without touching parser, dedupe, or UI.

**If `NotificationSource` is ever used, know its limits:** notifications can be dismissed before we
read them, Android may truncate long text or group them into *"2 new messages"*, and a silenced SMS
app yields nothing. Capture from both and dedupe across them — the same machinery UPI's double-SMS
already forced us to build.

### ⚠️ Constraint 2 — "Credit" is overloaded

In banking, *credit* = money **in**, *debit* = money **out**. We also have a **Credit Card account**. So the UI says **Money In (green)** / **Money Out (red)** — a credit-card *purchase* is Money Out (red) even though the account is a credit card.

### Flow

1. Message arrives → **MessageSource** (SMS receiver or notification listener; works with app closed)
2. Filter by **sender allowlist** + keyword heuristics
3. **Parse:** amount (`Rs.100` / `INR 100.00` / `₹100`), direction (`debited`/`spent`/`withdrawn` vs `credited`/`received`/`deposited`), account hint (`A/c XX1234`, `Card ending 5678`), merchant/payee, ref no, datetime, `Avl Bal`
4. **Discard noise:** OTP, promotional, balance-only, and **declined / failed** transactions
5. **Dedupe:** same amount + account inside a short time window (UPI often fires two SMS; the user may have also added it manually)
6. Write to `pending_txns` → **badge** on the Review Inbox + optional notification
7. User opens app → **Review Inbox cards**:
   - **Money Out → red**, **Money In → green**
   - Shows amount · time · matched account · merchant · raw SMS (expandable)
   - Pick **category** → **Approve** → posts a real transaction
   - Or **Edit** / **Dismiss** / **Mark duplicate**

### Auto-Approve (toggle button)

When **Auto-Approve** is ON: if a payment is to/from a **name or account seen before**, the app auto-detects the category, **auto-fills and posts** the transaction — but **the card still appears**, marked as auto-filled, purely to inform the user.

Card states:

| State | Meaning | Actions |
|---|---|---|
| `pending` | Parsed, needs a category | Assign → Approve · Edit · Dismiss |
| `auto_filled` | Matched a learned rule, **already posted** | **Undo** · Edit · Keep |
| `approved` | User confirmed | — |
| `dismissed` / `duplicate` | Ignored | Restore |

Guardrails:
- Auto-approve fires **only from a learned rule** — a merchant/account you've already categorised at least once. **Never a fresh guess.**
- Card shows *why*: "Auto-filled — Swiggy → Food (used 7×)".
- **Undo must reverse the posted transaction**, not just hide the card.
- Toggle is global (Settings) and per-rule.

### Bank detection

During **account setup** the user picks their **bank from a list** and enters the **last 4 digits**. That pairing is what matches incoming messages to an account.

- `bank → sender IDs` shipped as templates; `last4 → account` set by the user
- **First template to build & test: India Post Payments Bank (IPPB)** — Yash's current bank SMS source
- Unknown sender → card still shows with raw text, and offers "map this sender to an account"

### Smart behaviour (beyond the basics)

- **Learned merchant rules** — categorise "Swiggy → Food" once; next time it auto-fills (see Auto-Approve).
- **Account matching** — map message `XX1234` to an account by last-4 digits; asked once, remembered.
  - **Debit-card message** → posts to its **linked bank** account (per §1's account model)
  - **Credit-card message** → posts to the **Credit Card** account (increases what you owe)
- **Refunds / reversals** — `reversed`, `refund`, `credited back` → posts as Money In.
- **Balance reconciliation** — many messages carry `Avl Bal: Rs.X`; compare to the app's balance and flag drift.
- **Backfill on first grant** — scan the last N days of SMS to import history. *(SMS source only — notifications have no history.)*
- **Manual fallback** — an unparsable bank message still appears as a card with raw text to fill in by hand.
- **Privacy** — all parsing is **on-device**; no message ever leaves the phone. Consistent with local-first.
- **Permission UX** — explain *why* before requesting; degrade gracefully to manual entry if denied.
- **Settings** — manage sender allowlist, ignore rules, **Auto-Approve toggle**, re-scan, revoke.

### Data additions

```
pending_txns    (id, source[sms|notification], raw_body, sender, received_at,
                 parsed_amount?, parsed_direction[debit|credit], parsed_account_hint?,
                 parsed_merchant?, parsed_ref?, parsed_balance?, confidence,
                 status[pending|auto_filled|approved|dismissed|duplicate],
                 applied_rule_id?, matched_account_id?, created_transaction_id?, created_at)
merchant_rules  (id, match_pattern, category_id, account_id?, auto_approve, hit_count)
sender_rules    (id, sender_pattern, bank_name, enabled)
banks           (id, name, sender_patterns[])   -- shipped templates (IPPB first)
```
(plus `accounts` += `account_last4`, `card_last4`, `bank_id?` — see §3)

---

## 9. Auto Spend (recurring transactions) — ⏸️ PARKED

> **Status: on hold.** Design captured below, not scheduled. The double-count problem (below) is the reason to think it through properly before building. Revisit after beta.

**Goal:** money automatically posts on a fixed date — EMI, rent, subscriptions, and **salary in**.

### Scope (bigger than the name)
Despite the UI name "Auto Spend", the engine handles **three types**:
- **Expense** — EMI, rent, Netflix, insurance
- **Income** — salary, monthly interest *(most common recurring entry — must be supported)*
- **Transfer** — monthly savings sweep, credit-card bill payment

### ⚠️ The double-count trap (must be solved, not patched later)

Your EMI auto-debits at the bank. So on the 5th:
- Auto Spend posts **₹5,000 expense**
- The bank's SMS also arrives → SMS capture posts **₹5,000 expense**
- **→ ₹10,000 recorded. Balance corrupted.**

**Design:** an Auto Spend run creates a **scheduled/expected** entry. When a matching SMS arrives (**amount + account + date window**), it **confirms and reconciles** that entry instead of creating a second transaction. If no SMS ever arrives, the scheduled entry stands on its own. Reconciliation status is visible on the transaction.

```
SMS arrives → does it match an expected recurring run?
   yes → mark run CONFIRMED_BY_SMS, attach raw SMS, do NOT create a new txn
   no  → normal Review Inbox flow
```

### Rules a recurring engine needs

- **End condition** — `end_date` **or** `occurrences_total` (EMI = 24 installments, then stop). Without this the rule invents payments after the loan is paid off.
- **Missed-run catch-up** — phone off / app unopened for days → on next launch, backfill every run from `last_run_date` to today. Never silently skip.
- **Skip one occurrence** — "skip this month's EMI" without deleting the rule.
- **Auto-post vs remind** — per-rule toggle. Default **auto-post** for true auto-debits (EMI), **remind** for things you pay manually.
- **Insufficient balance** — allow it, but warn; don't silently block a real-world debit.
- **Upcoming preview** — next N scheduled runs, also surfaced on the **Calendar** on future dates.
- **Notification** — fire when an Auto Spend posts.

### Data model

```
recurring_rules (id, name, type[expense|income|transfer], amount,
                 account_id, to_account_id?, category_id?,
                 frequency[daily|weekly|monthly|yearly], interval,
                 day_of_month?, weekday?,
                 start_date, end_date?, occurrences_total?, occurrences_done,
                 next_run_date, last_run_date?, auto_post, is_active, note, created_at)

recurring_runs  (id, rule_id, scheduled_date, posted_at?, transaction_id?,
                 status[scheduled|posted|skipped|failed|confirmed_by_sms])
```

`recurring_runs` gives skip/history **and** is what SMS reconciliation matches against.

---

## 9.1 Cash Reminders (replaces Auto Spend for now) ✅

**The idea:** on a future day, remind me I need to pay (or collect) this amount. Set on the **Calendar**.

**Why this is the better design.** Auto Spend *posts by itself*, which collides with the bank SMS for the same payment → double-count. A **reminder posts nothing**. On the due day you tap **Mark as paid**, which opens a prefilled transaction you confirm. Nothing can ever be booked twice. Same practical use for EMI / rent / bills, none of the corruption risk.

### Behaviour
- Set: **amount · date · title · direction (pay / receive)** + optional account, category, person
- Appears on the **Calendar** on its future date
- **Notification** on the day (and *N* days before, configurable)
- On the day: **Mark as paid** → opens a prefilled Add-Transaction → user confirms → posts, reminder marked done
- Also: **Snooze**, **Edit**, **Dismiss**
- Optional **repeat** (monthly EMI reminder) — still reminder-only, so still safe
- Can link to a **Person** (e.g. "collect ₹500 from Ram on the 20th")
- **Overdue** reminders stay visible and get flagged

### Data model

```
reminders (id, title, amount?, direction[pay|receive], due_date,
           account_id?, category_id?, person_id?,
           repeat[none|weekly|monthly|yearly], notify_days_before,
           status[open|done|snoozed|dismissed|overdue],
           transaction_id?,   -- set when "Mark as paid" posts the txn
           created_at)
```

> Bonus: an incoming bank message can **match an open reminder** (amount + account + date window) and offer "is this the EMI you planned?" — reconciliation *with user confirmation*, never silent.

---

## 10. Execution roadmap

| Phase | Deliverable | Done when |
|---|---|---|
| **0 · Setup** ✅ | Flutter project, folders, deps, theme, `Money` type, git init | ✅ Themed shell + bottom nav · analyze clean · APK builds (see TLS fix below) |
| **1 · Data** ✅ | Drift schema (all 8 tables), `Money` paise type, seed, `recalculateBalances()` | ✅ 14 invariant tests pass — transfers net-zero, no debit-card double-count, lending ≠ expense |
| **2 · MVP UI** ✅ | Dashboard, Add transaction (income/expense/transfer), Transactions list, Accounts + Add Account sheet | ✅ Shippable — track daily money end-to-end |
| **3 · Budgets** ✅ | Budget model, spent calc, budgets screen, progress UI | ✅ Set a budget, see live progress |
| **4 · Notifications** ✅ | `NotificationService`, budget threshold/overspend (once per period via `budget_alerts`), reminder scheduling, detected-txn ping | ✅ Alerts fire once, not on every purchase |
| **5 · Message Auto-Capture** ✅ | `MessageSource` abstraction, Kotlin SMS channel, IPPB parser, dedupe, account matching, Review Inbox, merchant rules, **Auto-Approve** | ✅ 45 tests — UPI double-SMS never double-counts; Undo reverses the money |
| **6 · Persons** ✅ | Persons + entries model, screen, settlements, optional account linkage | ✅ Add a person, log I owe/they owe, running balance + net worth stay correct |
| **7 · Calendar & Reminders** ✅ | Calendar grid (day-wise in/out), Cash Reminders, Mark-as-paid | ✅ Reminders show on future dates; nothing posts without confirmation. *(notifications pending Phase 4)* |
| **8 · Insights** | Charting layer → full graphical Dashboard, Stats, Account Reports | One chart engine, several views, no duplicated code |
| **9 · Data + polish** | Download Data (CSV/JSON), Backup & Restore, theme refinement | Can export/restore; app feels finished |
| **8 · Data + polish** ✅ | Download Data (CSV/JSON), Backup & Restore, Categories, Onboarding, Tx/Account detail, edit transaction | ✅ Export, restore, edit — all tested |
| **10 · Release** ✅ | Edge cases, 116 tests, signed APK, `verify_apk.sh` gate | ✅ `dist/money-manager-arm64.apk` |
| **⏸ Parked** | **Auto Spend** (§9), app-lock, Play Store policy | Auto Spend superseded by Cash Reminders (§9.1) |

### How to build + ship

```bash
rm -rf build/native_assets          # Flutter/Windows native-assets bug
flutter test                        # 116 tests must pass
flutter build apk --release --split-per-abi
bash tool/verify_apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
`verify_apk.sh` **must pass** — it is the only thing standing between you and shipping another
APK with no `libsqlite3.so`. Needs ~3 GB free disk; a Gradle release build fails with
`java.io.IOException: There is not enough space on the disk` otherwise.

Notes on ordering:
- **Message capture at Phase 5** on purpose: manual entry is where money apps die, so auto-capture is what makes daily tracking stick. Needs Phase 2's accounts/categories to post into.
- **Phase 2's Dashboard is a basic summary** (numbers + recent activity). Phase 8 upgrades it to the full graphical view.
- **Play Store policy is deferred** — message capture ships as a normal feature. `MessageSource` stays an interface so a future Play build has options (swap source / strip module) without touching parser, dedupe, or UI.
- **Auto Spend is parked** — **Cash Reminders (§9.1)** covers the same need without the double-count risk.

---

## 11. Key decisions & risks (flagged)

1. **Money as integer paise** — non-negotiable; doubles will silently corrupt totals.
2. **Accounts ≠ Categories; transfers and person movements are neither income nor expense** — enforce in every report/budget query or numbers lie.
3. **Balance = ledger truth + atomic cache + repair fn** — never let a UI-only counter drift from the ledger.
4. **Budget period boundaries** — calendar month with configurable start day (default 1st). Rolling periods are v2.
5. **Timezone** — store dates in a consistent zone; matters for period boundaries and scheduled notifications.
6. **Archive over delete** — deleting an account/category with history breaks past reports.
7. **`READ_SMS` vs Play Store — ⏭️ deferred.** Message capture ships as a normal feature; Play policy gets sorted before publishing. Keep `MessageSource` as an interface so the capture layer stays swappable. *(Recorded risk, explicitly not blocking.)*
8. **SMS parsing is inherently fuzzy** — bank formats vary and change. Never auto-post low-confidence parses; the Review Inbox is the safety net. Keep bank templates in config, not code.
9. **Dedupe is mandatory** — UPI commonly fires two SMS for one payment; without dedupe every UPI spend double-counts.
10. **SMS never leaves the device** — on-device parsing only. This is a money app reading your bank messages; privacy is the whole trust story.
11. **Auto Spend × message capture = double-count** *(parked feature)* — anything that posts by itself can collide with the bank message for the same payment. **Cash Reminders (§9.1) avoid this entirely** by never posting without user confirmation. Don't reintroduce silent auto-posting.
12. **Auto-Approve must only fire from a learned rule** — never a fresh guess. And **Undo must reverse the posted transaction**, not just hide the card.
13. **Notification capture is lossy** — dismissed, truncated, or grouped notifications mean missed transactions. Capture from both sources where possible; never assume the stream is complete.
14. **One charting layer** — Dashboard / Stats / Account Reports / Reports are four *views*, not four implementations.

---

## 11.5 Audit — 8 defects found and fixed

An adversarial audit (6 lenses × 3 independent skeptics per finding, skeptics defaulting to
*refuted*) confirmed 8 defects and refuted 4. Each fix has a regression test in
`test/bug_hunt_regression_test.dart`.

| # | Defect | Why it mattered |
|---|---|---|
| 1 | **Auto-Approve substring merchant match** | A learned rule for `OLA` matched **`GOLA SNACKS`** and auto-booked it under Transport. Broke the promise *"Auto-Approve never guesses."* → now **exact match only**; a fuzzy `suggestMerchantRule` exists for hints and never auto-posts. |
| 2 | **Budget alert lost for the whole month** | `checkBudgets()` fires from a provider listener *before* `notifications.init()`. It claimed the alert row, `_show()` silently no-opped, and the claim persisted → alert never fired again that period. → `checkBudgets` returns early when not ready, `_show` reports success, a failed show **releases** the claim, and `init()` re-runs the check. |
| 3 | **`claimBudgetAlert` not atomic** | Check-then-insert across two statements, then `return true` unconditionally after `insertOrIgnore`. Two overlapping calls both "won" → the same alert buzzed twice. → wrapped in `transaction()`. |
| 4 | **Restore destroyed the review inbox** | `importAll` deleted `pending_txns` + `budget_alerts`; `exportAll` never captured them. Restoring the app's *own* backup wiped un-reviewed capture cards and re-fired spent alerts. → export/import are now symmetric; older backups without those keys still restore. |
| 5 | **UPI wallet double-SMS booked twice** | The bank SMS names `A/c XX1234`; the PhonePe SMS names no account and a different reference, so they never matched. → an amount+direction match where **either side lacks an account hint** is now flagged duplicate (flagged, never dropped — the card still shows with *"Not a duplicate"*, and a flagged card can never auto-approve). |
| 6 | **Reminder due *today* never scheduled** | `dueDate` is midnight, so `fireAt` was already past and the reminder was dropped. → fires at 09:00, or `now + 1 min` if that has passed and the day hasn't. |
| 7 | **Calendar cell overflow** | 42×53 dp cell, ~48 dp of content — no headroom for text scaling. → `Flexible` + `FittedBox(scaleDown)`. |
| 8 | **Stats screen infinite rebuild loop** *(found by tests, not the audit)* | `netWorthTrendProvider` did `ref.watch(allTransactionsProvider)` **and** opened `db.watchTransactions()`. Drift re-emits to all listeners of a cached query on new subscription → recompute forever. The screen hung and never rendered. → plain `Provider`s composed from the stream providers. |

**Refuted (correctly):** near-duplicates burying distinct payments (1/3); identical-body SMS in the
same minute (0/3); `int.parse` on a route param crashing (0/3); CSV formula injection (0/3).

---

## 12. Open questions (confirm before we build)

- **Persons labels** — entry buttons "They owe" (they'll pay you) vs "I owe" (you'll pay them) — good wording?
- **Default accounts to seed** — start with just **Cash** (type: cash); user adds their own Bank/Card accounts. Or seed a sample Bank too?
- ~~**Default categories**~~ ✅ **CONFIRMED**
  - Income: Salary, Profit, Gift, Cash, Interest, Refund
  - Expense: Rent, Food, Groceries, Transport, Bills, Shopping, Health, Entertainment, EMI
- ~~**Bottom navigation**~~ ✅ **CONFIRMED** — `Dashboard · Transactions · ➕ · Accounts · More`
- ~~**More tab contents**~~ ✅ **CONFIRMED** — Budgets · Auto Spend · Calendar · Stats · Account Reports · Persons · Categories · Download Data · Settings
- ~~**App-lock (PIN/biometric)**~~ ✅ **DROPPED for now** — parked. Personal beta shared with friends.
- ~~**Distribution**~~ ✅ **CONFIRMED** — beta APK to friends now; **Play Store is a fixed eventual goal** → this forces the `MessageSource` abstraction (§8) from day one.
- ~~**Auto-approve**~~ ✅ **CONFIRMED** — Auto-Approve button. Same name/account seen before → auto-detect category, auto-fill **and post**, but **still show the card** so the user knows. Guardrails: learned rules only; Undo reverses the transaction.
- ~~**Which banks**~~ ✅ **India Post Payments Bank (IPPB)** first. User selects bank + enters **last 4 digits** at account setup → that's the match key.
- ~~**Auto Spend default**~~ ⏸️ **PARKED** — revisit after beta.

- ~~**Persons labels**~~ ✅ **CONFIRMED** — "They owe" / "I owe".
- ~~**Default accounts to seed**~~ ✅ **CONFIRMED** — pre-create **Cash** only. Onboarding then prompts the user to add their bank (pick bank → last 4 digits → opening balance). No fake/sample accounts.
- ~~**"IPOs"**~~ ✅ **= IPPB**, India Post Payments Bank. One bank, one parser template to start.
- ~~**Calendar future dates**~~ ✅ **SOLVED** — future dates show **Cash Reminders** (§9.1) instead of Auto Spend.
- ~~**SMS on Play Store**~~ ⏭️ **DEFERRED** — message reading stays in the app. Play policy is a later problem. Build now.

**No blocking questions remain. Plan is signed off.**

---

*Status: **Phase 0 complete.** Next: Phase 1 (data layer).*
*Target: Android build with message capture on. Play Store policy revisited before publishing.*
*Toolchain: Flutter 3.38.9 · Dart 3.10.8*

### ✅ Resolved — Gradle `PKIX path building failed`

**Symptom**
```
PKIX path building failed: unable to find valid certification path to requested target
[!] Gradle threw an error while downloading artifacts from the network.
```

**Root cause.** Avast antivirus' **Web Shield HTTPS scanning** man-in-the-middles outbound TLS
on this machine. It re-signs every artifact host (`dl.google.com`, `maven.google.com`,
`services.gradle.org`, …) with its own self-signed root:

```
CN=Avast Web/Mail Shield Root, O=Avast Web/Mail Shield
SHA1 32:1B:BE:C5:FF:D8:FF:FF:B8:3B:60:98:E4:CF:52:2B:79:47:AF:B2
```

Windows trusts that root (browsers work), but the **JDK keeps a separate truststore** that did
not contain it. Gradle runs on the Android Studio JetBrains Runtime (**OpenJDK 21.0.8**), whose
`cacerts` had 113 public CAs and no Avast root → handshake fails during dependency download,
before any compilation. **Environment issue, not a code issue.**

Note: this is *local* interception. Switching networks (phone hotspot) does **not** bypass it.

**Fix applied** — imported the (already-Windows-trusted) Avast root into the JDK Gradle uses:

```powershell
# elevated PowerShell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -importcert `
  -alias avast-web-shield-root `
  -file "C:\ProgramData\Avast Software\Avast\wscert.pem" `
  -keystore "C:\Program Files\Android\Android Studio\jbr\lib\security\cacerts" `
  -storepass changeit -noprompt
```

Truststore went 113 → 114 CAs. Backup of the original: `C:\Users\admin\backups\cacerts.jbr21.backup`

**Undo:** `keytool -delete -alias avast-web-shield-root -keystore "...\jbr\lib\security\cacerts" -storepass changeit`

**If it returns:** an Android Studio update can replace the JBR and reset `cacerts` — just re-import.
Also confirm the target JDK with `flutter doctor -v` ("Java binary at:"); importing into the wrong
JDK (e.g. Oracle's, which is what's on `PATH`) has zero effect.

> ⛔ **Never "fix" this by disabling TLS verification** — `trustAllCerts`, `sslVerify=false`,
> `-Dmaven.wagon.http.ssl.insecure=true`, or a downloaded `cacerts` from a forum. Those make the
> machine accept *any* forged certificate, permanently. On a money app that reads bank messages,
> that is the wrong trade forever. The correct move is to trust *one named CA you have verified* —
> which is what was done here (the on-disk PEM's subject was matched against the live intercepting
> issuer before importing).

### Build gotchas already solved (don't re-discover these)

| Problem | Fix |
|---|---|
| `dart run build_runner build` → *"'dart compile' does not support build hooks"* | Use **`dart run build_runner build --force-jit --delete-conflicting-outputs`**. build_runner AOT-compiles its build script; a dep ships native-asset hooks that `dart compile` can't handle. |
| `flutter_local_notifications` → `:app:checkDebugAarMetadata` fails | **Core library desugaring** enabled in `android/app/build.gradle.kts` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")`. |
| Icons stored as codepoints break `--release` | Icons persist as **stable string keys** (`AppIcons.resolve`), never runtime `IconData`. Keeps icon tree-shaking working. |
| Fixed the CA but Gradle still failed | A JVM reads `cacerts` **once at startup**. Kill stale daemons: `./gradlew --stop`. |
| 2nd `flutter test` crashes: *"Cannot copy sqlite3.dll … already exists"* | Flutter/Windows native-assets bug. Run **`rm -rf build/native_assets`** before `flutter test`. |
| Widget test hangs 10 min | Drift futures never resolve in `testWidgets`' fake-async zone. Do **all DB work inside `tester.runAsync`**. |
| `pumpAndSettle` never returns | An indeterminate `CircularProgressIndicator` schedules frames forever. **Pump a bounded span** instead. |
| Test fails `!timersPending` | Cancelling a Drift query stream schedules a 0ms timer. **Unmount the tree + `pump(Duration.zero)`** before the test ends. |
| Layout overflows only on device | `flutter_test` defaults to an 800×600 landscape surface. Smoke tests set **360×800 dp** (`tester.view.physicalSize`). |
| A screen hangs forever, never renders | **Never `ref.watch(xProvider)` and also open the same drift query inside the same provider.** Drift caches streams by query; subscribing re-emits to all listeners → infinite recompute. Compose from providers instead. Guarded by `test/reports_provider_test.dart`. |
| `BoxConstraints forces an infinite width` | The theme sets `FilledButton minimumSize: Size.fromHeight(56)` = **infinite min width**. Fine in a Column; a **Row** gives non-flex children unbounded width and it throws. Override `minimumSize` or wrap in `Expanded`. |
| `flutter_local_notifications` 22.x calls don't compile | v22 moved to **named params**: `initialize(settings:)`, `show(id:title:body:notificationDetails:)`, `cancel(id:)`, `zonedSchedule(id:scheduledDate:notificationDetails:androidScheduleMode:)`. |
| Undo threw `FOREIGN KEY constraint failed` | `pending_txns.created_transaction_id` and `reminders.transaction_id` reference `transactions`. `deleteTransaction` now **clears those references first**. Caught by a test. |

### 🔴 The crash that shipped — read this before touching `drift`

**Symptom on device:** every screen stuck loading; a toast reading
`Failed to load dynamic library 'libsqlite3.so': dlopen failed: library "libsqlite3.so" not found`.

**Root cause.** `drift ≥ 2.32` requires `sqlite3 ^3.1.5`, which ships its Android native library
**only via experimental native-assets build hooks**. The companion plugin at that version is
`sqlite3_flutter_libs: 0.6.0+eol`, whose own pubspec says *"This dependency doesn't do anything."*
`flutter build apk` never ran the hook — `build/native_assets/` had `windows/` but **no `android/`** —
so the APK contained `libapp.so`, `libflutter.so`, `libdartjni.so` and **no `libsqlite3.so`**.

**The fault line:**

| | `sqlite3` | `sqlite3_flutter_libs` | Android `.so` bundled? |
|---|---|---|---|
| drift ≤ **2.31.0** / drift_flutter ≤ **0.2.8** | ^2.6.0 | **0.5.24 — a real Gradle plugin** | ✅ |
| drift ≥ 2.32 / drift_flutter 0.3.0 | ^3.1.5 | 0.6.0 **+eol (no-op)** | ❌ hooks only |

**Fix:** pinned to **drift 2.31.0 · drift_flutter 0.2.8 · sqlite3_flutter_libs 0.5.24**, plus an
explicit `sqlite3_flutter_libs` dependency. **Do not bump drift past 2.31 until Flutter runs build
hooks for Android release builds.**

**Why no test caught it.** Every test overrides `dbProvider` with `NativeDatabase.memory()`, so the
real `driftDatabase()` path was never exercised. Unit tests cannot see a missing `.so`.
Two guards now exist:
- **`bash tool/verify_apk.sh <apk>`** — fails the build if `libsqlite3.so` is absent for any ABI
  that has `libflutter.so`. **Run this before shipping any APK.**
- **`databaseReadyProvider`** — opens the DB at startup so a failure renders a real error screen
  with the cause and a retry, instead of spinners forever.

### Pinned versions & why

| Package | Version | Note |
|---|---|---|
| `flutter_riverpod` | **2.6.1 (pinned)** | Riverpod **3.x pulls in `test`**, forcing `test ≥1.31.2` → Dart ≥3.11, which breaks `drift_dev` on Dart 3.10.8. 2.6.x is the stable line. **Do not bump without re-checking `drift_dev`.** |
| `drift` / `drift_dev` | **2.31.0 (pinned)** | See the crash box above. 2.32+ loses the Android `libsqlite3.so`. |
| `drift_flutter` | **0.2.8 (pinned)** | Last version on the plugin-based `sqlite3` 2.x. |
| `sqlite3_flutter_libs` | **0.5.24 (pinned)** | The version that actually bundles the native library. |
| `go_router` | 17.x | `StatefulShellRoute.indexedStack` for tab state. |
| `fl_chart` · `flutter_local_notifications` · `timezone` · `intl` · `flutter_slidable` | latest | Per §4. |
