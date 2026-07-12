import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';

void main() {
  group('Money', () {
    test('stores paise as integers', () {
      expect(const Money(1250).rupees, 12.50);
      expect(Money.fromRupees(12.5).paise, 1250);
    });

    test('rounds to nearest paisa instead of drifting', () {
      // 0.1 + 0.2 != 0.3 in floating point. Integer paise must not care.
      final a = Money.fromRupees(0.1);
      final b = Money.fromRupees(0.2);
      expect((a + b).paise, 30);
      expect(a + b, Money.fromRupees(0.3));
    });

    test('arithmetic stays exact across many additions', () {
      var total = const Money.zero();
      for (var i = 0; i < 1000; i++) {
        total = total + Money.fromRupees(0.01);
      }
      expect(total.paise, 1000);
      expect(total.rupees, 10.0);
    });

    test('tryParse handles symbols, separators and junk', () {
      expect(Money.tryParse('1,250.50')?.paise, 125050);
      expect(Money.tryParse('₹1250')?.paise, 125000);
      expect(Money.tryParse('  99 ')?.paise, 9900);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse(''), isNull);
    });

    test('comparison, negation and abs', () {
      expect(const Money(100) > const Money(50), isTrue);
      expect(-const Money(100), const Money(-100));
      expect(const Money(-100).abs, const Money(100));
      expect(const Money(-1).isNegative, isTrue);
      expect(const Money.zero().isZero, isTrue);
    });
  });

  group('MoneyFormat', () {
    test('formats with the rupee symbol', () {
      expect(MoneyFormat.symbol(const Money(125050)), contains('1,250.50'));
    });

    test('signed prefixes direction', () {
      expect(MoneyFormat.signed(const Money(50000)), startsWith('+'));
      expect(MoneyFormat.signed(const Money(-50000)), startsWith('-'));
    });
  });
}
