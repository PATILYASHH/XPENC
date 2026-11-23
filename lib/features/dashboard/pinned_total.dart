import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';

/// The Dashboard's Total money figure while it's scrolled up out of sight
/// under the top bar — null while it's on screen, or not on the Dashboard at
/// all. The top bar shows it in place of the "Dashboard" title then, so
/// what you have never leaves the screen.
///
/// Set by the Total money card (`_NetWorthCard`), read by the shell's top
/// bars.
final dashboardPinnedTotal = ValueNotifier<Money?>(null);

/// [dashboardPinnedTotal] as a top-bar title: the whole part at [style]'s
/// size, the paise after the point smaller. Masked like every other amount
/// while amounts are hidden.
class PinnedTotalTitle extends StatelessWidget {
  const PinnedTotalTitle(this.amount, {this.style, super.key});

  final Money amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => MoneyText(
    amount,
    style: style,
    color: amount.isNegative ? AppColors.expense : null,
    fractionScale: 0.62,
  );
}
