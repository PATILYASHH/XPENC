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

// ── Per-widget options ────────────────────────────────────────────────────

/// One setting a Dashboard widget offers in its options sheet: a short
/// label and two or three [choices], value then label. The first choice is
/// the default — always the widget as it looked before options existed, so
/// nobody's dashboard changes until they pick something.
///
/// Values are what [Settings.dashboardWidgetOptions] stores: letters and
/// digits only. Never rename one without mapping the old value.
class DashboardOption {
  const DashboardOption(this.key, this.label, this.choices);

  final String key;
  final String label;
  final List<(String, String)> choices;

  String get defaultValue => choices.first.$1;

  /// [value] if it's one of [choices], else the default — so a value from
  /// a later version, or a hand-edited backup, never breaks a widget.
  String resolve(String? value) =>
      choices.any((c) => c.$1 == value) ? value! : defaultValue;

  String labelOf(String value) =>
      choices.firstWhere((c) => c.$1 == resolve(value)).$2;
}

/// `2 · 4 · All` style counts share their labels.
List<(String, String)> _counts(List<int> ns, {bool all = false}) => [
  for (final n in ns) ('$n', '$n'),
  if (all) ('all', tr('All')),
];

List<(String, String)> get _showHide => [
  ('show', tr('Show')),
  ('hide', tr('Hide')),
];

extension DashboardWidgetOptionsX on DashboardWidget {
  /// What this widget lets you change, in the order its sheet lists them.
  /// The Accounts widget's layout lives in its own column
  /// ([Settings.dashboardAccountsStyle]) and is offered beside these.
  List<DashboardOption> get options => switch (this) {
    DashboardWidget.detected => [
      DashboardOption('count', tr('Cards shown'), _counts([3, 1, 5])),
    ],
    DashboardWidget.totalMoney => [
      DashboardOption('chart', tr('Trend chart'), _showHide),
      DashboardOption('tabs', tr('Money in / out tabs'), _showHide),
      DashboardOption('details', tr('Opening & available'), _showHide),
    ],
    DashboardWidget.thisMonth => [
      DashboardOption('style', tr('Layout'), [
        ('tiles', tr('Tiles')),
        ('compact', tr('Compact')),
      ]),
      DashboardOption('bar', tr('Split bar'), _showHide),
      DashboardOption('net', tr('Saved / overspent'), _showHide),
    ],
    DashboardWidget.accounts => [
      DashboardOption('zero', tr('Accounts at zero'), _showHide),
      DashboardOption('total', tr('Total in the title'), [
        ('hide', tr('Hide')),
        ('show', tr('Show')),
      ]),
    ],
    DashboardWidget.readyToAssign => [
      DashboardOption('title', tr('Title'), _showHide),
    ],
    DashboardWidget.people => [
      DashboardOption('filter', tr('Show'), [
        ('all', tr('Everyone')),
        ('owesYou', tr('Owe you')),
        ('youOwe', tr('You owe')),
      ]),
      DashboardOption('count', tr('People'), _counts([4, 2, 8])),
      DashboardOption('summary', tr('Totals row'), _showHide),
    ],
    DashboardWidget.upcoming => [
      DashboardOption('days', tr('Look ahead'), [
        ('14', tr('2 weeks')),
        ('7', tr('1 week')),
        ('30', tr('1 month')),
      ]),
      DashboardOption('count', tr('Items'), _counts([5, 3, 10])),
    ],
    DashboardWidget.budgets => [
      DashboardOption('style', tr('Style'), [
        ('rings', tr('Rings')),
        ('bars', tr('Bars')),
      ]),
      DashboardOption('order', tr('Order'), [
        ('set', tr('As set')),
        ('fullest', tr('Fullest first')),
      ]),
    ],
    DashboardWidget.spending => [
      DashboardOption('show', tr('Show'), [
        ('both', tr('Chart & list')),
        ('chart', tr('Chart')),
        ('list', tr('List')),
      ]),
      DashboardOption('count', tr('Categories'), [
        ('all', tr('All')),
        ('5', tr('Top 5')),
        ('3', tr('Top 3')),
      ]),
    ],
    DashboardWidget.recent => [
      DashboardOption('count', tr('Transactions'), _counts([5, 3, 10])),
      DashboardOption('type', tr('Show'), [
        ('all', tr('All')),
        ('expense', tr('Money out')),
        ('income', tr('Money in')),
      ]),
    ],
    DashboardWidget.cashFlow => [
      DashboardOption('months', tr('Months'), _counts([6, 3, 12])),
    ],
    DashboardWidget.goals => [
      DashboardOption('count', tr('Goals'), _counts([4, 2], all: true)),
      DashboardOption('done', tr('Reached goals'), _showHide),
    ],
    DashboardWidget.loans => [
      DashboardOption('count', tr('Loans'), _counts([4, 2], all: true)),
      DashboardOption('paid', tr('Paid-off loans'), _showHide),
    ],
    DashboardWidget.shortcuts => [
      DashboardOption('columns', tr('Per row'), _counts([4, 3, 5])),
      DashboardOption('labels', tr('Labels'), _showHide),
    ],
    DashboardWidget.groups => [
      DashboardOption('filter', tr('Show'), [
        ('all', tr('All')),
        ('get', tr('You get back')),
        ('owe', tr('You owe')),
      ]),
      DashboardOption('count', tr('Groups'), _counts([4, 2], all: true)),
    ],
    DashboardWidget.shopping => [
      DashboardOption('count', tr('Lists'), _counts([4, 2], all: true)),
    ],
  };

  DashboardOption? optionFor(String key) {
    for (final o in options) {
      if (o.key == key) return o;
    }
    return null;
  }
}

/// Every widget's picked options — only the ones set away from default.
typedef DashboardOptions = Map<DashboardWidget, Map<String, String>>;

/// Reads [Settings.dashboardWidgetOptions]: `widget.key=value`,
/// comma-joined. Anything unreadable, an unknown widget or key, or a value
/// that's no longer a choice is skipped — that widget just shows its
/// default for it.
DashboardOptions parseDashboardOptions(String raw) {
  final byName = DashboardWidget.values.asNameMap();
  final out = <DashboardWidget, Map<String, String>>{};
  for (final item in raw.split(',')) {
    final eq = item.indexOf('=');
    final dot = item.indexOf('.');
    if (dot <= 0 || eq <= dot + 1 || eq == item.length - 1) continue;
    final widget = byName[item.substring(0, dot)];
    final option = widget?.optionFor(item.substring(dot + 1, eq));
    final value = item.substring(eq + 1);
    if (option == null || option.resolve(value) != value) continue;
    if (value == option.defaultValue) continue;
    (out[widget!] ??= {})[option.key] = value;
  }
  return out;
}

/// The inverse of [parseDashboardOptions]. Defaults are left out.
String encodeDashboardOptions(DashboardOptions options) => [
  for (final w in DashboardWidget.values)
    for (final o in w.options)
      if (options[w]?[o.key] case final v?
          when v != o.defaultValue && o.resolve(v) == v)
        '${w.name}.${o.key}=$v',
].join(',');

/// [options] with [widget]'s [key] set to [value] (the default removes it).
DashboardOptions setDashboardOption(
  DashboardOptions options,
  DashboardWidget widget,
  String key,
  String value,
) {
  final next = {
    for (final e in options.entries) e.key: {...e.value},
  };
  final mine = next[widget] ??= {};
  final option = widget.optionFor(key);
  if (option == null || value == option.defaultValue) {
    mine.remove(key);
  } else {
    mine[key] = option.resolve(value);
  }
  if (mine.isEmpty) next.remove(widget);
  return next;
}

/// Every widget's options, as stored.
final dashboardOptionsProvider = Provider<DashboardOptions>(
  (ref) => parseDashboardOptions(
    ref.watch(settingsProvider).valueOrNull?.dashboardWidgetOptions ?? '',
  ),
);

/// [widget]'s value for [key] — the picked one, or its default.
String dashboardOptionOf(
  DashboardOptions options,
  DashboardWidget widget,
  String key,
) => widget.optionFor(key)?.resolve(options[widget]?[key]) ?? '';

extension DashboardOptionRef on WidgetRef {
  /// Watches [widget]'s value for [key] — see [dashboardOptionOf].
  String dashOption(DashboardWidget widget, String key) =>
      dashboardOptionOf(watch(dashboardOptionsProvider), widget, key);

  /// A count option as a number, or null for `all`.
  int? dashCount(DashboardWidget widget, [String key = 'count']) =>
      int.tryParse(dashOption(widget, key));

  /// A show/hide option as a bool.
  bool dashShown(DashboardWidget widget, String key) =>
      dashOption(widget, key) != 'hide';
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
