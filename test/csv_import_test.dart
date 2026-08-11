import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/features/data_export/csv_import.dart';

/// GitHub #17: importing a bank-exported CSV statement. Two shapes cover
/// most Indian bank exports — a single signed Amount column, or separate
/// Withdrawal/Deposit columns — and `guessMapping` should find either from
/// real header text without the user having to map anything by hand.
void main() {
  group('guessMapping', () {
    test('finds a single signed Amount column', () {
      final mapping = guessMapping(['Date', 'Description', 'Amount']);
      expect(mapping, isNotNull);
      expect(mapping!.dateColumn, 0);
      expect(mapping.noteColumn, 1);
      expect(mapping.amountColumn, 2);
      expect(mapping.isTwoColumn, isFalse);
    });

    test(
      'finds separate Withdrawal/Deposit columns (SBI/HDFC/ICICI shape)',
      () {
        final mapping = guessMapping([
          'Txn Date',
          'Narration',
          'Withdrawal Amt',
          'Deposit Amt',
          'Balance',
        ]);
        expect(mapping, isNotNull);
        expect(mapping!.debitColumn, 2);
        expect(mapping.creditColumn, 3);
        expect(mapping.isTwoColumn, isTrue);
      },
    );

    test('matches header names case-insensitively', () {
      final mapping = guessMapping(['DATE', 'notes', 'AMOUNT']);
      expect(mapping, isNotNull);
    });

    test('returns null with no recognisable date column', () {
      expect(guessMapping(['Foo', 'Bar', 'Amount']), isNull);
    });

    test('returns null with a date but no amount-shaped column at all', () {
      expect(guessMapping(['Date', 'Description']), isNull);
    });
  });

  group('parseCsvDate', () {
    test('parses dd/MM/yyyy', () {
      expect(parseCsvDate('09/07/2026'), DateTime(2026, 7, 9));
    });

    test('parses dd-MM-yy', () {
      expect(parseCsvDate('09-07-26'), DateTime(2026, 7, 9));
    });

    test('parses yyyy-MM-dd', () {
      expect(parseCsvDate('2026-07-09'), DateTime(2026, 7, 9));
    });

    test('parses "09 Jul 2026"', () {
      expect(parseCsvDate('09 Jul 2026'), DateTime(2026, 7, 9));
    });

    test('returns null for unparseable text', () {
      expect(parseCsvDate('not a date'), isNull);
    });

    test('does not misread a bare number as a date', () {
      expect(parseCsvDate('9'), isNull);
    });
  });

  group('parseCsvRow — single Amount column', () {
    const mapping = CsvColumnMapping(
      dateColumn: 0,
      noteColumn: 1,
      amountColumn: 2,
    );

    test('a negative amount parses as an expense (negative Money)', () {
      final row = parseCsvRow(['09/07/2026', 'Swiggy', '-500.00'], mapping);
      expect(row.date, DateTime(2026, 7, 9));
      expect(row.note, 'Swiggy');
      expect(row.amount, Money.fromRupees(-500));
      expect(row.amount!.isNegative, isTrue);
    });

    test('a positive amount parses as income', () {
      final row = parseCsvRow(['09/07/2026', 'Salary', '50000'], mapping);
      expect(row.amount, Money.fromRupees(50000));
      expect(row.amount!.isPositive, isTrue);
    });

    test('a zero amount row is skipped (null)', () {
      final row = parseCsvRow(['09/07/2026', 'Zero', '0'], mapping);
      expect(row.amount, isNull);
    });

    test('an unparseable date leaves date null without throwing', () {
      final row = parseCsvRow(['not a date', 'X', '10'], mapping);
      expect(row.date, isNull);
      expect(row.amount, Money.fromRupees(10));
    });
  });

  group('parseCsvRow — Withdrawal/Deposit columns', () {
    const mapping = CsvColumnMapping(
      dateColumn: 0,
      noteColumn: 1,
      debitColumn: 2,
      creditColumn: 3,
    );

    test('a withdrawal becomes a negative amount', () {
      final row = parseCsvRow(['09/07/2026', 'ATM', '2000', ''], mapping);
      expect(row.amount, Money.fromRupees(-2000));
    });

    test('a deposit becomes a positive amount', () {
      final row = parseCsvRow(['09/07/2026', 'Salary', '', '50000'], mapping);
      expect(row.amount, Money.fromRupees(50000));
    });

    test('both columns blank parses as no amount at all', () {
      final row = parseCsvRow([
        '09/07/2026',
        'Balance carried',
        '',
        '',
      ], mapping);
      expect(row.amount, isNull);
    });

    test('a stray currency symbol/comma in the cell is tolerated', () {
      final row = parseCsvRow(['09/07/2026', 'X', '', '₹1,250.50'], mapping);
      expect(row.amount, Money.fromRupees(1250.50));
    });
  });
}
