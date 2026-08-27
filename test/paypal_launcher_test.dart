import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/payments/paypal_launcher.dart';

void main() {
  group('PaypalLauncher.buildUri', () {
    test('builds a paypal.me link with id, amount and currency', () {
      final uri = PaypalLauncher.buildUri(
        paypalId: 'rahul',
        amount: Money.fromRupees(500),
        currencyCode: 'INR',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'paypal.me');
      expect(uri.path, '/rahul/500.00INR');
    });

    test('strips a full paypal.me URL down to the bare id', () {
      final uri = PaypalLauncher.buildUri(
        paypalId: 'https://www.paypal.me/rahul/',
        amount: Money.fromRupees(20),
        currencyCode: 'USD',
      );

      expect(uri.path, '/rahul/20.00USD');
    });

    test('am is a plain decimal string, never locale-grouped', () {
      final uri = PaypalLauncher.buildUri(
        paypalId: 'x',
        amount: Money.fromRupees(123456.7),
        currencyCode: 'INR',
      );
      expect(uri.path, '/x/123456.70INR');
      expect(uri.path, isNot(contains(',')));
    });
  });

  group('PaypalLauncher.normalizeId', () {
    test('leaves a bare id untouched', () {
      expect(PaypalLauncher.normalizeId('rahul'), 'rahul');
    });

    test('strips scheme, www and trailing path from a pasted URL', () {
      expect(
        PaypalLauncher.normalizeId('https://www.paypal.me/rahul/10USD'),
        'rahul',
      );
    });
  });
}
