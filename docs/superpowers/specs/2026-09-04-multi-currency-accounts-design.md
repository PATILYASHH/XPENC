# Multi-currency accounts — design spec

Date: 2026-09-04
Status: draft, pending approval

## Background

The user wants each wallet/account to be able to hold its own currency
(e.g. an INR bank account alongside a USD travel wallet), a new **Currency**
module under Settings where they maintain exchange rates against a parent
currency, and every total in the app (Net Worth, Reports, transfers, PDF
statements, backups) to keep working correctly across accounts that don't
share a currency.

## Why this isn't a small change

The app has exactly **one** currency today, app-wide. `Money`
(`core/money.dart:13`) is a bare integer number of minor units with no
currency attached at all. Rendering is done by `MoneyFormat`
(`core/money.dart:73`), a single static singleton configured once from
`Settings.currencyCode` (`tables.dart:605`, `providers.dart:666`) and never
per-row. Every call site — `MoneyText` (`core/widgets/money_text.dart:124`),
PDF statements, CSV exports, backups — assumes "the" currency, not "this
account's" currency. `Accounts` and `Transactions` (`tables.dart:132`,
`tables.dart:201`) have no currency column; `watchNetWorth`
(`database.dart:2122`) sums every balance-holding account's `currentBalance`
directly with `+`, which is only correct because today they're guaranteed to
be the same currency.

So this is a genuine data-model addition (new columns, a new table, a new
migration) plus updating every place that currently renders or sums money
assuming a single ambient currency — not a UI-only feature.

## Decisions already made (with the user, before this doc)

- **Rates are snapshotted per transaction, not looked up live.** Each
  transaction records the exchange rate that was active when it was posted.
  Editing a rate later never changes what a past transaction's converted
  value was. This is what makes historical totals ("inflation-aware")
  stable.
- **The parent/base currency is the existing global `Settings.currencyCode`**
  (today's single app-wide currency setting) — not a new, separate choice.
  Existing users get a base currency for free, with zero new setup.
- **Cross-currency transfers**: the user enters the amount leaving the
  source account once; the app auto-converts it into the destination
  account's currency at the current rate for that pair, showing an editable
  "≈ received" figure before saving.
- **Category budgets and Envelope Mode stay parent-currency-only.** A
  foreign-currency account can freely have income/expenses and counts
  toward Net Worth, but cannot use Envelope Mode, and its transactions never
  count toward a category budget. This avoids mixing FX uncertainty into a
  feature (`categoryBalance`/`readyToAssign`) built around exact
  rupee-for-rupee assignment.
- **Full end-to-end in one phase**: the Currency module, per-account
  currency, snapshotted rates, converted transfers, and every screen that
  totals money (Dashboard, Net Worth, Reports, Budgets, backup/export, PDF
  statements) ship together — no intermediate state where some screens
  silently ignore non-base accounts.
- **An account's currency locks once it has its first transaction** —
  editable only while the account is empty. Prevents its existing native
  amounts from becoming ambiguous.

## Non-goals

- Live/fetched exchange rates (no API integration) — rates are entered
  manually in the Currency module, exactly as the user described
  ("comparative prices with parent currency").
- Multi-currency Envelope Mode / category budgets (see decisions above).
- Changing an account's currency after it has transactions.
- A currency-conversion "what-if" calculator or standalone FX tool — rates
  exist only to power account/transaction conversion.
- Currency support for `Persons`/`PersonEntries` lending — these stay
  implicitly parent-currency, same as budgets, since they're not tied to a
  specific account in the general case (`accountId` is nullable on
  `PersonEntries`, `tables.dart:367`).

## Data model

### New `CurrencyRates` table

```dart
@DataClassName('CurrencyRateRow')
class CurrencyRates extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The non-parent currency this rate prices, e.g. `USD`. Never the parent
  /// currency itself — the parent is always rate 1:1 with itself.
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();

  /// How many units of the PARENT currency equal 1 unit of [currencyCode],
  /// scaled by 1,000,000 so it's an exact integer — never a `double`, same
  /// rule as [Money]. `rateToBaseMicros: 83_120_000` means 1 USD = 83.12 INR.
  IntColumn get rateToBaseMicros => integer()();

  /// When this rate became active. A transaction snapshots the latest row
  /// with `effectiveAt <= transaction.date`.
  DateTimeColumn get effectiveAt => dateTime()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

Multiple rows per `currencyCode` accumulate as history — adding a new rate
is always an insert, never an update, so past snapshots stay resolvable
even after the "current" rate moves on.

`AppDatabase` gains:

- `latestRate(String currencyCode, {DateTime? asOf})` — the row with the
  greatest `effectiveAt <= (asOf ?? now)`, or `null` if the currency has no
  rate yet at that point in time.
- `watchCurrentRates()` — one row per currency in use, its most recent rate,
  for the Currency settings screen list.
- `addCurrencyRate(String currencyCode, int rateToBaseMicros, DateTime effectiveAt)`.

### `Accounts` gains one column

```dart
/// Null = this account is in the parent currency (`Settings.currencyCode`)
/// — true for every account created before this feature and for every
/// account a user never explicitly changes. Locked once the account has a
/// transaction (enforced in `addAccount`/`updateAccount`, not the schema).
TextColumn get currencyCode => text().withLength(min: 3, max: 3).nullable()();
```

A debit-card/UPI-style account (`linkedAccountId` non-null,
`tables.dart:142`) always inherits its linked account's currency and never
gets its own — it holds no balance of its own, so a separate currency on it
would be meaningless.

### `Transactions` gains four columns

```dart
/// This transaction's own currency, snapshotted from its account at post
/// time. Null = parent currency (matches `amount`'s existing meaning
/// exactly — no conversion needed). Never changes after the fact, even if
/// the account's currency setting somehow changed (it can't, once posted —
/// see the account-lock rule — but a transaction is self-describing anyway).
TextColumn get currencyCode => text().withLength(min: 3, max: 3).nullable()();

/// Snapshot of `CurrencyRates.rateToBaseMicros` as of `date`, for
/// [currencyCode]. Null iff [currencyCode] is null.
IntColumn get fxRateToBaseMicros => integer().nullable()();

/// Transfer only, and only when the source and destination accounts don't
/// share a currency: the amount credited to `toAccountId`, in *its own*
/// currency. Null for a same-currency transfer, where crediting `amount`
/// unchanged is already correct.
IntColumn get toAmount => integer().map(const MoneyConverter()).nullable()();

/// Transfer only, mirrors [currencyCode]/[fxRateToBaseMicros] for the
/// destination leg — the two accounts can each be a different currency
/// from the parent (and from each other), so the destination needs its own
/// independent snapshot.
TextColumn get toCurrencyCode => text().withLength(min: 3, max: 3).nullable()();
IntColumn get toFxRateToBaseMicros => integer().nullable()();
```

`amount` keeps its exact existing meaning: the native amount in the
transaction's own currency (source leg for a transfer). Nothing about how
`amount` is written or read changes for a parent-currency transaction —
every new column is simply null, identical to today's behavior.

A transaction's **base-currency value** is computed, never stored
redundantly:

```dart
extension TransactionBaseValue on TransactionRow {
  Money get baseAmount => currencyCode == null
      ? amount
      : Money((amount.paise * fxRateToBaseMicros!) ~/ 1000000);
}
```

This mirrors the existing Dart-side-fold style the codebase already uses
(`recalculateBalances`, `watchNetWorth` — fetch rows, compute in Dart) rather
than pushing conversion into SQL.

### Migration

Schema v58 → v59, appended to `onUpgrade` after the existing `if (from < 58)`
block (`database.dart:463`):

```dart
if (from < 59) {
  await m.createTable(currencyRates);
  await _addColumnIfMissing(m, accounts, accounts.currencyCode);
  await _addColumnIfMissing(m, transactions, transactions.currencyCode);
  await _addColumnIfMissing(m, transactions, transactions.fxRateToBaseMicros);
  await _addColumnIfMissing(m, transactions, transactions.toAmount);
  await _addColumnIfMissing(m, transactions, transactions.toCurrencyCode);
  await _addColumnIfMissing(m, transactions, transactions.toFxRateToBaseMicros);
}
```

Every new column is nullable and additive; every existing row upgrades with
all-null values, which is defined above to mean exactly today's behavior.
No backfill needed.

## Rendering change: `MoneyFormat` / `MoneyText`

`MoneyFormat` (`core/money.dart:73`) stays the single global formatter for
the **parent** currency — Dashboard, Net Worth, Reports, Budgets keep using
it completely unchanged, since those are always parent-currency totals.

For rendering a specific account's or transaction's own (possibly foreign)
amount, `MoneyFormat` gains one new method that formats a `Money` against an
*explicit* `Currency` instead of the configured global one:

```dart
static String symbolIn(Money m, Currency c) => ...
```

(built the same way `_buildWithSymbol` already is, just not cached — this
path is only used per-row, not hot enough to need the cached `NumberFormat`s
the global path has).

`MoneyText`/`BalanceText`/`AnimatedBalanceText`
(`core/widgets/money_text.dart:124,174,195`) each gain an optional
`Currency? currency` parameter. `null` (the default, and the only value
every existing call site passes) renders exactly as today, via the global
`MoneyFormat`. Only call sites that render one specific account's/
transaction's amount — the transaction list tile, account detail balance,
the add/edit transaction amount field, the transfer sheet's two amount
fields — are updated to pass that row's `Currency` explicitly. Every
aggregate-total call site (Dashboard cards, Net Worth, Reports, Budget
progress, category totals) is left untouched, since those are already,
correctly, parent-currency figures.

## Balances, Net Worth, Reports, Budgets

- **Per-account screens** (account detail, its own transaction list): always
  native currency, unchanged mechanics — `currentBalance`/`openingBalance`
  stay stored in the account's own currency, `recalculateBalances`
  (`database.dart:2061`) is untouched.
- **Net Worth / Accounts-screen grand total / Dashboard hero figure**
  (`watchNetWorth`, `database.dart:2122`): changes from a plain `+` fold to
  converting each account's `currentBalance` into the parent currency using
  **today's** rate (`latestRate(account.currencyCode)`, no `asOf`) before
  summing — a balance is a "right now" figure, so it uses the live rate,
  not a snapshot.
- **Reports/Stats aggregate charts, `watchSpendByCategory`**
  (`database.dart:2209`) and similar category/income/expense totals: fold
  using each transaction's `baseAmount` (its **snapshotted** rate) instead
  of raw `amount`. Parent-currency transactions are unaffected (`baseAmount
  == amount` when `currencyCode == null`).
- **Category budgets / Envelope Mode**: no change — per the decision above,
  these already only ever see parent-currency accounts, so `baseAmount ==
  amount` for every row they touch.

## Screens & UI

### Currency module (Settings → Currency)

New screen, `lib/features/settings/currency_settings_screen.dart`, linked
from `settings_screen.dart` next to the existing entries. Shows:

- The parent currency (today's `currencyProvider`, `providers.dart:666`,
  relabelled "Parent currency" in this screen's copy — the underlying
  setting and `setCurrencyCode` call are unchanged).
- One row per currency currently used by any account, its latest rate
  ("1 USD = 83.12 INR"), and when it was last updated. Reuses
  `CurrencyPickerSheet`'s search list (`currency_picker_sheet.dart:9`) to
  add a currency not yet in use.
- Tapping a row opens a small history list (every `CurrencyRates` row for
  that code, newest first) plus an "Add rate" action: pick an effective
  date (defaults to today) and enter the new rate. This always inserts,
  never edits a past row — preserves old snapshots' resolvability.

### Accounts

`add_account_sheet.dart` (fields currently built around
`_type`/`_colorValue`/`_iconKey`, lines 54–143) gains a currency picker
(reusing `CurrencyPickerSheet`'s list), defaulting to the parent currency,
shown for every account type except a debit card / UPI instrument (which
mirrors its linked account instead — no picker shown). Once the account has
at least one transaction, the field becomes read-only with a short
explanation, enforced in `AppDatabase.updateAccount` as well as the UI (not
just a disabled control).

### Transactions

The add/edit transaction screen (`add_transaction_screen.dart`) resolves the
selected account's currency and:

- Shows the amount field in that currency's symbol/decimal places.
- On save, if the account's `currencyCode` is non-null, resolves
  `latestRate(code, asOf: date)` and writes `currencyCode`/
  `fxRateToBaseMicros` onto the transaction; throws a clear, catchable error
  if no rate exists yet as of that date (steers the user to the Currency
  module first) rather than silently defaulting to 1:1.
- For a transfer where source and destination currencies differ: after the
  debit amount is entered, shows a second, editable "≈ you'll receive"
  field pre-filled by converting through both accounts' current rates
  (`amount → base → destination`), saved as `toAmount`/`toCurrencyCode`/
  `toFxRateToBaseMicros` alongside the source leg's own snapshot.

### Backups / PDF statements

- JSON backups: the exporter already walks tables generically and stamps a
  `schemaVersion` (`database.dart:4805`), so the six new columns ride along
  automatically. Restoring an old (pre-v59) backup produces all-null new
  columns — defined above to mean "parent currency" — so old backups restore
  with identical behavior to today.
- PDF statements (`statement_pdf.dart`, `report_pdf.dart`): each line shows
  its transaction's native amount; a statement for a non-parent-currency
  account gains one subtotal line converted to the parent currency (using
  each line's own snapshotted rate, i.e. `Σ baseAmount`), so a statement
  handed to someone using the parent currency still totals correctly.

## Testing

- Migration test (existing `migration_version_drift_test.dart` pattern):
  v58→v59 upgrade adds `CurrencyRates` and the five new columns with safe
  (null) defaults; an existing account/transaction round-trips unchanged.
- `AppDatabase` unit tests: `latestRate` resolves the correct historical row
  for a given `asOf` date; adding a transaction on a foreign-currency
  account with no rate yet throws; `watchNetWorth` correctly converts a
  mixed-currency set of accounts using the live rate; `watchSpendByCategory`
  sums using each transaction's snapshotted rate, not the live one, after
  the rate is changed post-hoc; a cross-currency transfer's `toAmount`
  lands in the destination account's balance correctly;
  `updateAccount` rejects a currency change once a transaction exists.
- Widget tests: Currency settings screen lists rates and accepts a new one;
  account creation offers/hides the currency picker correctly for a
  debit-card account; the transfer sheet's auto-converted "≈ received"
  field appears only when currencies differ and remains editable.

## Migration/back-compat summary

Purely additive: one new table, five new nullable columns (`accounts.currencyCode`
plus four on `transactions`), one new rendering method
(`MoneyFormat.symbolIn`), one new optional parameter on three widgets, and
one changed fold (`+` → currency-aware sum) in `watchNetWorth` and
`watchSpendByCategory`. Every existing account/transaction has `currencyCode
== null`, meaning "parent currency," which is defined throughout this spec
to behave identically to today. No existing table, column, route, or screen
is removed or renamed (the Currency module is new; the existing currency
picker screen keeps its current job of setting the parent currency and is
reused, not replaced, inside the new module).
