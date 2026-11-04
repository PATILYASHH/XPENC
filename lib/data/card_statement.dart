import '../core/money.dart';
import 'database.dart';
import 'tables.dart';

/// A tracked credit card's last statement (GitHub #183): what it owed when
/// the statement closed, what has come in since, and what's been charged
/// since — the next statement, so far. Purchases after the close belong to
/// that next one, not to what's due now.
///
/// Worked out from the ledger every time, not frozen at the close, so a
/// purchase entered or edited later still lands on the statement its date
/// puts it on.
class CardStatement {
  const CardStatement({
    required this.closedOn,
    required this.dueOn,
    required this.statement,
    required this.paidSince,
    required this.spentSince,
  });

  /// The day the statement closed.
  final DateTime closedOn;

  /// The day it's due.
  final DateTime dueOn;

  /// What the card owed at the close — the statement balance.
  final Money statement;

  /// Money into the card since the close: payments, refunds.
  final Money paidSince;

  /// Charges since the close: the next statement so far.
  final Money spentSince;

  /// What's still to pay of [statement].
  Money get leftToPay => paidSince >= statement
      ? const Money.zero()
      : statement - paidSince;
}

/// [card]'s last statement as of [today], from its [txs] (any others are
/// ignored) and its cycle days — see [CardStatement].
CardStatement cardStatementOf({
  required AccountRow card,
  required Iterable<TransactionRow> txs,
  required DateTime today,
  required int statementDay,
  required int dueDay,
}) {
  final open = AppDatabase.creditCardStatementPeriod(
    today: today,
    statementDay: statementDay,
  );
  final closedOn = DateTime(
    open.start.year,
    open.start.month,
    open.start.day - 1,
  );
  final dueOn = AppDatabase.creditCardNextDueDate(
    today: open.start,
    statementDay: statementDay,
    dueDay: dueDay,
  );

  var paid = const Money.zero();
  var spent = const Money.zero();
  for (final t in txs) {
    if (t.date.isBefore(open.start)) continue;
    final from = t.accountId == card.id;
    final into = t.toAccountId == card.id;
    switch (t.type) {
      case TxType.income || TxType.personIn || TxType.correctionIn:
        if (from) paid += t.amount;
      case TxType.expense || TxType.personOut || TxType.correctionOut:
        if (from) spent += t.amount;
      case TxType.transfer:
        if (into) paid += t.toAmount ?? t.amount;
        if (from) spent += t.amount;
    }
  }
  // The balance as it closed: today's, with everything since taken back.
  final atClose = card.currentBalance - paid + spent;
  return CardStatement(
    closedOn: closedOn,
    dueOn: dueOn,
    statement: atClose.isNegative
        ? Money.fromPaise(-atClose.paise)
        : const Money.zero(),
    paidSince: paid,
    spentSince: spent,
  );
}
