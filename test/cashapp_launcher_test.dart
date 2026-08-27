import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/payments/cashapp_launcher.dart';

void main() {
  group('CashAppLauncher.buildUri', () {
    test('builds a cash.app link with a \$-prefixed cashtag and amount', () {
      final uri = CashAppLauncher.buildUri(
        cashtag: 'rahul',
        amount: Money.fromRupees(20),
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'cash.app');
      expect(uri.path, r'/$rahul/20.00');
    });

    test('leaves an already \$-prefixed cashtag untouched', () {
      final uri = CashAppLauncher.buildUri(
        cashtag: r'$rahul',
        amount: Money.fromRupees(20),
      );
      expect(uri.path, r'/$rahul/20.00');
    });

    test('strips a pasted cash.app URL down to the cashtag', () {
      final uri = CashAppLauncher.buildUri(
        cashtag: r'https://cash.app/$rahul/5',
        amount: Money.fromRupees(20),
      );
      expect(uri.path, r'/$rahul/20.00');
    });

    test('amount is a plain decimal string, never locale-grouped', () {
      final uri = CashAppLauncher.buildUri(
        cashtag: 'x',
        amount: Money.fromRupees(123456.7),
      );
      expect(uri.path, r'/$x/123456.70');
      expect(uri.path, isNot(contains(',')));
    });
  });
}
