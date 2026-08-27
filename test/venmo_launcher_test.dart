import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/payments/venmo_launcher.dart';

void main() {
  group('VenmoLauncher.buildUri', () {
    test('builds a venmo.com pay link with the right params', () {
      final uri = VenmoLauncher.buildUri(
        username: 'rahul',
        amount: Money.fromRupees(500),
        note: 'Settlement',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'venmo.com');
      expect(uri.path, '/rahul');
      expect(uri.queryParameters['txn'], 'pay');
      expect(uri.queryParameters['amount'], '500.00');
      expect(uri.queryParameters['note'], 'Settlement');
    });

    test('strips a pasted venmo.com URL and leading @ down to the username', () {
      final uri = VenmoLauncher.buildUri(
        username: 'https://venmo.com/u/@rahul?txn=pay',
        amount: Money.fromRupees(20),
      );
      expect(uri.path, '/rahul');
    });

    test('am is a plain decimal string, never locale-grouped', () {
      final uri = VenmoLauncher.buildUri(
        username: 'x',
        amount: Money.fromRupees(123456.7),
      );
      expect(uri.queryParameters['amount'], '123456.70');
      expect(uri.queryParameters['amount'], isNot(contains(',')));
    });

    test('omits note when not given', () {
      final uri = VenmoLauncher.buildUri(
        username: 'x',
        amount: Money.fromRupees(10),
      );
      expect(uri.queryParameters.containsKey('note'), isFalse);
    });
  });
}
