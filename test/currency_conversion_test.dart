import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/currency_conversion.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

void main() {
  group('convertUsingRate', () {
    test('1 USD = 83.12 INR converts \$10.00 to ₹831.20', () {
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
        currencyCode: 'USD',
        fxRateToBaseMicros: 83120000,
      );
      expect(row.baseAmount, const Money(83120)); // ₹831.20
    });
  });
}
