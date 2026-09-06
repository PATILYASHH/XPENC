# Multi-currency accounts — Plan 1: Core data & conversion engine

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the database a real per-account currency, a manually-maintained
exchange-rate history, and snapshot-based conversion — with every balance/net
worth computation correct for a mix of currencies — with zero UI yet.

**Architecture:** Additive Drift schema (one new table, five new nullable
columns) at migration v60. A new `lib/data/currency_conversion.dart` holds the
pure integer-scaled conversion math, reused by `AppDatabase` (rate lookup,
transaction-time snapshotting, `watchNetWorth`) and, later, by UI code. No
existing table, column, or public method signature is removed — this plan
only adds.

**Tech Stack:** Dart 3.10, Flutter, Drift (SQLite ORM) with `build_runner`
codegen, `flutter_test`.

**Relationship to other plans:** This is Plan 1 of the multi-currency-accounts
feature (see `docs/superpowers/specs/2026-09-04-multi-currency-accounts-design.md`).
It produces a fully tested backend with no screens — Plan 2 (Currency settings
screen), Plan 3 (account/transaction/transfer UI) and Plan 4 (backups/PDF
statements) build on top of it. Every task here ends with the app compiling
and `flutter test` green; this plan is safe to ship on its own even before
any UI exists to set a non-default currency.

---

### Task 1: Schema — `CurrencyRates` table and new columns

**Files:**
- Modify: `lib/data/tables.dart`
- Modify: `lib/data/database.dart:117-152` (table registration), `:463-487` (migration)
- Generated (do not hand-edit): `lib/data/database.g.dart`
- Test: `test/migration_version_drift_test.dart`

- [ ] **Step 1: Add the `CurrencyRates` table to `tables.dart`**

Add this after the `MoneyConverter` class (`tables.dart:127`), before the
`// ─── Tables ───` section's first table, so it sits with the other
top-level tables:

```dart
/// A manually-entered exchange rate: how many units of the parent currency
/// (`Settings.currencyCode`) equal one unit of some other currency, as of a
/// given date. Never fetched live — see the design spec's "Non-goals".
///
/// Rows accumulate as history; adding a new rate is always an insert, never
/// an update, so a transaction posted under an old rate stays resolvable
/// (`AppDatabase.latestRate`) even after the rate moves on. This is what
/// makes converted historical totals stable when the rate changes later.
@DataClassName('CurrencyRateRow')
class CurrencyRates extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The non-parent currency this rate prices, e.g. `USD`. Never the parent
  /// currency itself, which is always 1:1 with itself.
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();

  /// Units of the parent currency per 1 unit of [currencyCode], scaled by
  /// [currencyRateScale] so it's an exact integer — never a `double`, the
  /// same rule [Money] follows. `83_120_000` means 1 unit = 83.12 parent.
  IntColumn get rateToBaseMicros => integer()();

  DateTimeColumn get effectiveAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

Then add the five new columns. In `Accounts` (`tables.dart:132-176`), just
before the closing `}`:

```dart
  /// Null = this account is in the parent currency (`Settings.currencyCode`)
  /// — true for every account that existed before this feature, and for
  /// every account a user never explicitly changes. Locked once the account
  /// has a transaction (enforced in `AppDatabase.setAccountCurrency`, not
  /// here — Drift columns can't express that rule). A debit-card/UPI
  /// instrument (non-null `linkedAccountId`) never gets its own value here —
  /// it always mirrors its linked account's currency.
  TextColumn get currencyCode => text().withLength(min: 3, max: 3).nullable()();
```

In `Transactions` (`tables.dart:201-266`, right after the existing
`paymentGroupId` column and before the closing `}` — note this table
already has an unrelated `foreignCurrencyCode`/`foreignAmount` pair from
GitHub #85; add these as a second, clearly-distinguished group):

```dart
  /// This transaction's own ledger currency, snapshotted from its account's
  /// [Accounts.currencyCode] at post time. Null = parent currency, which
  /// matches [amount]'s existing meaning exactly (no conversion needed).
  /// Distinct from the #85 [foreignCurrencyCode]/[foreignAmount] pair above,
  /// which is a manual informational annotation on a parent-currency
  /// transaction — this pair instead describes the transaction's *real*
  /// native currency, inherited from its account.
  TextColumn get currencyCode => text().withLength(min: 3, max: 3).nullable()();

  /// Snapshot of `CurrencyRates.rateToBaseMicros` as of [date], for
  /// [currencyCode]. Null iff [currencyCode] is null.
  IntColumn get fxRateToBaseMicros => integer().nullable()();

  /// Transfer only, and only when the source and destination accounts don't
  /// share a currency: the amount credited to [toAccountId], in *its own*
  /// currency. Null for a same-currency transfer, where crediting [amount]
  /// unchanged is already correct — see `AppDatabase._applyTxEffect`.
  IntColumn get toAmount => integer().map(const MoneyConverter()).nullable()();

  /// Transfer only, mirrors [currencyCode]/[fxRateToBaseMicros] for the
  /// destination leg — the two accounts can each be a different currency
  /// from the parent (and from each other), so the destination needs its
  /// own independent snapshot.
  TextColumn get toCurrencyCode => text().withLength(min: 3, max: 3).nullable()();
  IntColumn get toFxRateToBaseMicros => integer().nullable()();
```

- [ ] **Step 2: Register the table and bump the schema version**

In `lib/data/database.dart`, add `CurrencyRates` to the `@DriftDatabase`
`tables` list (`database.dart:118-151`), anywhere — alphabetically near
`CreditCardDetails` is fine:

```dart
    CreditCardDetails,
    CurrencyRates,
```

Change the schema version (`database.dart:176`):

```dart
  int get schemaVersion => 60;
```

Append a new migration step after the existing `if (from < 59)` block
(`database.dart:467-487`), inside `onUpgrade`, right before its closing
`}`:

```dart
      if (from < 60) {
        // Multi-currency accounts — see
        // docs/superpowers/specs/2026-09-04-multi-currency-accounts-design.md.
        await m.createTable(currencyRates);
        await _addColumnIfMissing(m, accounts, accounts.currencyCode);
        await _addColumnIfMissing(m, transactions, transactions.currencyCode);
        await _addColumnIfMissing(
          m,
          transactions,
          transactions.fxRateToBaseMicros,
        );
        await _addColumnIfMissing(m, transactions, transactions.toAmount);
        await _addColumnIfMissing(
          m,
          transactions,
          transactions.toCurrencyCode,
        );
        await _addColumnIfMissing(
          m,
          transactions,
          transactions.toFxRateToBaseMicros,
        );
      }
```

- [ ] **Step 3: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes with `Succeeded after ...` and no errors; `git diff
lib/data/database.g.dart` shows a new `CurrencyRates`/`CurrencyRateRow`
table class and the new columns on `Accounts`/`AccountRow`/
`Transactions`/`TransactionRow`.

- [ ] **Step 4: Write the failing migration test**

Add to `test/migration_version_drift_test.dart`, inside `main()` after the
existing "v46 group tables" test (`migration_version_drift_test.dart:107-129`):

```dart
  test(
    'the v60 CurrencyRates table and account/transaction currency columns '
    'survive a rolled-back re-open',
    () async {
      final file = await buildRolledBackDatabase(59);

      final reopened = AppDatabase(NativeDatabase(file));
      await expectLater(reopened.select(reopened.currencyRates).get(), completes);
      await expectLater(reopened.select(reopened.accounts).get(), completes);
      await expectLater(reopened.select(reopened.transactions).get(), completes);
      await reopened.close();
    },
  );
```

- [ ] **Step 5: Run the test to verify it currently passes**

Run: `flutter test test/migration_version_drift_test.dart`
Expected: PASS (this test validates the migration you just wrote, so it
should already pass — if it fails, `_addColumnIfMissing`/`createTable`
calls in Step 2 are wrong; fix before continuing).

- [ ] **Step 6: Full-suite sanity check, then commit**

Run: `flutter test`
Expected: PASS (no existing test should be affected by purely-additive
nullable columns).

```bash
git add lib/data/tables.dart lib/data/database.dart lib/data/database.g.dart test/migration_version_drift_test.dart
git commit -m "feat: add CurrencyRates table and per-account/transaction currency columns (v60)"
```

---

### Task 2: Pure conversion math (`currency_conversion.dart`)

**Files:**
- Create: `lib/data/currency_conversion.dart`
- Test: `test/currency_conversion_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/currency_conversion.dart';
import 'package:xpenc/data/database.dart';

void main() {
  group('convertUsingRate', () {
    test('1 USD = 83.12 INR converts $10.00 to ₹831.20', () {
      final converted = convertUsingRate(
        const Money(1000), // $10.00
        83120000, // 83.12 scaled by currencyRateScale
      );
      expect(converted, const Money(83120)); // ₹831.20
    });

    test('a 1:1 rate is a no-op', () {
      final converted = convertUsingRate(const Money(50000), 1000000);
      expect(converted, const Money(50000));
    });
  });

  group('TransactionBaseValue.baseAmount', () {
    test('a parent-currency transaction (null currencyCode) is unconverted', () {
      final row = TransactionRow(
        id: 1,
        type: TxType.expense,
        amount: const Money(50000),
        accountId: 1,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        needsAmountReview: false,
      );
      expect(row.baseAmount, const Money(50000));
    });

    test('a foreign-currency transaction converts using its snapshotted rate', () {
      final row = TransactionRow(
        id: 1,
        type: TxType.expense,
        amount: const Money(1000), // $10.00
        accountId: 1,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        needsAmountReview: false,
        currencyCode: const Value('USD'),
        fxRateToBaseMicros: const Value(83120000),
      );
      expect(row.baseAmount, const Money(83120)); // ₹831.20
    });
  });
}
```

Note: `TransactionRow` is a generated Drift data class — pass every
non-nullable field positionally/named as shown (matching whatever
`database.g.dart` generated for the existing columns), and the two new
nullable fields via `Value(...)`. If the generated constructor rejects
`Value(...)` for a plain data-class field (Drift data classes take raw
values, not `Value<T>` — that wrapper is only for `Companion`s), use the
raw value directly instead, e.g. `currencyCode: 'USD', fxRateToBaseMicros:
83120000` — check `database.g.dart`'s `TransactionRow` constructor
signature and match it exactly.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/currency_conversion_test.dart`
Expected: FAIL — `currency_conversion.dart` doesn't exist yet (import error).

- [ ] **Step 3: Write the implementation**

```dart
import '../core/money.dart';
import 'tables.dart';

/// [CurrencyRates.rateToBaseMicros] and [Transactions.fxRateToBaseMicros]
/// are both scaled by this so the rate is an exact integer, never a
/// `double` — the same rule [Money] itself follows.
const currencyRateScale = 1000000;

/// Converts [amount] (in some other currency) into the parent currency
/// using [rateToBaseMicros] — units of parent per 1 unit of that currency,
/// scaled by [currencyRateScale].
Money convertUsingRate(Money amount, int rateToBaseMicros) =>
    Money((amount.paise * rateToBaseMicros) ~/ currencyRateScale);

/// A transaction's value in the parent currency — computed, never stored
/// redundantly. Every Reports/Stats/Budget total that must stay stable
/// after a rate changes later (the "snapshot" design decision) folds over
/// this instead of raw [TransactionRow.amount].
extension TransactionBaseValue on TransactionRow {
  Money get baseAmount => currencyCode == null
      ? amount
      : convertUsingRate(amount, fxRateToBaseMicros!);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/currency_conversion_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/currency_conversion.dart test/currency_conversion_test.dart
git commit -m "feat: add pure currency-conversion math and TransactionRow.baseAmount"
```

---

### Task 3: `AppDatabase` rate methods

**Files:**
- Modify: `lib/data/database.dart` (add a new `// ── Currency rates ──` section — put it right after `recalculateBalances` ends, around `database.dart:2100`, before `// ── Queries ──`)
- Test: `test/currency_rates_db_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('addCurrencyRate', () {
    test('rejects an unknown currency code', () {
      expect(
        () => db.addCurrencyRate(
          currencyCode: 'ZZZ',
          rateToBaseMicros: 83000000,
          effectiveAt: DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive rate', () {
      expect(
        () => db.addCurrencyRate(
          currencyCode: 'USD',
          rateToBaseMicros: 0,
          effectiveAt: DateTime(2026, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('accepts a valid rate', () async {
      final id = await db.addCurrencyRate(
        currencyCode: 'USD',
        rateToBaseMicros: 83000000,
        effectiveAt: DateTime(2026, 1, 1),
      );
      expect(id, greaterThan(0));
    });
  });

  group('latestRate', () {
    test('returns null when the currency has no rate yet', () async {
      final rate = await db.latestRate('USD');
      expect(rate, isNull);
    });

    test('resolves the most recent rate at or before "asOf"', () async {
      await db.addCurrencyRate(
        currencyCode: 'USD',
        rateToBaseMicros: 80000000,
        effectiveAt: DateTime(2026, 1, 1),
      );
      await db.addCurrencyRate(
        currencyCode: 'USD',
        rateToBaseMicros: 85000000,
        effectiveAt: DateTime(2026, 6, 1),
      );

      final beforeBoth = await db.latestRate(
        'USD',
        asOf: DateTime(2025, 12, 1),
      );
      expect(beforeBoth, isNull);

      final betweenThem = await db.latestRate(
        'USD',
        asOf: DateTime(2026, 3, 1),
      );
      expect(betweenThem!.rateToBaseMicros, 80000000);

      final afterBoth = await db.latestRate('USD', asOf: DateTime(2026, 12, 1));
      expect(afterBoth!.rateToBaseMicros, 85000000);
    });
  });

  group('watchCurrentRates', () {
    test('emits one row per currency, the newest rate for each', () async {
      await db.addCurrencyRate(
        currencyCode: 'USD',
        rateToBaseMicros: 80000000,
        effectiveAt: DateTime(2026, 1, 1),
      );
      await db.addCurrencyRate(
        currencyCode: 'USD',
        rateToBaseMicros: 85000000,
        effectiveAt: DateTime(2026, 6, 1),
      );
      await db.addCurrencyRate(
        currencyCode: 'EUR',
        rateToBaseMicros: 90000000,
        effectiveAt: DateTime(2026, 1, 1),
      );

      final rows = await db.watchCurrentRates().first;
      expect(rows, hasLength(2));
      final usd = rows.firstWhere((r) => r.currencyCode == 'USD');
      expect(usd.rateToBaseMicros, 85000000);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/currency_rates_db_test.dart`
Expected: FAIL — `addCurrencyRate`/`latestRate`/`watchCurrentRates` are
undefined methods on `AppDatabase`.

- [ ] **Step 3: Implement the methods**

In `lib/data/database.dart`, add near the top of the file's imports (check
it isn't already imported — `_validateForeignCurrency` at `database.dart:866`
already calls `currencyForCode`, so `core/currency.dart` should already be
imported; if not, add `import '../core/currency.dart';`) and add
`import 'currency_conversion.dart';`.

Insert this new section right after `recalculateBalances` closes
(`database.dart:2099`, before the `// ── Queries ──` comment at `:2101`):

```dart
  // ── Currency rates ───────────────────────────────────────────────────────

  /// The most recent rate for [currencyCode] at or before [asOf] (defaults
  /// to now) — `null` if none has been entered yet as of that date. This is
  /// what a transaction snapshots at post time, and what a live figure
  /// (Net Worth) resolves with `asOf` left at its default.
  Future<CurrencyRateRow?> latestRate(
    String currencyCode, {
    DateTime? asOf,
  }) {
    final cutoff = asOf ?? DateTime.now();
    return (select(currencyRates)
          ..where(
            (r) =>
                r.currencyCode.equals(currencyCode) &
                r.effectiveAt.isSmallerOrEqualValue(cutoff),
          )
          ..orderBy([
            (r) => OrderingTerm(expression: r.effectiveAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Records a new rate. Always an insert, never an update — see
  /// [CurrencyRates]'s doc for why history must never be overwritten.
  Future<int> addCurrencyRate({
    required String currencyCode,
    required int rateToBaseMicros,
    required DateTime effectiveAt,
  }) {
    if (rateToBaseMicros <= 0) {
      throw ArgumentError('Rate must be positive.');
    }
    if (currencyForCode(currencyCode).code != currencyCode) {
      throw ArgumentError('Unknown currency code: $currencyCode.');
    }
    return into(currencyRates).insert(
      CurrencyRatesCompanion.insert(
        currencyCode: currencyCode,
        rateToBaseMicros: rateToBaseMicros,
        effectiveAt: effectiveAt,
      ),
    );
  }

  /// One row per currency that has ever had a rate entered, each the most
  /// recent — the list the Currency settings screen renders. Folds in Dart
  /// rather than SQL, same style as [recalculateBalances]/[watchNetWorth].
  Stream<List<CurrencyRateRow>> watchCurrentRates() =>
      select(currencyRates).watch().map((rows) {
        final latest = <String, CurrencyRateRow>{};
        for (final r in rows) {
          final existing = latest[r.currencyCode];
          if (existing == null || r.effectiveAt.isAfter(existing.effectiveAt)) {
            latest[r.currencyCode] = r;
          }
        }
        final list = latest.values.toList()
          ..sort((a, b) => a.currencyCode.compareTo(b.currencyCode));
        return list;
      });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/currency_rates_db_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/database.dart test/currency_rates_db_test.dart
git commit -m "feat: add AppDatabase.latestRate/addCurrencyRate/watchCurrentRates"
```

---

### Task 4: Account currency — creation and the first-transaction lock

**Files:**
- Modify: `lib/data/database.dart:2348-2386` (`addAccount`), and add `setAccountCurrency` near `renameAccount` (`database.dart:2392-2400`)
- Test: `test/account_currency_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addBank({String? currencyCode}) => db.addAccount(
        name: 'Bank',
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconKey: 'bank',
        openingBalance: const Money(10000),
        currencyCode: currencyCode,
      );

  test('addAccount defaults to null (parent currency)', () async {
    final id = await addBank();
    final row = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingle();
    expect(row.currencyCode, isNull);
  });

  test('addAccount stores an explicit foreign currency', () async {
    final id = await addBank(currencyCode: 'USD');
    final row = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingle();
    expect(row.currencyCode, 'USD');
  });

  test('a debit card never gets its own currency, even if one is passed', () async {
    final bankId = await addBank(currencyCode: 'USD');
    final cardId = await db.addAccount(
      name: 'Debit card',
      type: AccountType.card,
      cardKind: CardKind.debit,
      linkedAccountId: bankId,
      colorValue: 0xFF000000,
      iconKey: 'card',
      openingBalance: const Money.zero(),
      currencyCode: 'EUR',
    );
    final row = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(cardId))).getSingle();
    expect(row.currencyCode, isNull);
  });

  group('setAccountCurrency', () {
    test('changes the currency of an untouched account', () async {
      final id = await addBank();
      await db.setAccountCurrency(id, 'USD');
      final row = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(id))).getSingle();
      expect(row.currencyCode, 'USD');
    });

    test('locks once the account has a transaction', () async {
      final id = await addBank();
      await db.addTransaction(
        type: TxType.income,
        amount: const Money(5000),
        accountId: id,
        date: DateTime(2026, 1, 1),
      );

      expect(
        () => db.setAccountCurrency(id, 'USD'),
        throwsArgumentError,
      );
    });

    test('rejects an unknown currency code', () async {
      final id = await addBank();
      expect(() => db.setAccountCurrency(id, 'ZZZ'), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/account_currency_test.dart`
Expected: FAIL — `addAccount` has no `currencyCode` parameter,
`setAccountCurrency` is undefined.

- [ ] **Step 3: Implement**

Modify `addAccount` (`database.dart:2348-2386`):

```dart
  Future<int> addAccount({
    required String name,
    required AccountType type,
    CardKind? cardKind,
    int? linkedAccountId,
    String? bankName,
    String? last4,
    required int colorValue,
    required String iconKey,
    required Money openingBalance,
    String? currencyCode,
  }) {
    if (type == AccountType.card && cardKind == null) {
      throw ArgumentError('A card must be credit or debit.');
    }
    if (cardKind == CardKind.debit && linkedAccountId == null) {
      throw ArgumentError(
        'A debit card must be linked to the bank account it draws from.',
      );
    }
    // An instrument (debit card) holds no balance, and no currency, of its
    // own — it always mirrors the account it draws from.
    final opening = linkedAccountId == null
        ? openingBalance
        : const Money.zero();
    final resolvedCurrencyCode = linkedAccountId == null ? currencyCode : null;
    if (resolvedCurrencyCode != null &&
        currencyForCode(resolvedCurrencyCode).code != resolvedCurrencyCode) {
      throw ArgumentError('Unknown currency code: $resolvedCurrencyCode.');
    }

    return into(accounts).insert(
      AccountsCompanion.insert(
        name: name,
        type: type,
        cardKind: Value(cardKind),
        linkedAccountId: Value(linkedAccountId),
        bankName: Value(bankName),
        last4: Value(last4),
        colorValue: colorValue,
        iconKey: iconKey,
        openingBalance: opening,
        currentBalance: opening,
        currencyCode: Value(resolvedCurrencyCode),
      ),
    );
  }
```

Add `setAccountCurrency` right after `renameAccount`
(`database.dart:2392-2400`):

```dart
  /// Changes an account's currency. Only ever allowed before it has a
  /// transaction — once one exists, its native amount is only meaningful
  /// under the currency it was posted in, so the field locks (see the
  /// design spec's "an account's currency locks once it has its first
  /// transaction" decision). A linked card can never set its own currency —
  /// it always mirrors the account it draws from.
  Future<void> setAccountCurrency(int id, String? currencyCode) async {
    if (currencyCode != null &&
        currencyForCode(currencyCode).code != currencyCode) {
      throw ArgumentError('Unknown currency code: $currencyCode.');
    }
    final account = await (select(
      accounts,
    )..where((a) => a.id.equals(id))).getSingle();
    if (account.linkedAccountId != null) {
      throw ArgumentError(
        "A linked card always uses its bank account's currency.",
      );
    }
    if (await countTransactionsForAccount(id) > 0) {
      throw ArgumentError(
        'This account already has transactions — its currency is locked.',
      );
    }
    await (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(currencyCode: Value(currencyCode)),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/account_currency_test.dart`
Expected: PASS

- [ ] **Step 5: Run the full suite (this touches a widely-used method signature)**

Run: `flutter test`
Expected: PASS — `addAccount`'s new `currencyCode` parameter is optional, so
every existing call site (which doesn't pass it) is unaffected.

- [ ] **Step 6: Commit**

```bash
git add lib/data/database.dart test/account_currency_test.dart
git commit -m "feat: add per-account currency, locked after the first transaction"
```

---

### Task 5: Transaction currency snapshot on `addTransaction`

**Files:**
- Modify: `lib/data/database.dart:985-1039` (`addTransaction`)
- Test: `test/transaction_currency_snapshot_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> addAccountWithCurrency(String? code) => db.addAccount(
        name: 'Acct $code',
        type: AccountType.bank,
        colorValue: 0xFF000000,
        iconKey: 'bank',
        openingBalance: const Money.zero(),
        currencyCode: code,
      );

  test('a parent-currency account posts with null currency/rate', () async {
    final id = await addAccountWithCurrency(null);
    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: const Money(50000),
      accountId: id,
      date: DateTime(2026, 1, 1),
    );
    final row = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(txId))).getSingle();
    expect(row.currencyCode, isNull);
    expect(row.fxRateToBaseMicros, isNull);
  });

  test('a foreign-currency account with no rate yet throws', () async {
    final id = await addAccountWithCurrency('USD');
    expect(
      () => db.addTransaction(
        type: TxType.expense,
        amount: const Money(1000),
        accountId: id,
        date: DateTime(2026, 1, 1),
      ),
      throwsArgumentError,
    );
  });

  test('a foreign-currency account snapshots the rate as of the tx date', () async {
    final id = await addAccountWithCurrency('USD');
    await db.addCurrencyRate(
      currencyCode: 'USD',
      rateToBaseMicros: 80000000,
      effectiveAt: DateTime(2026, 1, 1),
    );
    await db.addCurrencyRate(
      currencyCode: 'USD',
      rateToBaseMicros: 85000000,
      effectiveAt: DateTime(2026, 6, 1),
    );

    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: const Money(1000),
      accountId: id,
      date: DateTime(2026, 3, 1), // between the two rates
    );
    final row = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(txId))).getSingle();
    expect(row.currencyCode, 'USD');
    expect(row.fxRateToBaseMicros, 80000000);
  });

  group('cross-currency transfer', () {
    test('same-currency transfer leaves toAmount/toCurrencyCode null', () async {
      final a = await addAccountWithCurrency(null);
      final b = await addAccountWithCurrency(null);
      final txId = await db.addTransaction(
        type: TxType.transfer,
        amount: const Money(50000),
        accountId: a,
        toAccountId: b,
        date: DateTime(2026, 1, 1),
      );
      final row = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      expect(row.toAmount, isNull);
      expect(row.toCurrencyCode, isNull);
    });

    test('parent to foreign transfer computes toAmount via the current rate', () async {
      final inrAcct = await addAccountWithCurrency(null);
      final usdAcct = await addAccountWithCurrency('USD');
      await db.addCurrencyRate(
        currencyCode: 'USD',
        rateToBaseMicros: 83000000, // 1 USD = 83 INR
        effectiveAt: DateTime(2026, 1, 1),
      );

      final txId = await db.addTransaction(
        type: TxType.transfer,
        amount: const Money(830000), // ₹8300.00
        accountId: inrAcct,
        toAccountId: usdAcct,
        date: DateTime(2026, 2, 1),
      );
      final row = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(txId))).getSingle();
      expect(row.toCurrencyCode, 'USD');
      // ₹8300.00 / 83 = $100.00
      expect(row.toAmount, const Money(10000));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/transaction_currency_snapshot_test.dart`
Expected: FAIL — every new column stays null/unpopulated (`addTransaction`
doesn't resolve currency yet), so the "throws" and "snapshots the rate"
assertions fail.

- [ ] **Step 3: Implement**

Add a private helper right before `addTransaction`
(`database.dart:985`), and rewrite `addTransaction` to use it:

```dart
  /// Resolves what [accountId] should stamp onto a transaction posted on
  /// [date]: `(null, null)` for a parent-currency account, or its currency
  /// code plus the rate snapshot for a foreign-currency one. Throws if the
  /// account is foreign-currency but no rate has been entered yet as of
  /// that date — silently falling back to 1:1 would quietly corrupt every
  /// downstream total, so this fails loudly instead and the UI is
  /// responsible for steering the user to the Currency settings screen
  /// first (Plan 2/3).
  Future<(String?, int?)> _resolveTxCurrency(int accountId, DateTime date) async {
    final account = await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    final code = account.currencyCode;
    if (code == null) return (null, null);
    final rate = await latestRate(code, asOf: date);
    if (rate == null) {
      throw ArgumentError(
        'No exchange rate set for $code yet — add one in Settings > '
        'Currency before posting this transaction.',
      );
    }
    return (code, rate.rateToBaseMicros);
  }
```

Replace the body of `addTransaction` (`database.dart:985-1039`):

```dart
  Future<int> addTransaction({
    required TxType type,
    required Money amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    int? personId,
    required DateTime date,
    String? note,
    String? payee,
    int? recurringRuleId,
    String? imagePath,
    bool needsAmountReview = false,
    String? foreignCurrencyCode,
    Money? foreignAmount,
  }) async {
    await _validateTx(
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      personId: personId,
      payee: payee,
      recurringRuleId: recurringRuleId,
      foreignCurrencyCode: foreignCurrencyCode,
      foreignAmount: foreignAmount,
    );

    final (sourceCode, sourceRate) = await _resolveTxCurrency(accountId, date);

    String? toCode;
    int? toRate;
    Money? toAmt;
    if (type == TxType.transfer && toAccountId != null) {
      final resolved = await _resolveTxCurrency(toAccountId, date);
      toCode = resolved.$1;
      toRate = resolved.$2;
      if (toCode != sourceCode) {
        final sourceBase = sourceCode == null
            ? amount
            : convertUsingRate(amount, sourceRate!);
        toAmt = toCode == null
            ? sourceBase
            : Money((sourceBase.paise * currencyRateScale) ~/ toRate!);
      }
    }

    return transaction(() async {
      final id = await into(transactions).insert(
        TransactionsCompanion.insert(
          type: type,
          amount: amount,
          accountId: accountId,
          toAccountId: Value(toAccountId),
          categoryId: Value(categoryId),
          personId: Value(personId),
          date: date,
          note: Value(note),
          payee: Value(payee),
          recurringRuleId: Value(recurringRuleId),
          imagePath: Value(imagePath),
          needsAmountReview: Value(needsAmountReview),
          foreignCurrencyCode: Value(foreignCurrencyCode),
          foreignAmount: Value(foreignAmount),
          currencyCode: Value(sourceCode),
          fxRateToBaseMicros: Value(sourceRate),
          toAmount: Value(toAmt),
          toCurrencyCode: Value(toCode),
          toFxRateToBaseMicros: Value(toRate),
        ),
      );
      final row = await (select(
        transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      await _applyTxEffect(row, reverse: false);
      return id;
    });
  }
```

Add the import at the top of `database.dart` (next to the other local
imports): `import 'currency_conversion.dart';` (skip if Task 3 already
added it).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/transaction_currency_snapshot_test.dart`
Expected: PASS

- [ ] **Step 5: Full-suite check, then commit**

Run: `flutter test`
Expected: PASS. (`addHybridPaymentTransaction` and any other transaction-
writing path that doesn't go through `addTransaction` is untouched by this
task — cross-currency hybrid payments are explicitly out of scope per the
spec's Non-goals; leave `addHybridPaymentTransaction` as-is.)

```bash
git add lib/data/database.dart test/transaction_currency_snapshot_test.dart
git commit -m "feat: snapshot currency/rate onto a transaction at post time"
```

---

### Task 6: Fix balance math for cross-currency transfers

**Files:**
- Modify: `lib/data/database.dart:834-851` (`_applyTxEffect`), `:2061-2099` (`recalculateBalances`)
- Test: `test/cross_currency_balance_test.dart`

Without this fix, Task 5's `toAmount` is stored but never used — a
cross-currency transfer would still credit the destination account with the
*source*-currency `amount`, silently corrupting its balance (e.g. crediting
"8300" to a USD wallet instead of "100").

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a cross-currency transfer credits the destination in its own currency',
      () async {
    final inrAcct = await db.addAccount(
      name: 'INR wallet',
      type: AccountType.cash,
      colorValue: 0xFF000000,
      iconKey: 'cash',
      openingBalance: const Money(1000000), // ₹10,000.00
    );
    final usdAcct = await db.addAccount(
      name: 'USD wallet',
      type: AccountType.cash,
      colorValue: 0xFF000000,
      iconKey: 'cash',
      openingBalance: const Money.zero(),
      currencyCode: 'USD',
    );
    await db.addCurrencyRate(
      currencyCode: 'USD',
      rateToBaseMicros: 83000000, // 1 USD = 83 INR
      effectiveAt: DateTime(2026, 1, 1),
    );

    await db.addTransaction(
      type: TxType.transfer,
      amount: const Money(830000), // ₹8300.00 leaves the INR wallet
      accountId: inrAcct,
      toAccountId: usdAcct,
      date: DateTime(2026, 2, 1),
    );

    final inrRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(inrAcct))).getSingle();
    final usdRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(usdAcct))).getSingle();

    expect(inrRow.currentBalance, const Money(170000)); // ₹1700.00 left
    expect(usdRow.currentBalance, const Money(10000)); // $100.00 credited
  });

  test('recalculateBalances rebuilds a cross-currency transfer identically',
      () async {
    final inrAcct = await db.addAccount(
      name: 'INR wallet',
      type: AccountType.cash,
      colorValue: 0xFF000000,
      iconKey: 'cash',
      openingBalance: const Money(1000000),
    );
    final usdAcct = await db.addAccount(
      name: 'USD wallet',
      type: AccountType.cash,
      colorValue: 0xFF000000,
      iconKey: 'cash',
      openingBalance: const Money.zero(),
      currencyCode: 'USD',
    );
    await db.addCurrencyRate(
      currencyCode: 'USD',
      rateToBaseMicros: 83000000,
      effectiveAt: DateTime(2026, 1, 1),
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: const Money(830000),
      accountId: inrAcct,
      toAccountId: usdAcct,
      date: DateTime(2026, 2, 1),
    );

    await db.recalculateBalances();

    final usdRow = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(usdAcct))).getSingle();
    expect(usdRow.currentBalance, const Money(10000));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/cross_currency_balance_test.dart`
Expected: FAIL — `usdRow.currentBalance` comes back as `830000` (wrongly
credited the raw source amount) instead of `10000`.

- [ ] **Step 3: Fix `_applyTxEffect` and `recalculateBalances`**

In `_applyTxEffect` (`database.dart:834-851`), change the `transfer` case:

```dart
      case TxType.transfer:
        await _adjust(t.accountId, -amt);
        final creditAmt =
            t.toAmount == null ? amt : Money(t.toAmount!.paise * sign);
        await _adjust(t.toAccountId!, creditAmt);
```

In `recalculateBalances` (`database.dart:2061-2099`), change the `transfer`
case inside the `for (final t in await select(transactions).get())` loop:

```dart
          case TxType.transfer:
            bump(t.accountId, -t.amount);
            bump(t.toAccountId!, t.toAmount ?? t.amount);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/cross_currency_balance_test.dart`
Expected: PASS

- [ ] **Step 5: Full-suite check, then commit**

Run: `flutter test`
Expected: PASS — every existing same-currency transfer has `toAmount ==
null`, so `t.toAmount ?? t.amount` and the `creditAmt` fallback both
degrade to exactly today's behavior.

```bash
git add lib/data/database.dart test/cross_currency_balance_test.dart
git commit -m "fix: credit a cross-currency transfer's destination in its own currency"
```

---

### Task 7: Currency-aware Net Worth

**Files:**
- Modify: `lib/data/database.dart:2122-2126` (`watchNetWorth`)
- Test: `test/net_worth_currency_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('sums a mixed-currency set of accounts using the live rate', () async {
    await db.addAccount(
      name: 'INR wallet',
      type: AccountType.cash,
      colorValue: 0xFF000000,
      iconKey: 'cash',
      openingBalance: const Money(1000000), // ₹10,000.00
    );
    await db.addAccount(
      name: 'USD wallet',
      type: AccountType.cash,
      colorValue: 0xFF000000,
      iconKey: 'cash',
      openingBalance: const Money(10000), // $100.00
      currencyCode: 'USD',
    );
    await db.addCurrencyRate(
      currencyCode: 'USD',
      rateToBaseMicros: 83000000, // 1 USD = 83 INR
      effectiveAt: DateTime(2020, 1, 1),
    );

    final netWorth = await db.watchNetWorth().first;
    // ₹10,000.00 + ($100.00 -> ₹8,300.00) = ₹18,300.00
    expect(netWorth, const Money(1830000));
  });

  test('a foreign account with no rate yet contributes its raw balance '
      'unconverted, rather than breaking the stream', () async {
    await db.addAccount(
      name: 'USD wallet',
      type: AccountType.cash,
      colorValue: 0xFF000000,
      iconKey: 'cash',
      openingBalance: const Money(10000),
      currencyCode: 'USD',
    );

    final netWorth = await db.watchNetWorth().first;
    expect(netWorth, const Money(10000));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/net_worth_currency_test.dart`
Expected: FAIL — the first test expects `1830000` but today's plain `+`
fold produces `1010000` (₹10,000 + a raw `10000` treated as rupees, i.e.
$100 misread as ₹100).

- [ ] **Step 3: Implement**

Replace `watchNetWorth` (`database.dart:2122-2126`):

```dart
  /// Total money = Cash + Bank + Credit Card. Instruments never double-count.
  /// An account with [Accounts.includeInNetWorth] off — opted out from
  /// Settings > Customize Dashboard — contributes nothing here, though it
  /// still shows its own balance everywhere else in the app.
  ///
  /// A foreign-currency account's balance is converted using **today's**
  /// rate, not a snapshot — Net Worth is a "right now" figure, unlike a
  /// transaction's historical [TransactionBaseValue.baseAmount]. If no rate
  /// has been entered for its currency yet, its raw balance is added
  /// unconverted rather than dropping it or throwing, so an incomplete
  /// Currency setup never breaks the dashboard.
  Stream<Money> watchNetWorth() => watchBalanceHoldingAccounts().asyncMap((
    rows,
  ) async {
    var total = const Money.zero();
    for (final a in rows) {
      if (!a.includeInNetWorth) continue;
      if (a.currencyCode == null) {
        total += a.currentBalance;
        continue;
      }
      final rate = await latestRate(a.currencyCode!);
      total += rate == null
          ? a.currentBalance
          : convertUsingRate(a.currentBalance, rate.rateToBaseMicros);
    }
    return total;
  });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/net_worth_currency_test.dart`
Expected: PASS

- [ ] **Step 5: Full-suite check, then commit**

Run: `flutter test`
Expected: PASS — every existing account has `currencyCode == null`, so the
new method takes the unconverted `continue` branch for all of them,
identical to today's `+` fold.

```bash
git add lib/data/database.dart test/net_worth_currency_test.dart
git commit -m "feat: convert foreign-currency balances into Net Worth at the live rate"
```

---

### Task 8: `MoneyFormat.symbolIn` — format an amount in an explicit currency

**Files:**
- Modify: `lib/core/money.dart`
- Test: `test/currency_test.dart` (add to the existing `MoneyFormat.configure` group)

- [ ] **Step 1: Write the failing test**

Add to `test/currency_test.dart`, inside the existing `group('MoneyFormat.configure', ...)` block (`currency_test.dart:34-84`):

```dart
    test('symbolIn formats against an explicit currency, ignoring the '
        'globally configured one', () {
      MoneyFormat.configure(
        currency: currencyForCode('INR'),
        showSymbol: true,
      );
      final out = MoneyFormat.symbolIn(const Money(125050), currencyForCode('USD'));
      expect(out, contains(r'$'));
      expect(out, contains('1,250.50'));
      expect(out, isNot(contains('₹')));
    });

    test('symbolIn respects a zero-decimal currency', () {
      final out = MoneyFormat.symbolIn(
        const Money(125000),
        currencyForCode('JPY'),
      );
      expect(out, contains('¥'));
      expect(out, isNot(contains('.00')));
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/currency_test.dart`
Expected: FAIL — `symbolIn` is not a member of `MoneyFormat`.

- [ ] **Step 3: Implement**

In `lib/core/money.dart`, add a new static method to `MoneyFormat` right
after `symbol` (`money.dart:118-120`):

```dart
  /// Formats [m] against an explicit [currency], ignoring whatever
  /// [MoneyFormat] is globally configured to. For rendering one specific
  /// account's or transaction's own (possibly foreign) amount — every
  /// aggregate total (Dashboard, Net Worth, Reports, Budgets) stays on
  /// [symbol] as before, since those are always parent-currency figures.
  /// Not cached like [_withSymbol] — this path is only ever used per-row,
  /// not hot enough to need it.
  static String symbolIn(Money m, Currency currency) {
    if (!_showSymbol) return _buildBare(currency).format(m.rupees);
    return _buildWithSymbol(currency).format(m.rupees);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/currency_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/money.dart test/currency_test.dart
git commit -m "feat: add MoneyFormat.symbolIn to render an explicit currency"
```

---

### Task 9: `MoneyText`/`BalanceText`/`AnimatedBalanceText` gain an optional `currency`

**Files:**
- Modify: `lib/core/widgets/money_text.dart:124-219`
- Test: `test/money_text_currency_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/currency.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/widgets/money_text.dart';

void main() {
  tearDown(() => MoneyFormat.configure(
        currency: kDefaultCurrency,
        showSymbol: true,
      ));

  testWidgets('an explicit currency overrides the globally configured one',
      (tester) async {
    MoneyFormat.configure(currency: currencyForCode('INR'), showSymbol: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoneyText(
            const Money(125050),
            currency: currencyForCode('USD'),
          ),
        ),
      ),
    );

    expect(find.textContaining(r'$'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('omitting currency keeps using the global MoneyFormat, unchanged',
      (tester) async {
    MoneyFormat.configure(currency: currencyForCode('INR'), showSymbol: true);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MoneyText(Money(125050))),
      ),
    );

    expect(find.textContaining('₹'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/money_text_currency_test.dart`
Expected: FAIL — `MoneyText` has no `currency` parameter.

- [ ] **Step 3: Implement**

In `lib/core/widgets/money_text.dart`, update `MoneyText`
(`money_text.dart:124-171`):

```dart
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    this.style,
    this.color,
    this.signed = false,
    this.compact = false,
    this.currency,
    super.key,
  });

  final Money amount;
  final TextStyle? style;
  final Color? color;

  /// Prefix `+`/`-`. Use on ledger rows, not on balances.
  final bool signed;
  final bool compact;

  /// Renders against this currency instead of the globally configured one —
  /// for a specific account's/transaction's own (possibly foreign) amount.
  /// Null (the default) renders exactly as before, via [MoneyFormat].
  final Currency? currency;

  /// A fixed-width placeholder — never derived from the real digits, so the
  /// mask can't leak the amount's order of magnitude (a 3-digit vs 7-digit
  /// figure would otherwise be visibly distinguishable even hidden).
  static const _maskGlyph = '••••••';

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the currency setting changes — [MoneyFormat] is already
    // reconfigured by then, so the new symbol/grouping lands immediately.
    // Irrelevant when [currency] is set explicitly, but depending
    // unconditionally keeps this widget's rebuild behavior simple.
    CurrencyScope.depend(context);
    final hidden = AmountVisibilityScope.of(context);
    final displayCurrency = currency ?? MoneyFormat.currency;
    final text = hidden
        ? (MoneyFormat.showSymbol
            ? '${displayCurrency.symbol} $_maskGlyph'
            : _maskGlyph)
        : compact
            ? MoneyFormat.compact(amount)
            : signed
                ? _signedIn(amount, currency)
                : currency == null
                    ? MoneyFormat.symbol(amount)
                    : MoneyFormat.symbolIn(amount, currency!);

    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.bodyLarge)?.copyWith(
        color: color,
        fontFeatures: kTabularFigures,
      ),
    );
  }

  static String _signedIn(Money m, Currency? currency) {
    if (currency == null) return MoneyFormat.signed(m);
    final sign = m.isNegative ? '-' : '+';
    return '$sign${MoneyFormat.symbolIn(m.abs, currency)}';
  }
}
```

Update `BalanceText` and `AnimatedBalanceText` (`money_text.dart:174-219`)
to accept and forward the same parameter:

```dart
class BalanceText extends StatelessWidget {
  const BalanceText(this.amount, {this.style, this.currency, super.key});

  final Money amount;
  final TextStyle? style;
  final Currency? currency;

  @override
  Widget build(BuildContext context) {
    return MoneyText(
      amount,
      style: style,
      currency: currency,
      color: amount.isNegative ? AppColors.expense : null,
    );
  }
}

/// A [BalanceText] that counts to its value instead of snapping to it — and
/// counts *from* the old value whenever the balance changes.
///
/// Reserve this for a single hero figure. Numbers that sit in a list or a
/// column must not move, or the whole screen twitches on every ledger write.
class AnimatedBalanceText extends StatelessWidget {
  const AnimatedBalanceText(
    this.amount, {
    this.style,
    this.currency,
    this.duration = const Duration(milliseconds: 650),
    super.key,
  });

  final Money amount;
  final TextStyle? style;
  final Currency? currency;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return BalanceText(amount, style: style, currency: currency);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: amount.paise),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, paise, _) =>
          BalanceText(Money(paise), style: style, currency: currency),
    );
  }
}
```

`money_text.dart` already imports `../currency.dart` (`money_text.dart:6`),
so `Currency` is already in scope — no new import needed.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/money_text_currency_test.dart`
Expected: PASS

- [ ] **Step 5: Full-suite check, then commit**

Run: `flutter test`
Expected: PASS — `currency` defaults to `null` everywhere it isn't passed,
so every existing call site (there are dozens across the app) renders
identically to before.

```bash
git add lib/core/widgets/money_text.dart test/money_text_currency_test.dart
git commit -m "feat: let MoneyText/BalanceText/AnimatedBalanceText render an explicit currency"
```

---

## Self-review notes (for whoever executes this plan)

- **Spec coverage:** This plan implements the "Data model" and "Migration"
  sections of the design spec in full, plus the `MoneyFormat`/`MoneyText`
  half of the "Rendering change" section, plus the Net Worth conversion
  described under "Balances, Net Worth, Reports, Budgets". It deliberately
  does **not** implement: the Currency settings screen, account/transaction/
  transfer UI, `watchSpendByCategory`/Reports conversion, or
  backup/PDF-statement handling — those are Plans 2–4.
- **`TransactionRow` constructor shape (Task 2):** the exact generated
  constructor signature for `TransactionRow` may not match this plan's
  guess field-for-field once `database.g.dart` is regenerated in Task 1 —
  the step's note says explicitly to check the generated file and adjust.
  Don't skip that check.
- **Do not implement Plans 2–4 tasks from this document** — they don't
  exist here on purpose; see the "Relationship to other plans" note at the
  top.
