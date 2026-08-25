import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/payments/upi_launcher.dart';

void main() {
  group('UpiLauncher.buildGenericUri', () {
    test('builds a upi://pay link with the right params', () {
      final uri = UpiLauncher.buildGenericUri(
        action: UpiAction.pay,
        payeeUpiId: 'rahul@okhdfcbank',
        payeeName: 'Rahul',
        amount: Money.fromRupees(500),
        note: 'Settlement',
      );

      expect(uri.scheme, 'upi');
      expect(uri.host, 'pay');
      expect(uri.queryParameters['pa'], 'rahul@okhdfcbank');
      expect(uri.queryParameters['pn'], 'Rahul');
      expect(uri.queryParameters['am'], '500.00');
      expect(uri.queryParameters['cu'], 'INR');
      expect(uri.queryParameters['tn'], 'Settlement');
    });

    test('builds a upi://collect link', () {
      final uri = UpiLauncher.buildGenericUri(
        action: UpiAction.collect,
        payeeUpiId: 'me@okhdfcbank',
        payeeName: 'Yash',
        amount: Money.fromRupees(250),
      );

      expect(uri.host, 'collect');
      expect(uri.queryParameters.containsKey('tn'), isFalse);
    });

    test('collect uses the caller-supplied identity as pa/pn, not the '
        "person's", () {
      // buildGenericUri doesn't know "whose" identity it's building for —
      // the caller decides. Calling it with "my" identity for a collect
      // link must produce a URI whose pa/pn is that identity.
      final uri = UpiLauncher.buildGenericUri(
        action: UpiAction.collect,
        payeeUpiId: 'me@okhdfcbank',
        payeeName: 'Yash',
        amount: Money.fromRupees(100),
      );
      expect(uri.queryParameters['pa'], 'me@okhdfcbank');
      expect(uri.queryParameters['pn'], 'Yash');
    });

    test('percent-encodes a name with a space and a note with special '
        'characters, round-tripping correctly', () {
      final uri = UpiLauncher.buildGenericUri(
        action: UpiAction.pay,
        payeeUpiId: 'rahul.kumar@okaxis',
        payeeName: 'Rahul Kumar',
        amount: Money.fromRupees(1234.5),
        note: 'Lunch @ Cafe & Bar',
      );

      final reparsed = Uri.parse(uri.toString());
      expect(reparsed.queryParameters['pn'], 'Rahul Kumar');
      expect(reparsed.queryParameters['tn'], 'Lunch @ Cafe & Bar');
    });

    test('am is a plain decimal string, never locale-grouped', () {
      final uri = UpiLauncher.buildGenericUri(
        action: UpiAction.pay,
        payeeUpiId: 'x@y',
        payeeName: 'X',
        amount: Money.fromRupees(123456.7),
      );
      // MoneyFormat.bare would render "1,23,456.70" (Indian grouping) —
      // that must never leak into a upi:// am= param.
      expect(uri.queryParameters['am'], '123456.70');
      expect(uri.queryParameters['am'], isNot(contains(',')));
    });

    test('an empty payee name falls back rather than sending a blank pn', () {
      final uri = UpiLauncher.buildGenericUri(
        action: UpiAction.pay,
        payeeUpiId: 'x@y',
        payeeName: '',
        amount: Money.fromRupees(10),
      );
      expect(uri.queryParameters['pn'], isNotEmpty);
    });
  });

  group('UpiLauncher.buildAppSpecificUri', () {
    test('Google Pay pay uses the documented tez:// scheme', () {
      final uri = UpiLauncher.buildAppSpecificUri(
        app: UpiApp.googlePay,
        action: UpiAction.pay,
        payeeUpiId: 'x@y',
        payeeName: 'X',
        amount: Money.fromRupees(10),
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'tez');
    });

    test('PhonePe pay uses the documented phonepe:// scheme', () {
      final uri = UpiLauncher.buildAppSpecificUri(
        app: UpiApp.phonePe,
        action: UpiAction.pay,
        payeeUpiId: 'x@y',
        payeeName: 'X',
        amount: Money.fromRupees(10),
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'phonepe');
    });

    test(
      'collect has no documented app-specific scheme for either app — '
      'returns null on purpose, not a guessed URI',
      () {
        for (final app in UpiApp.values) {
          final uri = UpiLauncher.buildAppSpecificUri(
            app: app,
            action: UpiAction.collect,
            payeeUpiId: 'x@y',
            payeeName: 'X',
            amount: Money.fromRupees(10),
          );
          expect(uri, isNull, reason: '$app collect must stay null');
        }
      },
    );
  });
}
