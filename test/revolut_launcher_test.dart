import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/payments/revolut_launcher.dart';

void main() {
  group('RevolutLauncher.buildUri', () {
    test('builds a revolut.me link with username and amount', () {
      final uri = RevolutLauncher.buildUri(
        username: 'rahul',
        amount: Money.fromRupees(20),
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'revolut.me');
      expect(uri.path, '/rahul/20.00');
    });

    test('strips a pasted revolut.me URL down to the username', () {
      final uri = RevolutLauncher.buildUri(
        username: 'https://revolut.me/rahul/10',
        amount: Money.fromRupees(20),
      );
      expect(uri.path, '/rahul/20.00');
    });

    test('amount is a plain decimal string, never locale-grouped', () {
      final uri = RevolutLauncher.buildUri(
        username: 'x',
        amount: Money.fromRupees(123456.7),
      );
      expect(uri.path, '/x/123456.70');
      expect(uri.path, isNot(contains(',')));
    });
  });
}
