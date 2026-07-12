import 'package:flutter/material.dart';

import '../../data/tables.dart';
import '../money.dart';
import '../theme/app_colors.dart';

/// Colour only ever *means* something: money in is green, money out is red,
/// a transfer is neither — and a person movement is neither either.
Color colorForTxType(TxType type) => switch (type) {
      TxType.income => AppColors.income,
      TxType.expense => AppColors.expense,
      TxType.transfer => AppColors.transfer,
      TxType.personOut || TxType.personIn => AppColors.person,
    };

/// The icon that stands for a transaction's kind, when there is no category.
///
/// A person movement is drawn as a *person*, not as an arrow: the counterparty
/// is the fact that matters, and the direction is already carried by the row's
/// sign and by its title ("Gave to Asha"). The old `call_made`/`call_received`
/// icons were telephone glyphs and said nothing about money at all.
IconData iconForTxType(TxType type) => switch (type) {
      TxType.transfer => Icons.swap_horiz_rounded,
      TxType.personOut => Icons.person_outline_rounded,
      TxType.personIn => Icons.person_outline_rounded,
      TxType.income => Icons.south_west_rounded,
      TxType.expense => Icons.north_east_rounded,
    };

/// What to call a transaction that has no category. [personName] names the
/// counterparty when there is one — "Gave to Asha" beats "Gave to person".
String labelForTxType(TxType type, {String? personName}) => switch (type) {
      TxType.transfer => 'Transfer',
      TxType.personOut => 'Gave to ${personName ?? 'person'}',
      TxType.personIn => 'Received from ${personName ?? 'person'}',
      TxType.income => 'Income',
      TxType.expense => 'Expense',
    };

/// Renders an amount with tabular figures so columns line up.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    this.style,
    this.color,
    this.signed = false,
    this.compact = false,
    super.key,
  });

  final Money amount;
  final TextStyle? style;
  final Color? color;

  /// Prefix `+`/`-`. Use on ledger rows, not on balances.
  final bool signed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = compact
        ? MoneyFormat.compact(amount)
        : signed
            ? MoneyFormat.signed(amount)
            : MoneyFormat.symbol(amount);

    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.bodyLarge)?.copyWith(
        color: color,
        fontFeatures: kTabularFigures,
      ),
    );
  }
}

/// A balance. Negative renders red because on a credit card it means *owed*.
class BalanceText extends StatelessWidget {
  const BalanceText(this.amount, {this.style, super.key});

  final Money amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return MoneyText(
      amount,
      style: style,
      color: amount.isNegative ? AppColors.expense : null,
    );
  }
}

/// A [BalanceText] that counts to its value instead of snapping to it — and
/// counts *from* the old value whenever the balance changes.
///
/// Reserve this for a single hero figure. Numbers that sit in a list or a
/// column must not move, or the whole screen twitches on every ledger write.
class AnimatedBalanceText extends StatelessWidget {
  const AnimatedBalanceText(
    this.amount, {
    this.style,
    this.duration = const Duration(milliseconds: 650),
    super.key,
  });

  final Money amount;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return BalanceText(amount, style: style);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: amount.paise),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, paise, _) => BalanceText(Money(paise), style: style),
    );
  }
}
