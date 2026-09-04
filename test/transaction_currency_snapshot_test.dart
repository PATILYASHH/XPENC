import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

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
