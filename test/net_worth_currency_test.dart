import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

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
