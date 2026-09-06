import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

TransactionRow _transfer({
  required int accountId,
  required int toAccountId,
  required Money amount,
  Money? toAmount,
}) => TransactionRow(
  id: 1,
  type: TxType.transfer,
  amount: amount,
  accountId: accountId,
  toAccountId: toAccountId,
  date: DateTime(2026, 1, 1),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  needsAmountReview: false,
  toAmount: toAmount,
);

void main() {
  group('accountMovement', () {
    test('a same-currency transfer credits the destination with the full '
        'amount (toAmount null)', () {
      final tx = _transfer(accountId: 1, toAccountId: 2, amount: const Money(50000));
      expect(accountMovement(tx, {1}), const Money(-50000));
      expect(accountMovement(tx, {2}), const Money(50000));
    });

    test('a cross-currency transfer credits the destination with toAmount, '
        'not the source-currency amount', () {
      final tx = _transfer(
        accountId: 1,
        toAccountId: 2,
        amount: const Money(830000), // ₹8300.00 left the source
        toAmount: const Money(10000), // $100.00 landed in the destination
      );
      expect(accountMovement(tx, {1}), const Money(-830000));
      expect(accountMovement(tx, {2}), const Money(10000));
    });
  });
}
