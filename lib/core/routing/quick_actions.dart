import 'package:flutter/material.dart';

import '../../data/database.dart' show TransactionTemplateRow;
import '../../data/tables.dart' show AppMode, TxType;
import '../../features/calculators/calculator_kind.dart';
import '../widgets/money_text.dart' show iconForTxType;
import '../../core/l10n/l10n.dart';

/// The hold-➕ radial menu's 8 slots — one ball per compass direction around
/// a fixed ✕ (cancel) in the middle. Slot `i` sits at [holdMenuSlotAngles]
/// `[i]`: 0 = straight up, then clockwise in 45° steps.
const holdMenuSlotCount = 8;

/// Degrees, screen convention (0° = right, clockwise, so -90° is straight
/// up) — index-aligned with the stored `Settings.holdMenuSlots` list.
const holdMenuSlotAngles = <double>[
  -90, // up
  -45, // up-right
  0, // right
  45, // down-right
  90, // down
  135, // down-left
  180, // left
  -135, // up-left
];

/// Short direction name per slot, for the settings screen's picker title.
const holdMenuSlotDirections = <String>[
  'Up',
  'Up-right',
  'Right',
  'Down-right',
  'Down',
  'Down-left',
  'Left',
  'Up-left',
];

/// Stored-id prefix for a transaction-template slot: `template:<rowId>`.
const quickActionTemplatePrefix = 'template:';

/// One pickable quick action — a module screen, a calculator, a prefilled
/// Add Transaction, or a saved template. [route] is always a full pushed
/// route (never `goBranch`), same reasoning as the old 3-slot menu: the
/// full `/more/*` route carries every action its embedded tab may lack.
class QuickActionSpec {
  const QuickActionSpec({
    required this.id,
    required String label,
    required this.icon,
    required this.route,
    String group = 'Modules',
    this.hiddenInBasic = false,
    this.indiaOnly = false,
  }) : _label = label, _group = group;

  final String id;
  final String _label;
  String get label => tr(_label);

  /// [label] before translation — global search matches both.
  String get englishLabel => _label;
  final IconData icon;
  final String route;

  /// Section heading in the settings picker.
  final String _group;
  String get group => tr(_group);
  String get englishGroup => _group;

  /// Basic mode has no budgets — a slot pointing there resolves to empty
  /// while Basic is active (the stored id is kept, so switching back
  /// restores it), mirroring `basicModeHiddenCatalogIds`.
  final bool hiddenInBasic;

  /// India-only (GST, PPF): a slot pointing there resolves to empty where
  /// India's tools aren't offered — see `indiaToolsFor`. The stored id is
  /// kept, as with [hiddenInBasic].
  final bool indiaOnly;
}

/// The global search (GitHub #209) as a quick action — it is also what a
/// hold on ➕ opens when the radial menu is off.
const searchQuickActionId = 'search';

/// Every non-template quick action, in picker order. Ids for the modules
/// that the old 3-slot menu offered (`transactions`, `persons`, `calendar`,
/// `budgets`, `accounts`, `stats`, `payees`) are deliberately unchanged, so
/// a stored pre-radial value still resolves.
final List<QuickActionSpec> quickActionCatalog = [
  const QuickActionSpec(
    id: searchQuickActionId,
    label: 'Search',
    icon: Icons.search_rounded,
    route: '/search',
  ),
  QuickActionSpec(
    id: 'add-expense',
    label: 'Add money out',
    icon: iconForTxType(TxType.expense),
    route: '/add?type=expense',
    group: 'Add',
  ),
  QuickActionSpec(
    id: 'add-income',
    label: 'Add money in',
    icon: iconForTxType(TxType.income),
    route: '/add?type=income',
    group: 'Add',
  ),
  // "34 supermarket" and it's saved (GitHub #213).
  const QuickActionSpec(
    id: 'type-it',
    label: 'Type it',
    icon: Icons.keyboard_alt_outlined,
    route: '/type',
    group: 'Add',
  ),
  const QuickActionSpec(
    id: 'transactions',
    label: 'Transactions',
    icon: Icons.receipt_long_rounded,
    route: '/more/transactions',
  ),
  const QuickActionSpec(
    id: 'accounts',
    label: 'Accounts',
    icon: Icons.account_balance_wallet_rounded,
    route: '/more/accounts',
  ),
  const QuickActionSpec(
    id: 'persons',
    label: 'Persons',
    icon: Icons.people_alt_rounded,
    route: '/more/persons',
  ),
  const QuickActionSpec(
    id: 'budgets',
    label: 'Budgets',
    icon: Icons.donut_large_rounded,
    route: '/more/budgets',
    hiddenInBasic: true,
  ),
  const QuickActionSpec(
    id: 'auto',
    label: 'Auto',
    icon: Icons.autorenew_rounded,
    route: '/more/auto',
  ),
  const QuickActionSpec(
    id: 'payees',
    label: 'Payees',
    icon: Icons.storefront_rounded,
    route: '/more/payees',
  ),
  const QuickActionSpec(
    id: 'goals',
    label: 'Goals & Loans',
    icon: Icons.savings_rounded,
    route: '/more/goals',
  ),
  const QuickActionSpec(
    id: 'shopping',
    label: 'Shopping List',
    icon: Icons.checklist_rounded,
    route: '/more/shopping',
  ),
  const QuickActionSpec(
    id: 'calendar',
    label: 'Calendar',
    icon: Icons.calendar_month_rounded,
    route: '/more/calendar',
  ),
  const QuickActionSpec(
    id: 'stats',
    label: 'Stats',
    icon: Icons.insights_rounded,
    route: '/more/stats',
  ),
  const QuickActionSpec(
    id: 'calculations',
    label: 'Calculations',
    icon: Icons.calculate_rounded,
    route: '/more/calculations',
  ),
  const QuickActionSpec(
    id: 'account-reports',
    label: 'Account Reports',
    icon: Icons.account_balance_rounded,
    route: '/more/account-reports',
  ),
  const QuickActionSpec(
    id: 'categories',
    label: 'Categories',
    icon: Icons.category_rounded,
    route: '/more/categories',
  ),
  const QuickActionSpec(
    id: 'tags',
    label: 'Tags',
    icon: Icons.sell_rounded,
    route: '/more/tags',
  ),
  const QuickActionSpec(
    id: 'backup',
    label: 'Backup',
    icon: Icons.backup_rounded,
    route: '/more/backup',
  ),
  const QuickActionSpec(
    id: 'export',
    label: 'Download Data',
    icon: Icons.download_rounded,
    route: '/more/export',
  ),
  const QuickActionSpec(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_rounded,
    route: '/more/settings',
  ),
  for (final kind in CalculatorKind.values)
    QuickActionSpec(
      id: 'calc-${kind.name}',
      label: kind.label,
      icon: kind.icon,
      route: kind.route,
      group: 'Calculations',
      indiaOnly: kind.indiaOnly,
    ),
];

final Map<String, QuickActionSpec> _catalogById = {
  for (final spec in quickActionCatalog) spec.id: spec,
};

/// Resolves one stored slot id to what the menu should show, or `null` for
/// an empty slot — including one whose id no longer resolves (a deleted
/// template, an unknown id from a future/older build) or is hidden in the
/// current [mode], or is India-only and [indiaTools] is off.
QuickActionSpec? resolveQuickAction(
  String id, {
  required List<TransactionTemplateRow> templates,
  required AppMode mode,
  bool indiaTools = true,
}) {
  if (id.isEmpty) return null;
  if (id.startsWith(quickActionTemplatePrefix)) {
    final templateId = int.tryParse(
      id.substring(quickActionTemplatePrefix.length),
    );
    for (final t in templates) {
      if (t.id == templateId) {
        return QuickActionSpec(
          id: id,
          label: t.name,
          icon: iconForTxType(t.type),
          route: '/add?template=${t.id}',
          group: tr('Templates'),
        );
      }
    }
    return null;
  }
  final spec = _catalogById[id];
  if (spec == null) return null;
  if (spec.hiddenInBasic && mode == AppMode.basic) return null;
  if (spec.indiaOnly && !indiaTools) return null;
  return spec;
}

/// Parses the stored `Settings.holdMenuSlots` into exactly
/// [holdMenuSlotCount] ids (`''` = empty). A pre-radial 3-item value
/// (`left-up,up,right-up` from the old upward fan) is carried over into the
/// matching upper slots of the ring, so an existing setup survives the
/// upgrade without a migration.
List<String> parseHoldMenuSlots(String raw) {
  final parts = raw.split(',');
  if (parts.length == holdMenuSlotCount) return parts;
  if (parts.length == 3) {
    final slots = List.filled(holdMenuSlotCount, '');
    slots[7] = parts[0]; // old -150° → up-left
    slots[0] = parts[1]; // old  -90° → up
    slots[1] = parts[2]; // old  -30° → up-right
    return slots;
  }
  return List.filled(holdMenuSlotCount, '');
}

/// What Reset puts back — the value `Settings.holdMenuSlots` defaults to.
const defaultHoldMenuSlotsRaw = 'calendar,budgets,stats';

/// Puts [id] in slot [index]. If it already sits in another slot, the two
/// trade places, so an action is never in the menu twice — the bottom-bar
/// editor's rule.
List<String> placeQuickAction(List<String> slots, int index, String id) {
  final next = List.of(slots);
  final from = next.indexOf(id);
  if (from == index) return next;
  if (from != -1) next[from] = next[index];
  next[index] = id;
  return next;
}

/// The slots Glass's corner fan shows while it's being edited, in fan
/// order: every filled one ([filled] is index-aligned with the 8 slots) and
/// the first free one, as the "+" to add with — none once all are taken.
List<int> glassEditableSlots(List<bool> filled) {
  final firstFree = filled.indexOf(false);
  return [
    for (var i = 0; i < filled.length; i++)
      if (filled[i] || i == firstFree) i,
  ];
}
