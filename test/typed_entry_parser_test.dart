import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/voice/voice_parser.dart';
import 'package:xpenc/data/tables.dart';

/// "Type it" (GitHub #213): a few typed words — "34 supermarket" — read
/// into an entry, with the person's own category keywords deciding where it
/// goes. Same reader as voice add, in its keyboard mode.
void main() {
  final now = DateTime(2026, 11, 26, 10);
  const cats = <VoiceCategory>[
    (id: 1, name: 'Food', income: false),
    (id: 2, name: 'Groceries', income: false),
    (id: 3, name: 'Transport', income: false),
    (id: 20, name: 'Salary', income: true),
    (id: 21, name: 'Profit', income: true),
  ];
  const keywords = <EntryKeyword>[
    (word: 'supermarket', categoryId: 1),
    (word: 'market', categoryId: 1),
    (word: 'super market', categoryId: 2),
    (word: 'freelance', categoryId: 21),
    (word: 'archived thing', categoryId: 99), // its category is gone
  ];
  const accounts = <EntryAccount>[
    (id: 100, name: 'Cash'),
    (id: 101, name: 'HDFC'),
    (id: 102, name: 'Food card'),
  ];

  VoiceDraft t(String s) => parseVoiceEntry(
    s,
    categories: cats,
    now: now,
    keywords: keywords,
    accounts: accounts,
    typed: true,
  );
  Money m(num v) => Money((v * 100).round());

  group('the example from the issue', () {
    test('"34 supermarket" is 34 out, filed under Food', () {
      final d = t('34 supermarket');
      expect(d.amount, m(34));
      expect(d.type, TxType.expense);
      expect(d.categoryId, 1);
      expect(d.accountId, isNull);
    });

    test('word order and case do not matter', () {
      expect(t('Supermarket 34').categoryId, 1);
      expect(t('SUPERMARKET 34').amount, m(34));
    });

    test('a plural of a keyword still matches', () {
      expect(t('12 markets').categoryId, 1);
    });

    test('the longest keyword wins', () {
      expect(t('34 super market').categoryId, 2);
    });
  });

  group('typed amounts', () {
    test('a decimal comma is cents, not thousands', () {
      expect(t('12,50 supermarket').amount, m(12.5));
      expect(t('12,5 market').amount, m(12.5));
      expect(t('1.234,56 market').amount, m(1234.56));
    });

    test('a grouping comma is still thousands', () {
      expect(t('1,250 market').amount, m(1250));
      expect(t('1,25,000 market').amount, m(125000));
      expect(t('99.50 market').amount, m(99.5));
    });

    test('any currency sign marks the amount, on either side', () {
      expect(t('34\$ supermarket').amount, m(34));
      expect(t('€12,50 market').amount, m(12.5));
      expect(t('£7 market').amount, m(7));
      expect(t('market ₹120').amount, m(120));
    });

    test('k and lakh still work', () {
      expect(t('2.5k market').amount, m(2500));
    });

    test('no number, no amount', () {
      expect(t('supermarket').amount, isNull);
    });
  });

  group('money in or out', () {
    test("a keyword's category decides when nothing else says", () {
      final d = t('5000 freelance');
      expect(d.type, TxType.income);
      expect(d.categoryId, 21);
    });

    test('a leading + is money in, - is money out', () {
      expect(t('+500 freelance').type, TxType.income);
      expect(t('-500 freelance').type, TxType.expense);
      expect(t('-500 freelance').categoryId, isNull);
    });

    test('a word that says which way beats the keyword', () {
      final d = t('received 34 supermarket');
      expect(d.type, TxType.income);
      expect(d.categoryId, isNull);
      expect(t('paid 34 supermarket').categoryId, 1);
    });

    test('category names and built-in hints still work without keywords', () {
      expect(t('40 transport').categoryId, 3);
      expect(t('250 taxi').categoryId, 3);
      expect(t('got salary 50000').type, TxType.income);
    });

    test('a keyword for a category that is gone is ignored', () {
      expect(t('34 archived thing').categoryId, isNull);
    });
  });

  group('accounts', () {
    test('an account named in the words is picked, and left out of the note',
        () {
      final d = t('34 lunch hdfc');
      expect(d.accountId, 101);
      expect(d.categoryId, 1);
      expect(d.note, 'Lunch');
    });

    test("an account's name never reads as a category", () {
      final d = t('34 groceries food card');
      expect(d.accountId, 102);
      expect(d.categoryId, 2);
    });
  });

  test('voice add, without the keyboard mode, reads as before', () {
    final d = parseVoiceEntry(
      'paid 1,250 for groceries',
      categories: cats,
      now: now,
    );
    expect(d.amount, m(1250));
    expect(d.categoryId, 2);
    expect(d.accountId, isNull);
  });
}
