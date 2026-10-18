import 'package:flutter/material.dart';

import '../../data/database.dart';

/// The More modules a mode can show while it's the focus (see
/// `Modes.modules`). Keys are stored, so never rename one.
class ModeModule {
  const ModeModule(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;

  static const all = <ModeModule>[
    ModeModule('accounts', 'Accounts', Icons.account_balance_wallet_outlined),
    ModeModule('transactions', 'Transactions', Icons.receipt_long_outlined),
    ModeModule('persons', 'Persons', Icons.people_alt_outlined),
    ModeModule('budgets', 'Budgets', Icons.donut_large_rounded),
    ModeModule('auto', 'Auto', Icons.autorenew_rounded),
    ModeModule('payees', 'Payees', Icons.storefront_outlined),
    ModeModule('goals', 'Goals & Loans', Icons.savings_outlined),
    ModeModule('shopping', 'Shopping List', Icons.checklist_outlined),
    ModeModule(
      'calendar',
      'Calendar & Reminders',
      Icons.calendar_month_outlined,
    ),
    ModeModule('stats', 'Stats', Icons.insights_outlined),
    ModeModule('reports', 'Account Reports', Icons.account_balance_outlined),
    ModeModule('calculators', 'Calculators', Icons.calculate_outlined),
    ModeModule('data', 'Download & Backup', Icons.backup_outlined),
    ModeModule('setup', 'Categories & Tags', Icons.category_outlined),
  ];

  static final keys = {for (final m in all) m.key};
}

/// The modules [mode] shows while focused. Empty storage means all of them;
/// a key from a newer build is ignored.
Set<String> modeModuleKeys(ModeRow mode) {
  final raw = mode.modules.trim();
  if (raw.isEmpty) return {...ModeModule.keys};
  return {
    for (final k in raw.split(','))
      if (ModeModule.keys.contains(k.trim())) k.trim(),
  };
}

/// [keys] as stored — empty when it's every module.
String encodeModeModules(Set<String> keys) {
  if (keys.containsAll(ModeModule.keys)) return '';
  return [
    for (final m in ModeModule.all)
      if (keys.contains(m.key)) m.key,
  ].join(',');
}

/// A starting point for a new mode.
class ModePreset {
  const ModePreset({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.modules,
    this.navSlots,
  });

  final String key;
  final String title;
  final String subtitle;
  final String name;
  final String iconKey;
  final int colorValue;
  final Set<String> modules;
  final String? navSlots;

  static const trip = ModePreset(
    key: 'trip',
    title: 'Trip',
    subtitle: 'Travel spends, split with friends, abroad or at home',
    name: 'Trip',
    iconKey: 'luggage',
    colorValue: 0xFF0EA5E9,
    modules: {'accounts', 'transactions', 'persons', 'shopping', 'calculators'},
    navSlots: 'transactions,persons',
  );

  static const blank = ModePreset(
    key: 'blank',
    title: 'Blank',
    subtitle: 'A wedding, a festival, a move — set it up your way',
    name: '',
    iconKey: 'festival',
    colorValue: 0xFFA855F7,
    modules: {},
  );

  static const all = [trip, blank];

  static ModePreset byKey(String? key) =>
      all.where((p) => p.key == key).firstOrNull ?? blank;
}
