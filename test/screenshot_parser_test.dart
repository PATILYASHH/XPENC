import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/parser/bank_message.dart';
import 'package:xpenc/features/message_capture/parser/screenshot_parser.dart';

const parser = ScreenshotParser();

ParseResult run(String body) => parser.parse(
      RawMessage(
        body: body,
        sender: 'Screenshot',
        receivedAt: DateTime(2026, 8, 15),
        source: MessageSourceKind.screenshot,
      ),
    );

ParsedMessage ok(String body) {
  final r = run(body);
  expect(r, isA<ParsedMessage>(), reason: 'expected a parse, got $r');
  return r as ParsedMessage;
}

RejectReason rejected(String body) {
  final r = run(body);
  expect(r, isA<Rejected>(), reason: 'expected a reject, got $r');
  return (r as Rejected).reason;
}

void main() {
  group('a PhonePe/GPay "payment successful" screenshot — money out', () {
    test('label and name on separate lines', () {
      final p = ok(
        'Payment Successful\n'
        '₹500\n'
        'Paid to\n'
        'John Doe\n'
        '15 Aug 2026, 10:30 am\n'
        'UPI Transaction ID\n'
        '123456789012',
      );
      expect(p.amount, Money.fromRupees(500));
      expect(p.direction, TxDirection.debit);
      expect(p.merchant, 'John Doe');
      expect(p.reference, '123456789012');
    });

    test('label and name on the same line', () {
      final p = ok(
        'Payment Successful\n'
        'Paid to Swiggy\n'
        '₹350.50\n'
        'Txn ID: ABC123XYZ456',
      );
      expect(p.amount, Money.fromRupees(350.50));
      expect(p.direction, TxDirection.debit);
      expect(p.merchant, 'Swiggy');
      expect(p.reference, 'ABC123XYZ456');
    });
  });

  group('a "payment received" screenshot — money in', () {
    test('parses direction, amount and sender', () {
      final p = ok(
        '₹1,200\n'
        'Payment received\n'
        'Received from\n'
        'Priya Sharma\n'
        'UPI Ref No 987654321098',
      );
      expect(p.amount, Money.fromRupees(1200));
      expect(p.direction, TxDirection.credit);
      expect(p.merchant, 'Priya Sharma');
      expect(p.reference, '987654321098');
    });
  });

  test('a cashback figure is never mistaken for the paid amount', () {
    final p = ok(
      'Payment Successful\n'
      'Paid to Amazon\n'
      '₹999\n'
      'Cashback ₹20',
    );
    expect(p.amount, Money.fromRupees(999),
        reason: 'must pick the txn amount, not the cashback');
    expect(p.merchant, 'Amazon');
  });

  test('confidence rewards a found payee and reference', () {
    final withBoth = ok(
      'Payment Successful\nPaid to Swiggy\n₹350\nUPI Ref No 123456789012',
    );
    final amountAndDirectionOnly = ok('Payment Successful\n₹350');
    expect(withBoth.confidence, greaterThan(amountAndDirectionOnly.confidence));
    expect(amountAndDirectionOnly.confidence, 40);
  });

  test(
    'a real PhonePe screenshot (GitHub #25) — no ₹ glyph, scrambled block '
    'order, an icon misread as a name, and a stray "Transaction Successful" '
    "that must not be mistaken for a reference number",
    () {
      final p = ok(
        'Paid to\n'
        'o(\n'
        'Sent to\n'
        'Transaction Successful\n'
        '04:06 pm on 11 Aug 2026\n'
        'Shree Foods\n'
        'shrikantpatil6@bpunity\n'
        ':Transfer Details\n'
        ': UP• shrikantpatil6@bpunity\n'
        'UNIFIED PAYMENTS INTERFACE\n'
        'PhonePe Transaction ID\n'
        'Debited from\n'
        'T2608111606297137560 265\n'
        'Yash\n'
        'UTR: 243197130234\n'
        'Powered by\n'
        'UPIAXIS BANK\n'
        '700\n'
        'NIFIFD PAYAENTS INTERFACE\n'
        '700',
      );
      expect(p.amount, Money.fromRupees(700),
          reason: 'no currency symbol survived OCR — must fall back to the '
              'bare "700" line');
      expect(p.direction, TxDirection.debit);
      expect(p.merchant, 'Shree Foods',
          reason: 'the line right after "Paid to" is a misread icon ("o("), '
              'not the name — must recover via the VPA-adjacency strategy');
      expect(p.reference, '243197130234',
          reason: 'the UTR, not "Successful" misread off "Transaction '
              'Successful" and not "Debited" bleeding across the line after '
              'the label-only "PhonePe Transaction ID" line');
    },
  );

  test(
    'a real Paytm screenshot — QR-merchant payment with no ₹ glyph at all, '
    'misread as a bare "T" glued onto the digits, and a "Notes:" label that '
    'must not be mistaken for a payee name',
    () {
      final p = ok(
        'Sent from:\n'
        'Notes:\n'
        'paytmqr6udoom@ptys\n'
        'Transaction ID:\n'
        'Paid from\n'
        'Samsung Wallet\n'
        '12 AUG 2026, 06:15 PM\n'
        'T20.00\n'
        'Powered by\n'
        'Sent\n'
        'yashpatil6161@pingpay\n'
        '228896402246\n'
        'AXIS BANK |LFI\n'
        'UNIFIED PAYMENTS INTERFACE\n'
        'UPI',
      );
      expect(p.amount, Money.fromRupees(20),
          reason: '₹ misread as a bare "T" glued onto "20.00"');
      expect(p.direction, TxDirection.debit);
      expect(p.merchant, isNull,
          reason: 'the only name-shaped line is "Notes:", a bare field '
              'label with nothing after it — never a real payee');
    },
  );

  test(
    'a real Google Pay screenshot — "transaction details" for money '
    'received, with no "received"/"credited" verb anywhere and an '
    'unrelated VPA sitting right above the account owner\'s own name',
    () {
      final p = ok(
        'From Samruddhi Patil\n'
        '+91 88578 72913\n'
        '80\n'
        'UPI transaction ID\n'
        '126372525429\n'
        'S\n'
        '16 Jul 2026, 12:15 pm\n'
        'Pnank India Post Payment Bank 8149\n'
        'India)\n'
        'Khau\n'
        'Completed\n'
        'To: Yash Sandip Patil\n'
        'Google Pay parthmagadum1@okaxis\n'
        'From: SAMRUDDHI SUDHIR PATIL (Bank of\n'
        'CICAgLi4qpCOBA\n'
        'Google Pay •\n'
        'samruddhipatil568-1@okhdfcbank\n'
        'Google transaction ID\n'
        'Payments may take up to 3 working days to be\n'
        'reflected in yOur accOunt\n'
        'POWERED BY\n'
        'UPI»\n'
        'UNIFIED PAYMENTS INTERFACE\n'
        'G Pay',
      );
      expect(p.amount, Money.fromRupees(80));
      expect(p.direction, TxDirection.credit,
          reason: 'no "received"/"credited" verb anywhere — must fall back '
              'to the bare "From Samruddhi Patil" header line');
      expect(p.merchant, 'Samruddhi Patil',
          reason: 'the same-line "From X" header must win over the VPA '
              'sitting above "To: Yash Sandip Patil" (the account owner, '
              'not the sender)');
      expect(p.reference, '126372525429');
    },
  );

  test(
    'a real PhonePe screenshot — "transaction details" for money sent, '
    'with no "sent"/"paid" verb anywhere, a masked account suffix that '
    'must not be mistaken for the amount, and a "Completed" status line '
    'that must not be mistaken for the reference',
    () {
      final p = ok(
        'To KAMBALE BALVANT GOPAL\n'
        'Inda Post\n'
        '8149\n'
        'K\n'
        '70\n'
        '22 Jun 2026, 10:41 am\n'
        '653902148962\n'
        'Pay again\n'
        'India Post Payment Bank\n'
        'UPI transaction ID\n'
        'Completed\n'
        'To: KAMBALE BALVANT GOPAL\n'
        'PhonePe• 9552829783@axl\n'
        'From: YESH SANDIP PATIL (India Post\n'
        'Payment Bank)\n'
        'CICAgNjNKPPiBQ\n'
        'Google Pay • parthmagadum1@okicici\n'
        'Google transaction ID\n'
        'POWERED BY\n'
        'UPI\n'
        'UNIFIED PAYMENTS INTERFACE\n'
        'G Pay',
      );
      expect(p.amount, Money.fromRupees(70),
          reason: 'the masked account suffix "8149" appears earlier in '
              'reading order than the real amount — must not win');
      expect(p.direction, TxDirection.debit,
          reason: 'no "sent"/"paid" verb anywhere — must fall back to the '
              'bare "To KAMBALE BALVANT GOPAL" header line');
      expect(p.merchant, 'KAMBALE BALVANT GOPAL');
      expect(p.reference, isNull,
          reason: '"Completed" sits right after the "UPI transaction ID" '
              'label — a pure-letter status word must never be accepted '
              'as a reference, and the real ID nearby has no label at all');
    },
  );

  group('rejections — never invent a transaction from noise', () {
    test('no text recognised at all', () {
      expect(rejected(''), RejectReason.notATransaction);
      expect(rejected('   \n  \n'), RejectReason.notATransaction);
    });

    test('an amount with no debit/credit/received language', () {
      expect(
        rejected('₹500\nRandom Screenshot Text\nNo Recognisable Verb Here'),
        RejectReason.noDirection,
      );
    });

    test('direction language but no amount anywhere', () {
      expect(
        rejected('Payment Successful\nThank you for using our app'),
        RejectReason.noAmount,
      );
    });
  });
}
