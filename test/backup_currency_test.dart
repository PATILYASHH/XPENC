import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// CurrencyRates is a brand-new table (not present when exportAll/importAll
/// were first written) — this guards it actually rides along in a backup,
/// same as every other table.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<({int inrAccount, int usdAccount, int txId})> seedCurrencyData() async {
    final inrAccount = (await db.watchAccounts().first).first.id;
    final usdAccount = await db.addAccount(
      name: 'Travel',
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
    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: const Money(1000),
      accountId: usdAccount,
      date: DateTime(2026, 2, 1),
    );
    return (inrAccount: inrAccount, usdAccount: usdAccount, txId: txId);
  }

  test('exportAll includes currencyRates and the new account/transaction '
      'currency columns', () async {
    await seedCurrencyData();

    final dump = await db.exportAll();

    expect(dump['currencyRates'], isA<List>());
    expect((dump['currencyRates'] as List), hasLength(1));
    final rateRow = (dump['currencyRates'] as List).first as Map;
    expect(rateRow['currency_code'], 'USD');
    expect(rateRow['rate_to_base_micros'], 83000000);

    final accountRows = dump['accounts'] as List;
    final usdAccountRow = accountRows
        .cast<Map>()
        .firstWhere((a) => a['currency_code'] == 'USD');
    expect(usdAccountRow, isNotNull);

    final txRows = dump['transactions'] as List;
    final usdTxRow = txRows
        .cast<Map>()
        .firstWhere((t) => t['currency_code'] == 'USD');
    expect(usdTxRow['fx_rate_to_base_micros'], 83000000);
  });

  test('a fresh database restores currencyRates and the currency columns '
      'from a backup', () async {
    final seeded = await seedCurrencyData();
    final dump =
        jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await fresh.importAll(dump);

    final rate = await fresh.latestRate('USD');
    expect(rate, isNotNull);
    expect(rate!.rateToBaseMicros, 83000000);

    final usdAccount = await (fresh.select(
      fresh.accounts,
    )..where((a) => a.id.equals(seeded.usdAccount))).getSingle();
    expect(usdAccount.currencyCode, 'USD');

    final tx = await (fresh.select(
      fresh.transactions,
    )..where((t) => t.id.equals(seeded.txId))).getSingle();
    expect(tx.currencyCode, 'USD');
    expect(tx.fxRateToBaseMicros, 83000000);
  });

  test('clearAllData wipes currencyRates along with everything else', () async {
    await seedCurrencyData();
    await db.clearAllData();

    final rates = await db.watchCurrentRates().first;
    expect(rates, isEmpty);
  });
}
