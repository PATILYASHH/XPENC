import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
