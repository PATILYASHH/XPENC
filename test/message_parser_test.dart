import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/parser/bank_message.dart';
import 'package:xpenc/features/message_capture/parser/message_parser.dart';

const parser = MessageParser();

ParseResult run(String body, {String sender = 'AD-IPPBNK'}) => parser.parse(
      RawMessage(body: body, sender: sender, receivedAt: DateTime(2026, 7, 9)),
    );

ParsedMessage ok(String body, {String sender = 'AD-IPPBNK'}) {
  final r = run(body, sender: sender);
  expect(r, isA<ParsedMessage>(), reason: 'expected a parse, got $r');
  return r as ParsedMessage;
}

RejectReason rejected(String body, {String sender = 'AD-IPPBNK'}) {
  final r = run(body, sender: sender);
  expect(r, isA<Rejected>(), reason: 'expected a reject, got $r');
  return (r as Rejected).reason;
}

void main() {
  group('IPPB — the bank we actually target', () {
    test('parses a UPI debit', () {
      final p = ok(
        'Rs.500.00 debited from A/c XXXX1234 on 05-07-26 to VPA ram@okaxis '
        '(UPI Ref no 123456789012). -India Post Payments Bank',
      );
      expect(p.amount, Money.fromRupees(500));
      expect(p.direction, TxDirection.debit);
      expect(p.accountHint, '1234');
      expect(p.merchant, 'ram@okaxis');
      expect(p.reference, '123456789012');
      expect(p.confidence, greaterThanOrEqualTo(kAutoApproveMinConfidence));
    });

    test('parses a credit with available balance', () {
      final p = ok(
        'Dear Customer, Rs 2,000.00 credited to your A/c XX1234 on 01-07-26. '
        'Avl Bal Rs 5,000.00 -IPPB',
      );
      expect(p.amount, Money.fromRupees(2000));
      expect(p.direction, TxDirection.credit);
      expect(p.availableBalance, Money.fromRupees(5000));
    });

    test('the balance is never mistaken for the transaction amount', () {
      final p = ok(
        'Rs.150.00 debited from A/c XX9876. Avl Bal Rs.12,345.67',
      );
      expect(p.amount, Money.fromRupees(150),
          reason: 'must pick the txn amount, not the balance');
      expect(p.availableBalance, Money.fromRupees(12345.67));
    });
  });

  group('noise must be discarded — booking these invents money', () {
    test('OTP', () {
      expect(rejected('123456 is your OTP for txn of Rs.500. Do not share.'),
          RejectReason.otp);
    });

    test('declined transaction never becomes an expense', () {
      expect(
        rejected('Your txn of Rs.2000 at AMAZON on A/c XX1234 was declined.'),
        RejectReason.declined,
      );
    });

    test('failed transaction', () {
      expect(
        rejected('Rs.999 debit from A/c XX1234 failed due to insufficient balance.'),
        RejectReason.declined,
      );
    });

    test('balance enquiry is not a transaction', () {
      expect(
        rejected('Your A/c XX1234 balance is Rs.5,000.00 as on 09-07-26.'),
        RejectReason.balanceOnly,
      );
    });

    test('promotional with an amount but no account', () {
      expect(
        rejected('Get a pre-approved loan offer of Rs.50,000! Click here. T&C apply'),
        RejectReason.promotional,
      );
    });

    test('message with no amount at all', () {
      expect(rejected('Your account statement is ready.'), RejectReason.noAmount);
    });
  });

  group('direction', () {
    test('refund is money IN, not an expense', () {
      final p = ok('Rs.300 refunded to your A/c XX1234 for order #A12.');
      expect(p.direction, TxDirection.credit);
    });

    test('reversal is money IN', () {
      final p = ok('Rs.750.00 reversed to A/c XX1234 on 08-07-26.');
      expect(p.direction, TxDirection.credit);
    });

    test('the first verb wins on mixed wording', () {
      final p = ok(
        'Rs.100.00 debited from A/c XX1234. Avl Bal Rs.400. Amount credited to merchant.',
      );
      expect(p.direction, TxDirection.debit);
    });

    test('withdrawal is a debit', () {
      final p = ok('Rs.2000 withdrawn from A/c XX1234 at ATM.');
      expect(p.direction, TxDirection.debit);
    });
  });

  group('amount formats', () {
    test('handles Rs. INR and the rupee glyph', () {
      expect(ok('Rs.1234.56 debited from A/c XX1111').amount,
          Money.fromRupees(1234.56));
      expect(ok('INR 1,00,000 credited to A/c XX1111').amount,
          Money.fromRupees(100000));
      expect(ok('₹99 debited from A/c XX1111').amount, Money.fromRupees(99));
    });

    test('paise never drift', () {
      expect(ok('Rs.0.01 debited from A/c XX1111').amount.paise, 1);
      expect(ok('Rs.19.99 debited from A/c XX1111').amount.paise, 1999);
    });
  });

  group('account hint', () {
    test('extracts last four from several shapes', () {
      expect(ok('Rs.10 debited from A/c XXXX4321').accountHint, '4321');
      expect(ok('Rs.10 debited from A/C no. XX8765').accountHint, '8765');
      expect(ok('Rs.10 spent on Card ending 5678').accountHint, '5678');
      expect(ok('Rs.10 debited from ac ***2468').accountHint, '2468');
    });
  });

  group('confidence gates auto-approve', () {
    test('a bare message from an unknown sender cannot auto-post', () {
      final p = ok('Rs.500 debited', sender: '9876543210');
      expect(p.confidence, lessThan(kAutoApproveMinConfidence),
          reason: 'no account, no ref, personal sender → must go to inbox');
    });

    test('a full bank message can auto-post', () {
      final p = ok(
        'Rs.250.00 debited from A/c XX1234 at SWIGGY on 09-07-26. '
        'Ref no 998877665544. Avl Bal Rs.3,000.00',
      );
      expect(p.confidence, greaterThanOrEqualTo(kAutoApproveMinConfidence));
      expect(p.merchant, isNotNull);
    });
  });

  group('sender classification', () {
    test('bank short codes recognised', () {
      expect(MessageParser.looksLikeBankSender('AD-IPPBNK'), isTrue);
      expect(MessageParser.looksLikeBankSender('VM-HDFCBK'), isTrue);
      expect(MessageParser.looksLikeBankSender('IPPBNK'), isTrue);
    });

    test('a phone number is a person, not a bank', () {
      expect(MessageParser.looksLikeBankSender('9876543210'), isFalse);
      expect(MessageParser.looksLikeBankSender('+919876543210'), isFalse);
    });
  });
}
