import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/parser/bank_message.dart';
import 'package:xpenc/features/message_capture/parser/bank_templates.dart';
import 'package:xpenc/features/message_capture/parser/message_parser.dart';

/// The bank formats people shared through GitHub's "Bank support" form,
/// verbatim apart from their redaction placeholders (filled with made-up
/// digits). If one of these stops parsing, that bank's users lose capture.
void main() {
  const parser = MessageParser();

  ParseResult parse(String body, String sender) => parser.parse(
    RawMessage(body: body, sender: sender, receivedAt: DateTime(2026, 11, 24)),
  );

  ParsedMessage parsed(String body, String sender) {
    final r = parse(body, sender);
    expect(r, isA<ParsedMessage>(), reason: body);
    return r as ParsedMessage;
  }

  group('HDFC Bank (#165, JD-HDFCBK-S)', () {
    const sender = 'JD-HDFCBK-S';

    test('UPI debit: "Sent Rs.… From … To …"', () {
      final p = parsed(
        'Sent Rs.232.00\n'
        'From HDFC Bank A/C *4821\n'
        'To SHARMA GENERAL STORE\n'
        'On 12/10/26\n'
        'Ref 629874512365\n'
        'Not You?\n'
        'Call 18002586161/SMS BLOCK UPI to 7308080808',
        sender,
      );
      expect(p.amount, Money.fromRupees(232));
      expect(p.direction, TxDirection.debit);
      expect(p.accountHint, '4821');
      expect(p.merchant, 'SHARMA GENERAL STORE');
      expect(p.reference, '629874512365');
      expect(p.confidence, greaterThanOrEqualTo(kAutoApproveMinConfidence));
    });

    test('UPI credit from a VPA', () {
      final p = parsed(
        'Credit Alert!\n'
        'Rs.3500.00 credited to HDFC Bank A/c XX4821 on 13-10-26 from VPA '
        'rahul.k@okaxis (UPI 629874512399)',
        sender,
      );
      expect(p.amount, Money.fromRupees(3500));
      expect(p.direction, TxDirection.credit);
      expect(p.accountHint, '4821');
      expect(p.merchant, 'rahul.k@okaxis');
      expect(p.reference, '629874512399');
    });
  });

  group('Federal Bank (#211, AX-FEDBNK-S / VM-FEDBNK-S)', () {
    test('UPI debit with balance', () {
      final p = parsed(
        'Debited Rs 274.00 from a/c X9115 on 24Nov26 19:33 via UPI to '
        'SNAPMINT FIN. Ref 632819821711.Bal Rs 669.95. Not you?Call '
        '18004251199 -Federal Bank',
        'AX-FEDBNK-S',
      );
      expect(p.amount, Money.fromRupees(274));
      expect(p.direction, TxDirection.debit);
      expect(p.accountHint, '9115');
      expect(p.merchant, 'SNAPMINT FIN');
      expect(p.reference, '632819821711');
      expect(p.availableBalance, const Money(66995));
    });

    test('credit with a "BAL-Rs." balance', () {
      final p = parsed(
        'Dear Customer, Rs.20 credited to your A/c XX9115 on 23NOV2026 '
        '14:25:13. BAL-Rs.1050.95-Federal Bank',
        'VM-FEDBNK-S',
      );
      expect(p.amount, Money.fromRupees(20));
      expect(p.direction, TxDirection.credit);
      expect(p.accountHint, '9115');
      expect(p.availableBalance, const Money(105095));
    });

    test('card spend: "spent@ MERCHANT on"', () {
      final p = parsed(
        'Rs 1158 spent@ WWW AMAZON on 14OCT26 03:49 Bal Rs 4144.06 Ref '
        '831810. Not you? Call 18004251199/ SMS NO 9115 to 9895088888 '
        '-Federal Bank',
        'AX-FEDBNK-S',
      );
      expect(p.amount, Money.fromRupees(1158));
      expect(p.direction, TxDirection.debit);
      expect(p.merchant, 'WWW AMAZON');
      expect(p.availableBalance, const Money(414406));
    });

    test('a mandate being set up is not a payment', () {
      final r = parse(
        'UPI ASPRESENTED mandate created towards Google Play till '
        '31-12-2036. Max amount Rs 2099.00. Ref: 667359969566. Not you? '
        'Call 18004201199 -Federal Bank',
        'AX-FEDBNK-S',
      );
      expect(r, isA<Rejected>());
    });
  });

  group('sender IDs', () {
    test('TRAI suffixes still look like a bank', () {
      expect(MessageParser.looksLikeBankSender('JD-HDFCBK-S'), isTrue);
      expect(MessageParser.looksLikeBankSender('AX-FEDBNK-S'), isTrue);
      expect(MessageParser.looksLikeBankSender('VM-SBIUPI-T'), isTrue);
    });

    test('the code is the fixed middle of a sender ID', () {
      expect(senderCode('JD-HDFCBK-S'), 'HDFCBK');
      expect(senderCode('VM-HDFCBK'), 'HDFCBK');
      expect(senderCode('ax-fedbnk-s'), 'FEDBNK');
      expect(normalizeSenderPattern(' AX-FEDBNK-S '), 'FEDBNK');
      expect(normalizeSenderPattern('fedbnk'), 'FEDBNK');
    });

    test('a phone number can never be tracked', () {
      expect(normalizeSenderPattern('+919876543210'), isNull);
      expect(normalizeSenderPattern('9876543210'), isNull);
      expect(normalizeSenderPattern('ab'), isNull);
    });

    test('tracked senders match, adverts never do', () {
      expect(tracksSender('JD-HDFCBK-S', ['HDFCBK']), isTrue);
      expect(tracksSender('AX-FEDBNK-T', ['FEDBNK']), isTrue);
      expect(tracksSender('JD-HDFCBK-P', ['HDFCBK']), isFalse);
      expect(tracksSender('AX-SWIGGY-S', ['HDFCBK', 'FEDBNK']), isFalse);
      expect(tracksSender('9876543210', ['HDFCBK']), isFalse);
    });

    test('the GitHub templates are seeded, with their issue', () {
      expect(templateForSender('JD-HDFCBK-S')?.sharedIn, 165);
      expect(templateForSender('AX-FEDBNK-S')?.bank, 'Federal Bank');
      expect(templateForSender('AX-FEDBNK-S')?.sharedIn, 211);
      expect(
        kSeedSenderRules.map((r) => r.pattern),
        containsAll(['HDFCBK', 'FEDBNK', 'IPPBNK', 'SBIUPI']),
      );
    });
  });
}
