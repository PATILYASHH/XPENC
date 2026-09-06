import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

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
