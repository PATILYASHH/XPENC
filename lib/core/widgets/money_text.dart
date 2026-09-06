import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/tables.dart';
import '../currency.dart';
import '../money.dart';
import '../theme/app_colors.dart';

/// Broadcasts the active currency down the tree so every [MoneyText] rebuilds
/// the instant it changes — even a screen kept alive in the background. The
/// numbers themselves come from [MoneyFormat], which the app keeps configured
/// to match; this scope only exists to notify dependents.
class CurrencyScope extends InheritedWidget {
  const CurrencyScope({
    required this.currency,
    required this.showSymbol,
    required super.child,
    super.key,
  });

  final Currency currency;
  final bool showSymbol;

  /// Establishes a dependency so the caller rebuilds on a currency change.
  /// Absent in bare widget tests, where the [MoneyFormat] default stands in.
  static void depend(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<CurrencyScope>();
  }

  @override
  bool updateShouldNotify(CurrencyScope oldWidget) =>
      currency.code != oldWidget.currency.code ||
      showSymbol != oldWidget.showSymbol;
}

/// Broadcasts the "hide amounts" privacy toggle down the tree so every
/// [MoneyText] masks (or unmasks) the instant it flips — the eye icon in
/// [AppShell]'s top bar. Same broadcast-only shape as [CurrencyScope]: the
/// masking itself happens in [MoneyText.build], this only notifies.
class AmountVisibilityScope extends InheritedWidget {
  const AmountVisibilityScope({
    required this.hidden,
    required super.child,
    super.key,
  });

  final bool hidden;

  /// Defaults to visible (not hidden) when absent — bare widget tests, or
  /// any [MoneyText] rendered before the scope is mounted.
  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AmountVisibilityScope>();
    return scope?.hidden ?? false;
  }

  @override
  bool updateShouldNotify(AmountVisibilityScope oldWidget) =>
      hidden != oldWidget.hidden;
}

/// The privacy switch for [AmountVisibilityScope] — small enough to sit right
/// next to a hero figure (the dashboard's Total Money card, an account
/// balance, ...) instead of living as a single button disconnected from any
/// amount on screen. Toggling it masks every [MoneyText] app-wide at once,
/// wherever else it's shown.
class AmountVisibilityToggle extends ConsumerWidget {
  const AmountVisibilityToggle({this.size = 18, super.key});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hideAmountsProvider);
    return IconButton(
      tooltip: hidden ? 'Show amounts' : 'Hide amounts',
      iconSize: size,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
      ),
      onPressed: () => ref.read(dbProvider).setHideAmounts(!hidden),
    );
  }
}

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
    this.currency,
    super.key,
  });

  final Money amount;
  final TextStyle? style;
  final Color? color;

  /// Prefix `+`/`-`. Use on ledger rows, not on balances.
  final bool signed;
  final bool compact;

  /// Renders against this currency instead of the globally configured one —
  /// for a specific account's/transaction's own (possibly foreign) amount.
  /// Null (the default) renders exactly as before, via [MoneyFormat].
  final Currency? currency;

  /// A fixed-width placeholder — never derived from the real digits, so the
  /// mask can't leak the amount's order of magnitude (a 3-digit vs 7-digit
  /// figure would otherwise be visibly distinguishable even hidden).
  static const _maskGlyph = '••••••';

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the currency setting changes — [MoneyFormat] is already
    // reconfigured by then, so the new symbol/grouping lands immediately.
    // Irrelevant when [currency] is set explicitly, but depending
    // unconditionally keeps this widget's rebuild behavior simple.
    CurrencyScope.depend(context);
    final hidden = AmountVisibilityScope.of(context);
    final displayCurrency = currency ?? MoneyFormat.currency;
    final text = hidden
        ? (MoneyFormat.showSymbol
            ? '${displayCurrency.symbol} $_maskGlyph'
            : _maskGlyph)
        : compact
            ? MoneyFormat.compact(amount)
            : signed
                ? _signedIn(amount, currency)
                : currency == null
                    ? MoneyFormat.symbol(amount)
                    : MoneyFormat.symbolIn(amount, currency!);

    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.bodyLarge)?.copyWith(
        color: color,
        fontFeatures: kTabularFigures,
      ),
    );
  }

  static String _signedIn(Money m, Currency? currency) {
    if (currency == null) return MoneyFormat.signed(m);
    final sign = m.isNegative ? '-' : '+';
    return '$sign${MoneyFormat.symbolIn(m.abs, currency)}';
  }
}

/// A balance. Negative renders red because on a credit card it means *owed*.
class BalanceText extends StatelessWidget {
  const BalanceText(this.amount, {this.style, this.currency, super.key});

  final Money amount;
  final TextStyle? style;
  final Currency? currency;

  @override
  Widget build(BuildContext context) {
    return MoneyText(
      amount,
      style: style,
      currency: currency,
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
    this.currency,
    this.duration = const Duration(milliseconds: 650),
    super.key,
  });

  final Money amount;
  final TextStyle? style;
  final Currency? currency;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return BalanceText(amount, style: style, currency: currency);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: amount.paise),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, paise, _) =>
          BalanceText(Money(paise), style: style, currency: currency),
    );
  }
}
