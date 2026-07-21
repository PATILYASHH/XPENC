import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/currency.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';

/// Multi-currency (issue #6): amounts can render in any currency, and the
/// symbol can be hidden entirely for a currency we don't carry.
void main() {
  // MoneyFormat is a global; leave it as the app expects it after each test.
  tearDown(() => MoneyFormat.configure(
        currency: kDefaultCurrency,
        showSymbol: true,
      ));

  group('registry', () {
    test('carries Bangladeshi Taka with its symbol', () {
      final bdt = currencyForCode('BDT');
      expect(bdt.code, 'BDT');
      expect(bdt.symbol, '৳');
    });

    test('an unknown or null code degrades to the default', () {
      expect(currencyForCode('ZZZ').code, kDefaultCurrency.code);
      expect(currencyForCode(null).code, kDefaultCurrency.code);
    });

    test('every currency has a unique code', () {
      final codes = kCurrencies.map((c) => c.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
    });
  });

  group('MoneyFormat.configure', () {
    test('renders the chosen currency symbol', () {
      MoneyFormat.configure(
        currency: currencyForCode('USD'),
        showSymbol: true,
      );
      final out = MoneyFormat.symbol(const Money(125050));
      expect(out, contains(r'$'));
      expect(out, contains('1,250.50'));
    });

    test('hiding the symbol leaves a bare number', () {
      MoneyFormat.configure(
        currency: currencyForCode('USD'),
        showSymbol: false,
      );
      final out = MoneyFormat.symbol(const Money(125050));
      expect(out, isNot(contains(r'$')));
      expect(out, contains('1,250.50'));
    });

    test('a zero-decimal currency shows no fraction', () {
      MoneyFormat.configure(
        currency: currencyForCode('JPY'),
        showSymbol: true,
      );
      final out = MoneyFormat.symbol(const Money(125000)); // ¥1,250
      expect(out, contains('¥'));
      expect(out, contains('1,250'));
      expect(out, isNot(contains('.00')));
    });

    test('groups in lakhs for INR, thousands for others', () {
      // ₹1,00,000.00
      MoneyFormat.configure(currency: currencyForCode('INR'), showSymbol: true);
      expect(MoneyFormat.symbol(const Money(10000000)), contains('1,00,000'));

      // $100,000.00
      MoneyFormat.configure(currency: currencyForCode('USD'), showSymbol: true);
      expect(MoneyFormat.symbol(const Money(10000000)), contains('100,000'));
    });

    test('signed still respects the hidden symbol', () {
      MoneyFormat.configure(
        currency: currencyForCode('USD'),
        showSymbol: false,
      );
      expect(MoneyFormat.signed(const Money(50000)), startsWith('+'));
      expect(MoneyFormat.signed(const Money(50000)), isNot(contains(r'$')));
    });
  });

  group('settings persistence', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('defaults to INR with the symbol shown', () async {
      final s = await db.getSettings();
      expect(s.currencyCode, 'INR');
      expect(s.showCurrencySymbol, isTrue);
    });

    test('persists the chosen currency and symbol toggle', () async {
      await db.setCurrencyCode('BDT');
      await db.setShowCurrencySymbol(false);
      final s = await db.getSettings();
      expect(s.currencyCode, 'BDT');
      expect(s.showCurrencySymbol, isFalse);
    });
  });
}
