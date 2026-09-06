import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

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
