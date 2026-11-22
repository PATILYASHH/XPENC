/// The bottom bar's four tab slots (the ➕ is separate and never moves).
///
/// Stored in `Settings.bottomNavSlots` as four comma-joined ids, e.g.
/// `dashboard,transactions,persons,more`. Older builds stored just the two
/// middle slots (`transactions,persons`), with Dashboard and More pinned at
/// the ends; that form still reads back as exactly that layout. An older
/// build reading the four-id form falls back to its own default, so a
/// backup restored across versions never breaks the bar.
///
/// Every id is used at most once, and More must stay on the bar: it's the
/// way into Settings and everything that has no tab of its own.
library;

/// Every module a slot can hold, in the order the editor lists them.
const bottomNavModuleIds = <String>[
  'dashboard',
  'transactions',
  'persons',
  'calendar',
  'budgets',
  'accounts',
  'stats',
  'payees',
  'more',
];

/// Each module's name (English; shown through `tr`).
const bottomNavModuleLabels = <String, String>{
  'dashboard': 'Dashboard',
  'transactions': 'Transactions',
  'persons': 'Persons',
  'calendar': 'Calendar',
  'budgets': 'Budgets',
  'accounts': 'Accounts',
  'stats': 'Stats',
  'payees': 'Payees',
  'more': 'More',
};

/// The id that can never leave the bar.
const bottomNavRequiredId = 'more';

const defaultBottomNavLayout = <String>[
  'dashboard',
  'transactions',
  'persons',
  'more',
];

/// Modules Basic mode has nothing to show for (no budgets, no net worth).
const _basicHidden = {'budgets', 'accounts'};

/// What fills a slot Basic mode can't show, first unused wins.
const _basicFallbacks = [
  'transactions',
  'persons',
  'calendar',
  'stats',
  'payees',
  'dashboard',
];

/// Null when [ids] is a layout the bar can show, else why not.
String? bottomNavLayoutProblem(List<String> ids) {
  if (ids.length != 4) return 'needs four slots';
  if (ids.any((id) => !bottomNavModuleIds.contains(id))) return 'unknown id';
  if (ids.toSet().length != 4) return 'an id is used twice';
  if (!ids.contains(bottomNavRequiredId)) return 'More must stay on the bar';
  return null;
}

/// The four ids to show for a stored [raw] value. Anything that doesn't
/// parse falls back to [defaultBottomNavLayout]; in [basic] mode a slot
/// holding a module Basic hides shows a stand-in instead — the stored value
/// is left alone, so switching back restores it.
List<String> resolveBottomNavLayout(String? raw, {bool basic = false}) {
  final parts = (raw ?? '').split(',');
  var ids = defaultBottomNavLayout;
  if (parts.length == 2) {
    final legacy = ['dashboard', parts[0], parts[1], 'more'];
    if (bottomNavLayoutProblem(legacy) == null) ids = legacy;
  } else if (bottomNavLayoutProblem(parts) == null) {
    ids = parts;
  }
  if (!basic || !ids.any(_basicHidden.contains)) return List.of(ids);
  final out = List.of(ids);
  for (var i = 0; i < out.length; i++) {
    if (!_basicHidden.contains(out[i])) continue;
    out[i] = _basicFallbacks.firstWhere((f) => !out.contains(f));
  }
  return out;
}

/// [layout] with slot [slot] set to [id]. If [id] is already in another
/// slot, the two swap, so each module stays on the bar once. Null when the
/// change would take More off the bar.
List<String>? pickBottomNavModule(List<String> layout, int slot, String id) {
  final out = List.of(layout);
  final previous = out[slot];
  if (previous == id) return out;
  final other = out.indexOf(id);
  if (other >= 0) {
    out[other] = previous;
  } else if (previous == bottomNavRequiredId) {
    return null;
  }
  out[slot] = id;
  return out;
}
