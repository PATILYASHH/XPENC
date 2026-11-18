import 'package:csv/csv.dart';
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

    test('finds a Category column', () {
      final mapping = guessMapping([
        'Date',
        'Description',
        'Amount',
        'Category',
      ]);
      expect(mapping, isNotNull);
      expect(mapping!.categoryColumn, 3);
    });

    test(
      'leaves categoryColumn null when there is no category-shaped column',
      () {
        final mapping = guessMapping(['Date', 'Description', 'Amount']);
        expect(mapping, isNotNull);
        expect(mapping!.categoryColumn, isNull);
      },
    );
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

    test('parses middle-European dd.MM.yyyy (GitHub #206)', () {
      expect(parseCsvDate('16.11.2026'), DateTime(2026, 11, 16));
    });

    test('parses single-digit d.M.yyyy and two-digit dd.MM.yy', () {
      expect(parseCsvDate('1.2.2026'), DateTime(2026, 2, 1));
      expect(parseCsvDate('16.11.26'), DateTime(2026, 11, 16));
    });

    test('still parses dd-MM-yyyy from the #207 file', () {
      expect(parseCsvDate('16-11-2026'), DateTime(2026, 11, 16));
    });

    test('rejects an impossible dot date', () {
      expect(parseCsvDate('32.13.2026'), isNull);
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

  group('parseCsvRow — category column', () {
    const mapping = CsvColumnMapping(
      dateColumn: 0,
      noteColumn: 1,
      categoryColumn: 3,
      amountColumn: 2,
    );

    test('reads the category text alongside the other fields', () {
      final row = parseCsvRow([
        '09/07/2026',
        'Swiggy',
        '-500.00',
        'Food',
      ], mapping);
      expect(row.category, 'Food');
    });

    test('a blank category cell parses as null', () {
      final row = parseCsvRow(['09/07/2026', 'Swiggy', '-500.00', ''], mapping);
      expect(row.category, isNull);
    });
  });

  group('parseCsvAmount', () {
    const comma = CsvDecimalSeparator.comma;

    test('a decimal comma reads as cents, not thousands (GitHub #207)', () {
      expect(parseCsvAmount('-2,10', decimal: comma), Money.fromRupees(-2.10));
    });

    test('European thousands dots are dropped', () {
      expect(
        parseCsvAmount('1.234.567,89', decimal: comma),
        Money.fromRupees(1234567.89),
      );
      expect(parseCsvAmount('1.234', decimal: comma), Money.fromRupees(1234));
    });

    test('dot mode keeps the old behaviour, Indian grouping included', () {
      expect(parseCsvAmount('1,25,000.50'), Money.fromRupees(125000.50));
      expect(parseCsvAmount('-500.00'), Money.fromRupees(-500));
    });

    test('ignores currency symbols and codes', () {
      expect(
        parseCsvAmount('€ -2,10 EUR', decimal: comma),
        Money.fromRupees(-2.10),
      );
      expect(parseCsvAmount('₹1,250.50'), Money.fromRupees(1250.50));
    });

    test('returns null for text with no number', () {
      expect(parseCsvAmount('n/a'), isNull);
      expect(parseCsvAmount('', decimal: comma), isNull);
    });
  });

  group('detectDecimalSeparator', () {
    test('a decimal comma file is detected (GitHub #207)', () {
      expect(
        detectDecimalSeparator(['-2,10', '15,00', '-1.234,56']),
        CsvDecimalSeparator.comma,
      );
    });

    test('repeated dots mean European grouping', () {
      expect(detectDecimalSeparator(['1.234.567']), CsvDecimalSeparator.comma);
    });

    test('Indian / US files stay on dot', () {
      expect(
        detectDecimalSeparator(['1,25,000.00', '-500.00', '2,000']),
        CsvDecimalSeparator.dot,
      );
    });

    test('whole numbers or ambiguous cells keep the dot default', () {
      expect(detectDecimalSeparator(['500', '-20']), CsvDecimalSeparator.dot);
      expect(detectDecimalSeparator(['1.234']), CsvDecimalSeparator.dot);
      expect(detectDecimalSeparator(const []), CsvDecimalSeparator.dot);
    });

    test('the majority wins over a stray odd cell', () {
      expect(
        detectDecimalSeparator(['-2,10', '3,50', '7.5']),
        CsvDecimalSeparator.comma,
      );
    });

    test('reads only the mapped amount columns', () {
      const mapping = CsvColumnMapping(dateColumn: 0, debitColumn: 2);
      expect(
        detectDecimalSeparatorForRows([
          ['16.11.2026', '1,000.00 note', '12,50'],
          ['17.11.2026', '9.99 again', '3,10'],
        ], mapping),
        CsvDecimalSeparator.comma,
      );
    });
  });

  group('parseCsvRow — European file (GitHub #206, #207)', () {
    test('the exact #207 file imports as 2.10, not 210', () {
      // Verbatim from the issue: semicolon-delimited, decimal comma.
      final decoded = Csv().decode('date; Amount;\n16-11-2026;-2,10;EUR\n');
      final headers = decoded.first;
      final rows = decoded.skip(1).toList();
      final guess = guessMapping(headers)!;
      final mapping = CsvColumnMapping(
        dateColumn: guess.dateColumn,
        amountColumn: guess.amountColumn,
        decimalSeparator: detectDecimalSeparatorForRows(rows, guess),
      );
      expect(mapping.decimalSeparator, CsvDecimalSeparator.comma);
      final row = parseCsvRow(rows.single, mapping);
      expect(row.date, DateTime(2026, 11, 16));
      expect(row.amount, Money.fromRupees(-2.10));
    });

    test('dot dates and comma amounts together', () {
      const mapping = CsvColumnMapping(
        dateColumn: 0,
        noteColumn: 1,
        amountColumn: 2,
        decimalSeparator: CsvDecimalSeparator.comma,
      );
      final row = parseCsvRow(['16.11.2026', 'REWE', '-1.234,56'], mapping);
      expect(row.date, DateTime(2026, 11, 16));
      expect(row.amount, Money.fromRupees(-1234.56));
    });
  });
}
