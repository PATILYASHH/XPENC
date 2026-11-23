import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/voice/voice_parser.dart';
import 'package:xpenc/data/tables.dart';

/// Voice add's sentence reader: no AI, just word lists — so every phrasing
/// it's meant to handle is pinned here.
void main() {
  final now = DateTime(2026, 11, 23, 10);
  const cats = <VoiceCategory>[
    (id: 1, name: 'Food', income: false),
    (id: 2, name: 'Groceries', income: false),
    (id: 3, name: 'Transport', income: false),
    (id: 4, name: 'Bills', income: false),
    (id: 5, name: 'Shopping', income: false),
    (id: 6, name: 'Health', income: false),
    (id: 7, name: 'Rent', income: false),
    (id: 8, name: 'Eating out', income: false),
    (id: 20, name: 'Salary', income: true),
    (id: 21, name: 'Refund', income: true),
    (id: 22, name: 'Gift', income: true),
  ];

  VoiceDraft p(String s) => parseVoiceEntry(s, categories: cats, now: now);
  Money rs(num r) => Money((r * 100).round());

  group('amount', () {
    test('digits with a currency word', () {
      expect(p('I took a taxi for 250 rupees').amount, rs(250));
      expect(p('paid rs 99 for chai').amount, rs(99));
      expect(p('₹1,250 on groceries').amount, rs(1250));
      expect(p('Rs. 40 metro').amount, rs(40));
    });

    test('Indian grouping, decimals and k/lakh', () {
      expect(p('rent 1,50,000').amount, rs(150000));
      expect(p('bought shoes for 2.5k').amount, rs(2500));
      expect(p('received 1.5 lakh bonus').amount, rs(150000));
      expect(p('spent 99.50 on coffee').amount, rs(99.5));
    });

    test('spoken numbers', () {
      expect(p('two hundred fifty rupees for lunch').amount, rs(250));
      expect(p('two hundred and fifty rupees taxi').amount, rs(250));
      expect(p('five thousand rent').amount, rs(5000));
      expect(p('two fifty for auto').amount, rs(250));
      expect(p('a hundred rupees chai').amount, rs(100));
      expect(p('fifty rupees milk').amount, rs(50));
    });

    test('Hinglish numbers', () {
      expect(p('do sau rupaye ka petrol').amount, rs(200));
      expect(p('paanch hazaar kiraya diya').amount, rs(5000));
    });

    test('prefers the number next to a currency word, skips times', () {
      expect(p('at 5 pm paid 300 rupees for dinner').amount, rs(300));
      expect(p('2 coffees for 180 rupees').amount, rs(180));
    });

    test('none when nothing is a number', () {
      expect(p('bought some milk').amount, isNull);
    });
  });

  group('type', () {
    test('money out by default and for spend words', () {
      expect(p('taxi 250').type, TxType.expense);
      expect(p('bought milk for 50').type, TxType.expense);
      expect(p('sabzi kharidi 120 ki').type, TxType.expense);
    });

    test('money in for income words', () {
      expect(p('received salary 50000').type, TxType.income);
      expect(p('got 2000 from Rahul').type, TxType.income);
      expect(p('500 rupaye mile').type, TxType.income);
    });

    test('a spend word wins over a weak "got"', () {
      expect(p('got a taxi and paid 300').type, TxType.expense);
    });
  });

  group('category', () {
    test('by the category name itself', () {
      expect(p('food 200').categoryId, 1);
      expect(p('groceries 800').categoryId, 2);
      expect(p('eating out 900').categoryId, 8);
    });

    test('through everyday words', () {
      expect(p('I took a taxi for 50 rupees').categoryId, 3);
      expect(p('uber 340').categoryId, 3);
      expect(p('petrol 500').categoryId, 3);
      expect(p('swiggy 450').categoryId, 1);
      expect(p('sabzi 120').categoryId, 2);
      expect(p('electricity bill 1800').categoryId, 4);
      expect(p('medicine 300').categoryId, 6);
      expect(p('amazon order 1200').categoryId, 5);
    });

    test('only categories of the same kind', () {
      expect(p('received salary 50000').categoryId, 20);
      expect(p('got a refund of 300').categoryId, 21);
    });

    test('none when nothing fits', () {
      expect(p('paid 500').categoryId, isNull);
    });
  });

  group('payee, day and note', () {
    test('payee after "to" (out) or "from" (in)', () {
      expect(p('paid 500 to Ramesh for lunch').payee, 'Ramesh');
      expect(p('got 2000 from Rahul Sharma').payee, 'Rahul Sharma');
      expect(p('Ramesh ko 500 diye').payee, 'Ramesh');
    });

    test('yesterday and the day before', () {
      expect(p('yesterday taxi 200').date, DateTime(2026, 11, 22));
      expect(p('day before yesterday dinner 900').date, DateTime(2026, 11, 21));
      expect(p('today lunch 150').date, isNull);
    });

    test('the note is what is left', () {
      expect(p('I took a taxi for 50 rupees').note, 'Taxi');
      expect(p('bought milk and bread for 120').note, 'Milk and bread');
      expect(p('paid 500').note, isNull);
    });
  });
}
