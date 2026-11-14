import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/tables.dart';
import '../../core/l10n/l10n.dart';

/// Every widget the Dashboard can show, in the built-in order. The ones up
/// to [recent] are the original dashboard and start on; the ones after it
/// start off, so nobody's dashboard changes until they add something.
///
/// The enum names are what [Settings.dashboardLayout] stores — never rename
/// one without mapping the old name in [parseDashboardLayout].
enum DashboardWidget {
  detected,
  totalMoney,
  thisMonth,
  accounts,
  readyToAssign,
  people,
  upcoming,
  budgets,
  spending,
  recent,
  cashFlow,
  goals,
  loans,
  shortcuts,
  groups,
  shopping,
}

extension DashboardWidgetX on DashboardWidget {
  bool get onByDefault => index <= DashboardWidget.recent.index;

  String get title => switch (this) {
    DashboardWidget.detected => tr('Detected transactions'),
    DashboardWidget.totalMoney => tr('Total money'),
    DashboardWidget.thisMonth => tr('Money in & out'),
    DashboardWidget.accounts => tr('Accounts'),
    DashboardWidget.readyToAssign => tr('Ready to Assign'),
    DashboardWidget.people => tr('People'),
    DashboardWidget.upcoming => tr('Upcoming'),
    DashboardWidget.budgets => tr('Budgets'),
    DashboardWidget.spending => tr('Spending'),
    DashboardWidget.recent => tr('Recent transactions'),
    DashboardWidget.cashFlow => tr('Cash flow'),
    DashboardWidget.goals => tr('Savings goals'),
    DashboardWidget.loans => tr('Loans'),
    DashboardWidget.shortcuts => tr('Shortcuts'),
    DashboardWidget.groups => tr('Groups'),
    DashboardWidget.shopping => tr('Shopping lists'),
  };

  String get description => switch (this) {
    DashboardWidget.detected => tr('Bank messages waiting for review'),
    DashboardWidget.totalMoney =>
      tr('Net worth, where the month began, and its trend'),
    DashboardWidget.thisMonth => tr('What came in and went out this month'),
    DashboardWidget.accounts => tr('Every account and its balance'),
    DashboardWidget.readyToAssign => tr('Money not yet given a job'),
    DashboardWidget.people => tr("Who owes you, and who you owe"),
    DashboardWidget.upcoming => tr('Reminders and Auto rules due soon'),
    DashboardWidget.budgets => tr('How full each budget is'),
    DashboardWidget.spending => tr('Where the month’s money went'),
    DashboardWidget.recent => tr('Your latest transactions'),
    DashboardWidget.cashFlow => tr('Six months of money in against money out'),
    DashboardWidget.goals => tr('How close each goal is'),
    DashboardWidget.loans => tr('What’s left to repay on each loan'),
    DashboardWidget.shortcuts => tr('Your Quick Actions, one tap away'),
    DashboardWidget.groups => tr('Where each shared group stands'),
    DashboardWidget.shopping => tr('Lists with items still to buy'),
  };

  IconData get icon => switch (this) {
    DashboardWidget.detected => Icons.mark_email_unread_outlined,
    DashboardWidget.totalMoney => Icons.account_balance_wallet_outlined,
    DashboardWidget.thisMonth => Icons.swap_vert_rounded,
    DashboardWidget.accounts => Icons.account_balance_outlined,
    DashboardWidget.readyToAssign => Icons.inbox_outlined,
    DashboardWidget.people => Icons.people_outline_rounded,
    DashboardWidget.upcoming => Icons.event_outlined,
    DashboardWidget.budgets => Icons.donut_large_rounded,
    DashboardWidget.spending => Icons.pie_chart_outline_rounded,
    DashboardWidget.recent => Icons.receipt_long_outlined,
    DashboardWidget.cashFlow => Icons.bar_chart_rounded,
    DashboardWidget.goals => Icons.savings_outlined,
    DashboardWidget.loans => Icons.request_quote_outlined,
    DashboardWidget.shortcuts => Icons.apps_rounded,
    DashboardWidget.groups => Icons.groups_outlined,
    DashboardWidget.shopping => Icons.shopping_cart_outlined,
  };

  /// Why this widget won't appear under the current mode, or null when it
  /// will. It keeps its place either way, so switching modes brings it back.
  String? unavailableNote({required AppMode mode, required bool rtaOn}) =>
      switch (this) {
        DashboardWidget.totalMoney ||
        DashboardWidget.accounts ||
        DashboardWidget.budgets when mode == AppMode.basic =>
          tr('Not shown in Basic mode'),
        DashboardWidget.readyToAssign when mode != AppMode.pro || !rtaOn =>
          tr('Shows in Pro mode with Ready to Assign on'),
        _ => null,
      };
}

/// One widget's place on the Dashboard.
typedef DashboardSlot = ({DashboardWidget widget, bool visible});

/// Reads [Settings.dashboardLayout]: ids top to bottom, `-` marking a hidden
/// one. Anything unreadable is skipped, a repeat keeps its first place, and
/// a widget the value doesn't name at all — every one, for the built-in
/// `''`, or one added in a later version — joins the end, on or off by its
/// own default. So every widget always appears exactly once.
List<DashboardSlot> parseDashboardLayout(String raw) {
  final byName = DashboardWidget.values.asNameMap();
  final out = <DashboardSlot>[];
  final seen = <DashboardWidget>{};
  for (final token in raw.split(',')) {
    final hidden = token.startsWith('-');
    final widget = byName[hidden ? token.substring(1) : token];
    if (widget == null || !seen.add(widget)) continue;
    out.add((widget: widget, visible: !hidden));
  }
  for (final widget in DashboardWidget.values) {
    if (seen.contains(widget)) continue;
    out.add((widget: widget, visible: widget.onByDefault));
  }
  return out;
}

/// The inverse of [parseDashboardLayout].
String encodeDashboardLayout(List<DashboardSlot> slots) => [
  for (final s in slots) s.visible ? s.widget.name : '-${s.widget.name}',
].join(',');

/// The built-in layout: the original dashboard, then everything else off.
final defaultDashboardLayout = parseDashboardLayout('');

/// The Dashboard's widgets, top to bottom — hidden ones included, so
/// Customize dashboard can offer them back.
final dashboardLayoutProvider = Provider<List<DashboardSlot>>(
  (ref) => parseDashboardLayout(
    ref.watch(settingsProvider).valueOrNull?.dashboardLayout ?? '',
  ),
);

/// [slots] with [widget] shown or hidden. A widget being added goes to the
/// bottom of what's shown, where the user is looking for it; a removed one
/// joins the hidden ones.
List<DashboardSlot> setDashboardWidgetVisible(
  List<DashboardSlot> slots,
  DashboardWidget widget, {
  required bool visible,
}) {
  final shown = [
    for (final s in slots)
      if (s.visible && s.widget != widget) s,
  ];
  final hidden = [
    for (final s in slots)
      if (!s.visible && s.widget != widget) s,
  ];
  // Last of the shown, or first of the hidden: the same place either way.
  return [...shown, (widget: widget, visible: visible), ...hidden];
}

/// [slots] with the shown widget at [oldIndex] (counting shown widgets only)
/// moved to [newIndex], in a reorderable list's `onReorder` convention —
/// where [newIndex] counts the dragged item still in place.
List<DashboardSlot> reorderDashboardWidgets(
  List<DashboardSlot> slots,
  int oldIndex,
  int newIndex,
) {
  final shown = [
    for (final s in slots)
      if (s.visible) s,
  ];
  final hidden = [
    for (final s in slots)
      if (!s.visible) s,
  ];
  if (newIndex > oldIndex) newIndex--;
  shown.insert(newIndex, shown.removeAt(oldIndex));
  return [...shown, ...hidden];
}
