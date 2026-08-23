# Goals & Loans — design spec

Date: 2026-08-23
Status: draft, pending approval

## Background

The user wants "Savings Goals" renamed to "Goals & Loans," with two additions:

- **Goals** (today's feature, unchanged in spirit): a Goal can now optionally
  link to a Category, so contributing money toward it also counts as
  "spent" against that Category's Budget. Their example: an "Investment"
  budget of ₹3,000; two goals, LIC and FD, both linked to "Investment" —
  contributing to either counts toward that ₹3,000.
- **Loans** (new, the reverse of a Goal): record money borrowed, then log
  payments that reduce what's left to pay, each payment optionally
  category-linked the same way, plus a due-date reminder ("EMI-like
  stuff").

## Why this isn't a small change

A Savings Goal today is not its own table — it's an `Accounts` row
(`AccountType.goal`, see `tables.dart:25`) plus a `GoalDetails` row for
target amount/date. "Contributing" is an ordinary `TxType.transfer` into
the goal account (never an expense), because that's the only way the
goal's own balance — and the source account's balance — both stay correct.
`AppDatabase._validateTx` (`database.dart:741-745`) actively **throws** if
a transfer carries a `categoryId`: *"Transfers carry no category — they
are neither income or expense."* Every budget/report in the app is built
on `TxType.expense`/`income` only (`TxTypeX.isIncomeOrExpense`,
`tables.dart:45`).

So "let a goal/loan contribution count toward a budget" means deliberately
loosening that one rule for exactly this case — not bolting on a cosmetic
label. The rest of this spec is scoped around doing that as narrowly as
possible.

## Decisions already made (with the user, before this doc)

- **Budget linkage is real, not cosmetic.** A transfer that's a goal/loan
  contribution may carry a `categoryId`; the Budget screen's "spent so
  far" for that category includes these transfers alongside ordinary
  expenses. Every income/expense report elsewhere is untouched — they
  filter on `TxType.expense`/`income` specifically, never transfers, so
  nothing outside the Budgets feature changes meaning.
- **Loans are principal-only.** No interest rate, no amortization split.
  A payment reduces the outstanding balance 1:1, exactly like paying down
  a credit card today.
- **EMI = reminder only, for v1.** A Loan can carry a due-date reminder
  (reusing the existing Calendar `Reminders` feature as-is) that nudges
  the user monthly to come make the payment themselves. No auto-posting —
  `RecurringRules` would need its own schema change (non-null `categoryId`,
  `income`/`expense`-only `kind`) to post a transfer instead, which is a
  separate, bigger piece of work deliberately deferred.
- **One linked category per Goal/Loan**, set at creation, pre-filling
  (but not locking) the category picker every time funds are
  added/a payment is made.

## Non-goals

- Interest/amortization tracking.
- Auto-posting EMI payments via `RecurringRules`.
- A "borrow more" flow that increases a Loan's balance after creation —
  the initial amount borrowed is set once, at creation, same as an
  opening balance on any other account.
- Changing the existing Dashboard "Loan" metric tab
  (`dashboard_screen.dart:243,311-314`) — it tracks `AccountType.payLater`
  (BNPL) balance trend today, a different kind of liability than a
  personal Loan. Left alone; flagged here as a known naming collision the
  user may want to revisit separately (e.g. rename that tab, or combine
  `payLater` + `loan` balances into one "money I owe" trend) — not part of
  this feature.
- Multi-category splits on a single contribution/payment (a goal/loan
  transfer gets at most one category, same as an ordinary un-split
  expense; `TransactionSplits` isn't extended to transfers).

## Data model

### New `AccountType.loan`

```dart
enum AccountType { cash, bank, card, payLater, prepaidBalance, goal, loan }
```

A `textEnum` column — adding a variant needs no migration (see the
`MessageSourceKind` precedent, `tables.dart:73-74`). A Loan account is a
liability exactly like a credit card or `payLater`: `openingBalance` is
set once, negative (`-principal`), `currentBalance` moves toward zero as
payments post. `-currentBalance` is always "outstanding to pay" — no
separate field to keep in sync.

`AppDatabase._validateTx`'s existing "a goal is not spendable" guard
(`database.dart:711-722`) extends to loans — a Loan account must also
never be the source/destination of a direct income/expense, only ever
funded via its opening balance and paid down via transfer.

### `GoalDetails` gains one column

```dart
/// The Category a contribution is tagged with by default — see the
/// Transactions-tab "Linked" pattern's sibling concept here. Null means
/// contributions aren't counted toward any budget; the add-funds sheet's
/// category picker still lets a specific contribution be tagged even
/// then, it just has no default to start from.
IntColumn get categoryId => integer().nullable().references(Categories, #id)();
```

### New `LoanDetails` table (mirrors `GoalDetails`)

```dart
@DataClassName('LoanDetailRow')
class LoanDetails extends Table {
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();

  /// Pre-fills the payment sheet's amount and the EMI reminder's amount —
  /// informational only, never enforced against an actual payment.
  IntColumn get emiAmount => integer().map(const MoneyConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {accountId};
}
```

No `principalAmount` column — `-Accounts.openingBalance` already *is* the
original amount borrowed, exactly the same way `Accounts.currentBalance`
already is the running balance; duplicating it would just be a second
number that could drift from the first.

`AppDatabase` gains `addLoan`/`updateLoan`, mirroring `addGoal`/`updateGoal`
(`database.dart:1245-1306`) exactly: `addLoan` validates the borrowed
amount is positive (same shape as `addGoal`'s `targetAmount must be
greater than zero` check), inserts the `Accounts` row with
`openingBalance`/`currentBalance` both set to `-amount`, then the
`LoanDetails` row. `updateLoan` never touches the balance, same "only a
transfer moves money" rule `updateGoal`'s own doc comment states. A
payment itself needs no dedicated method — it's a plain `addTransaction`
call (transfer, optionally categorized), exactly how the Goal detail
screen's `_FundsSheet` already posts contributions today.

Migration: schema v33 → v34 (`_addColumnIfMissing(m, goalDetails,
goalDetails.categoryId)`) → v35 (`m.createTable(loanDetails)`), following
the existing one-change-per-version pattern in `database.dart`'s
`onUpgrade`.

## Validation change

`_validateTx`'s transfer case (`database.dart:741-745`) currently throws
unconditionally on any `categoryId`. New rule: allowed only when the
transfer touches a goal or loan account on either side.

```dart
case TxType.transfer:
  if (toAccountId == null) {
    throw ArgumentError('A transfer needs a destination account.');
  }
  if (toAccountId == accountId) {
    throw ArgumentError('Cannot transfer to the same account.');
  }
  if (categoryId != null) {
    final from = await (select(accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
    final to = await (select(accounts)..where((a) => a.id.equals(toAccountId))).getSingleOrNull();
    final touchesGoalOrLoan = {from?.type, to?.type}
        .any((t) => t == AccountType.goal || t == AccountType.loan);
    if (!touchesGoalOrLoan) {
      throw ArgumentError(
        'Only a goal or loan contribution can carry a category.',
      );
    }
  }
```

An ordinary transfer between two regular accounts (Bank → Cash, say)
still can never carry a category — the invariant is narrowed, not
dropped. Direction isn't enforced here: nothing stops a Goal *withdrawal*
from carrying a category at the DB layer. That's deliberately left to the
UI (below) — withdrawing is "using savings," not "spending," so the
withdraw sheet simply never offers a category field, rather than the
database having to know about direction-as-intent.

## Budget-progress change

`AppDatabase.watchSpendByCategory` (`database.dart:1779-1795`) currently:

```dart
for (final t in rows) {
  if (t.type != TxType.expense) continue;
  ...
}
```

New: a categorized transfer counts the same as an uncategorized-split
expense does today — its whole amount, attributed to its one category (no
splitting; see Non-goals).

```dart
for (final t in rows) {
  if (t.type == TxType.expense) {
    if (t.categoryId != null) {
      out[t.categoryId!] = (out[t.categoryId!] ?? const Money.zero()) + t.amount;
      continue;
    }
    for (final s in await splitsForTransaction(t.id)) {
      out[s.categoryId] = (out[s.categoryId] ?? const Money.zero()) + s.amount;
    }
    continue;
  }
  if (t.type == TxType.transfer && t.categoryId != null) {
    out[t.categoryId!] = (out[t.categoryId!] ?? const Money.zero()) + t.amount;
  }
}
```

This one function is the sole source for `budgetProgressProvider`
(`providers.dart:258-288`), so every place that reads budget progress
picks this up automatically. `categoryTransactionsProvider`
(`providers.dart:207-246`) and `budgetStatement`/`categoryStatement`
(`database.dart:3493+`) — the category drill-down list and the PDF
statement — get the same category-filter loosened so a tagged
contribution/payment actually appears in the list backing the number, not
just the number itself.

Income/expense totals, Reports, Calendar, CSV export, and the
Transactions tab's own type filter are **not touched** — they all key off
`TxTypeX.isIncomeOrExpense` or `TxType.expense`/`income` directly, never
`watchSpendByCategory`, so a goal/loan transfer still never appears as
"expense" anywhere except inside its linked budget's progress.

## Screens & UI

### Rename surface (mechanical, no behavior change beyond what's listed above)

- Route: `/more/savings` → `/more/goals` (`app_router.dart:33-34,246-258`).
- More hub tile: `'Savings Goals'` → `'Goals & Loans'`, subtitle updated
  (`more_screen.dart:66-70`).
- `SavingsGoalsScreen` → becomes the combined hub with two tabs, **Goals**
  and **Loans** — same `TabBar` pattern `CategoriesScreen` already uses for
  Income/Expense, not a new pattern.
- `SavingsGoalDetailScreen` stays the Goal detail screen (title updated to
  just the goal's own name/"Goal", as today).
- New `LoanDetailScreen`, new route segment (`/more/goals/loan/:id` or
  similar — exact path decided in the implementation plan).

### Goal creation/detail — additive only

- `_GoalEditorSheet` (`savings_goals_screen.dart:293+`) gains one field: a
  Category picker (optional), saved onto `GoalDetails.categoryId` via
  `addGoal`/`updateGoal`, both of which gain a `categoryId` parameter.
- `_FundsSheet` (`savings_goal_detail_screen.dart:465+`) gains a Category
  field, pre-filled from the goal's linked category, **shown only when
  adding funds** (`widget.isAdd == true`) — never on Withdraw. Passes
  `categoryId` through to `addTransaction` only on that path.

### Loan creation/detail — new, parallel to Goal's

- `_LoanEditorSheet` (new, modeled directly on `_GoalEditorSheet`): name,
  **amount borrowed** (positive; becomes `-openingBalance`), optional
  **EMI amount**, optional linked Category, colour, icon. No target date,
  no "turn an existing account into a loan" fork (a loan has a known
  starting debt, not a balance to sweep in) — creation is a single "New
  loan" action, no choice sheet.
- `LoanDetailScreen` (new): outstanding balance (`-currentBalance`),
  original amount (`-openingBalance`), linked category, a single **"Make a
  payment"** action reusing `_FundsSheet` in its "add" mode (source
  account → loan account, category pre-filled/editable) — no Withdraw
  equivalent (see Non-goals). An **"Add EMI reminder"** button opens the
  existing `_ReminderSheet` (`calendar_screen.dart:669+`)/reminder-creation
  flow, pre-filled: title = loan name, direction = pay, amount =
  `LoanDetailRow.emiAmount` if set, category = the loan's linked category,
  repeat = monthly. Marking that reminder paid behaves exactly as it does
  today (a status flag + a nudge to go post the real transaction) — no new
  reminder machinery.

### Dashboard

No change (see Non-goals) — flagged for the user to decide on separately.

## Testing

- Migration test (`test/migration_version_drift_test.dart` pattern):
  v33→v35 upgrade preserves existing goal data and adds the new
  columns/table with safe defaults.
- `AppDatabase` unit tests: a categorized transfer into a goal/loan account
  succeeds; a categorized transfer between two ordinary accounts still
  throws; `watchSpendByCategory` includes a tagged contribution/payment in
  its category total; a withdrawal (no category) doesn't affect budget
  progress.
- Widget tests: Goal creation/edit with a linked category; Loan
  creation, a payment reducing the outstanding balance, an EMI reminder
  pre-filled correctly; the two-tab Goals/Loans hub renders both tabs
  (`screens_smoke_test.dart` pattern).

## Migration/back-compat summary

Additive: one new enum variant (free), one new nullable column on
`GoalDetails`, one new table, one narrowed (not removed) validation rule,
one loop in `watchSpendByCategory` gaining a second case. Every existing
goal keeps working exactly as it does today (`categoryId` defaults to
null, meaning "don't count toward any budget," so upgrading changes
nothing for existing goals until the user opts a specific one into a
category). No existing route, table, or screen is removed — `/more/savings`
becomes `/more/goals` as a rename, not a parallel path.
