# Customizable Bottom Nav Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user swap the two bottom-nav slots that flank the ➕ button (today: Transactions, Persons) for any of 7 catalog destinations, while Dashboard and More stay permanently pinned — resolving GitHub #70.

**Architecture:** Every catalog destination becomes a real `StatefulShellBranch` at a fixed, permanent branch index (so existing index-based logic never breaks), with a new `Settings.bottomNavSlots` column (`"transactions,persons"`-style text) picking which 2 of the 7 are currently visible and in which bar position. `AppShell` resolves the two configurable slots from that setting through a small static catalog map; everything else (Dashboard, More, the ➕ button) is untouched. Five screens (`CalendarScreen`, `BudgetsScreen`, `StatsScreen`, `AccountsScreen`, `PayeesScreen`) gain an `embedded` constructor flag so they can drop their own app bar when used as a tab, while their existing pushed (`/more/*`) routes keep rendering exactly as they do today.

**Tech Stack:** Flutter, Riverpod, go_router (`StatefulShellRoute.indexedStack`), Drift (SQLite).

**Correction vs. the design spec:** the spec (`docs/superpowers/specs/2026-08-23-customizable-bottom-nav-design.md`) assumed `AccountsScreen`/`PayeesScreen` already had no app bar and needed no change. On inspection both actually render their own `SliverAppBar` inside a `CustomScrollView` (not `Scaffold.appBar`, which is why an earlier grep for `appBar:` missed it) — so all 5 catalog screens beyond Dashboard/Transactions/Persons/More need the same `embedded` treatment, not just 3. This plan implements the corrected 5-screen version; the underlying feature and data model are unchanged from the spec.

**Simplification vs. the spec:** rather than detecting "the branch I'm currently on just became invisible" live inside `AppShell`, the new Settings screen simply navigates to `/dashboard` unconditionally right after saving a change — same end result (never left stranded on a hidden tab), much less code.

---

## File structure

| File | Change |
|---|---|
| `lib/data/tables.dart` | +1 column: `Settings.bottomNavSlots` |
| `lib/data/database.dart` | +1 migration step, +1 setter: `setBottomNavSlots` |
| `lib/data/providers.dart` | +2 signal providers for Calendar's top-bar actions |
| `lib/features/calendar/calendar_screen.dart` | +`embedded` param; listens to the 2 new signals instead of owning its own AppBar actions when embedded |
| `lib/features/budgets/budgets_screen.dart` | +`embedded` param |
| `lib/features/reports/stats_screen.dart` | +`embedded` param |
| `lib/features/accounts/accounts_screen.dart` | +`embedded` param |
| `lib/features/payees/payees_screen.dart` | +`embedded` param |
| `lib/core/routing/app_router.dart` | +5 new top-level `StatefulShellBranch`es |
| `lib/core/routing/app_shell.dart` | Catalog map, dynamic slot resolution, 9-case `_TopBar` switch |
| `lib/features/settings/bottom_nav_settings_screen.dart` | **New.** The "Customize bottom nav" screen + picker sheet |
| `lib/features/more/more_screen.dart` | +1 tile, +1 route |
| `test/bottom_nav_slots_test.dart` | **New.** `setBottomNavSlots` validation + migration |
| `test/bottom_nav_customization_test.dart` | **New.** End-to-end: change a slot, see the bar update, see the new tab render |

---

## Task 1: `Settings.bottomNavSlots` column + setter

**Files:**
- Modify: `lib/data/tables.dart:406-540` (the `Settings` table)
- Modify: `lib/data/database.dart:166` (`schemaVersion`), `:329-332` (`onUpgrade`), `~3065` (near `setHideAmounts`)
- Test: `test/bottom_nav_slots_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/bottom_nav_slots_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('defaults to transactions,persons', () async {
    expect((await db.getSettings()).bottomNavSlots, 'transactions,persons');
  });

  test('setBottomNavSlots persists a valid pair', () async {
    await db.setBottomNavSlots('calendar', 'budgets');
    expect((await db.getSettings()).bottomNavSlots, 'calendar,budgets');
  });

  test('rejects an id outside the catalog', () async {
    expect(
      () => db.setBottomNavSlots('nonsense', 'persons'),
      throwsArgumentError,
    );
  });

  test('rejects the same id in both slots', () async {
    expect(
      () => db.setBottomNavSlots('calendar', 'calendar'),
      throwsArgumentError,
    );
  });

  test('rejects a pinned id (dashboard/more are not choosable)', () async {
    expect(
      () => db.setBottomNavSlots('dashboard', 'persons'),
      throwsArgumentError,
    );
    expect(
      () => db.setBottomNavSlots('transactions', 'more'),
      throwsArgumentError,
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/bottom_nav_slots_test.dart`
Expected: fails to compile — `getSettings()` has no `bottomNavSlots` field yet, and `setBottomNavSlots` doesn't exist.

- [ ] **Step 3: Add the column**

In `lib/data/tables.dart`, inside `class Settings extends Table` (right after the `hideAmounts` column, before the closing `@override Set<Column> get primaryKey`):

```dart
  /// Which of the 7 catalog destinations occupy the two configurable
  /// bottom-nav slots flanking the ➕ button — left, then right. Dashboard
  /// and More are pinned and never appear here (see `AppShell`'s
  /// `BottomNavCatalog`). GitHub #70.
  TextColumn get bottomNavSlots =>
      text().withDefault(const Constant('transactions,persons'))();
```

- [ ] **Step 4: Regenerate Drift code immediately**

`SettingsCompanion` (used by Step 6 below) is generated from the table definition — regenerate now, before writing any code that references the new field, so nothing tries to compile against a stale `database.g.dart`.

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0; `lib/data/database.g.dart` picks up the new column.

- [ ] **Step 5: Bump the schema version and add the migration step**

In `lib/data/database.dart`, change:

```dart
  int get schemaVersion => 33;
```

to:

```dart
  int get schemaVersion => 34;
```

Then, in the `onUpgrade` migration (right after the `if (from < 33) { await m.createTable(transactionLinks); }` block, matching the existing one-step-per-version style):

```dart
      if (from < 34) {
        await _addColumnIfMissing(m, settings, settings.bottomNavSlots);
      }
```

- [ ] **Step 6: Add the catalog constant and the setter**

In `lib/data/database.dart`, near `setHideAmounts` (around line 3063):

```dart
  /// The 7 destinations a configurable bottom-nav slot can hold — Dashboard
  /// and More are pinned and deliberately excluded (see GitHub #70's design
  /// spec, "Non-goals").
  static const bottomNavCatalogIds = {
    'transactions',
    'persons',
    'calendar',
    'budgets',
    'accounts',
    'stats',
    'payees',
  };

  Future<void> setBottomNavSlots(String left, String right) async {
    if (!bottomNavCatalogIds.contains(left) ||
        !bottomNavCatalogIds.contains(right)) {
      throw ArgumentError('Unknown bottom-nav item.');
    }
    if (left == right) {
      throw ArgumentError('The two bottom-nav slots must be different.');
    }
    await update(
      settings,
    ).write(SettingsCompanion(bottomNavSlots: Value('$left,$right')));
  }
```

- [ ] **Step 7: Run it and watch it pass**

Run: `flutter test test/bottom_nav_slots_test.dart`
Expected: `All tests passed!`

- [ ] **Step 8: Full analyze + test sanity check**

Run: `flutter analyze lib/data/tables.dart lib/data/database.dart test/bottom_nav_slots_test.dart`
Expected: `No issues found!`

Run: `flutter test test/migration_version_drift_test.dart`
Expected: passes (confirms `schemaVersion`/migration steps stay in lockstep with the drift-generated schema — see that test file's own doc comment if it fails).

- [ ] **Step 9: Commit**

```bash
git add lib/data/tables.dart lib/data/database.dart lib/data/database.g.dart test/bottom_nav_slots_test.dart
git commit -m "feat(db): add Settings.bottomNavSlots for customizable bottom nav (#70)"
```

---

## Task 2: Calendar — signal providers + `embedded` mode

`CalendarScreen` currently owns `AppBar(title: 'Calendar', actions: [Today, New reminder])`. As a tab, the shared `_TopBar` (in `app_shell.dart`) owns the title/actions instead — but `_TopBar` is a sibling of `CalendarScreen`, not its parent, so it can't call `_goToToday`/`_openReminderSheet` directly. Two Riverpod "signal" providers (an incrementing int, exactly like the existing `txScrollToTopProvider` — see `lib/data/providers.dart:155` and its use in `app_shell.dart:42` / `transactions_screen.dart:124`) carry the tap across that boundary.

**Files:**
- Modify: `lib/data/providers.dart` (near `txScrollToTopProvider`)
- Modify: `lib/features/calendar/calendar_screen.dart:1-182` (imports, class doc, `build`)
- Test: `test/calendar_embedded_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/calendar_embedded_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/calendar/calendar_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('embedded: false (default) still shows its own app bar', (
    tester,
  ) async {
    await pump(tester, const CalendarScreen());
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(AppBar, 'Calendar'), findsOneWidget);
  });

  testWidgets('embedded: true renders no app bar of its own', (tester) async {
    await pump(tester, const CalendarScreen(embedded: true));
    expect(tester.takeException(), isNull);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets(
    'embedded: true still opens the reminder sheet when the signal fires',
    (tester) async {
      final container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const CalendarScreen(embedded: true),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      container.read(calendarNewReminderSignalProvider.notifier).state++;
      await tester.pump();

      expect(find.text('New reminder'), findsOneWidget);
    },
  );
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/calendar_embedded_test.dart`
Expected: fails to compile — `CalendarScreen` has no `embedded` parameter, `calendarNewReminderSignalProvider` doesn't exist.

- [ ] **Step 3: Add the two signal providers**

In `lib/data/providers.dart`, right after `txScrollToTopProvider` (line 155):

```dart
/// Bumped by `AppShell`'s top bar when Calendar is the active tab and its
/// "Today" action is tapped — `CalendarScreen` listens and jumps to today.
/// The value itself is meaningless, only the change matters, same idiom as
/// `txScrollToTopProvider` above (GitHub #70).
final calendarGoToTodaySignalProvider = StateProvider<int>((ref) => 0);

/// Same idiom, for the "New reminder" action.
final calendarNewReminderSignalProvider = StateProvider<int>((ref) => 0);
```

- [ ] **Step 4: Give `CalendarScreen` an `embedded` flag and split its body from its chrome**

Replace the whole of `lib/features/calendar/calendar_screen.dart`'s class header and `build` method (lines 20-182) with:

```dart
/// A month calendar built by hand (no calendar package). Each day cell shows the
/// money in / out for that day and a dot when an open reminder falls on it.
/// Tapping a day reveals its reminders and transactions below the grid.
///
/// This screen keeps its own shown month in [State]; it deliberately never
/// touches [selectedMonthProvider] so it stays independent of the rest of the app.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then, reached via
/// [calendarGoToTodaySignalProvider]/[calendarNewReminderSignalProvider]
/// rather than this widget's own `AppBar`. Default `false` keeps every
/// existing `/more/calendar` push exactly as it was.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// First day of the month currently on screen.
  late DateTime _shownMonth;

  /// The tapped day, or `null` when nothing is selected.
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _shownMonth = DateTime(now.year, now.month, 1);
    _selectedDay = _dateOnly(now);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _onCurrentMonth {
    final now = DateTime.now();
    return _shownMonth.year == now.year && _shownMonth.month == now.month;
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _shownMonth = DateTime(now.year, now.month, 1);
      _selectedDay = _dateOnly(now);
    });
  }

  void _stepMonth(int delta) {
    setState(() {
      _shownMonth = DateTime(_shownMonth.year, _shownMonth.month + delta, 1);
      // Selection belongs to whatever month it was made in; drop it on navigation.
      _selectedDay = null;
    });
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _confirmMarkPaid(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as paid'),
        content: const Text(
          'This will not post anything by itself. '
          'Confirm to record the transaction.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dbProvider).setReminderStatus(id, ReminderStatus.done);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update reminder')),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          "Marked done — add the transaction from + when you're ready.",
        ),
      ),
    );
  }

  Future<void> _deleteReminder(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dbProvider).deleteReminder(id);
      messenger.showSnackBar(const SnackBar(content: Text('Reminder deleted')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete reminder')),
      );
    }
  }

  void _openReminderSheet() {
    final initial = _selectedDay ?? _dateOnly(DateTime.now());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderSheet(initialDate: initial),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txAsync = ref.watch(allTransactionsProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final accountMap = ref.watch(accountMapProvider);
    final openReminders = ref.watch(openRemindersProvider);
    final recurringRules =
        ref.watch(recurringRulesProvider).valueOrNull ?? const [];

    if (widget.embedded) {
      ref.listen<int>(calendarGoToTodaySignalProvider, (_, _) => _goToToday());
      ref.listen<int>(
        calendarNewReminderSignalProvider,
        (_, _) => _openReminderSheet(),
      );
    }

    final body = txAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load calendar.\n$e',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
      data: (txns) => _content(
        theme,
        txns,
        categoryMap,
        accountMap,
        openReminders,
        recurringRules,
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          if (!_onCurrentMonth)
            IconButton(
              tooltip: 'Today',
              icon: const Icon(Icons.today_rounded),
              onPressed: _goToToday,
            ),
          IconButton(
            tooltip: 'New reminder',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openReminderSheet,
          ),
        ],
      ),
      body: body,
    );
  }
```

(Everything below `build` — `_content` through the end of the file — is unchanged.)

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/calendar_embedded_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Confirm the existing Calendar tests still pass**

Run: `flutter test test/screens_smoke_test.dart test/calendar_due_rule_test.dart`
Expected: `All tests passed!` (both construct `const CalendarScreen()` with no args, which still defaults `embedded` to `false`.)

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/features/calendar/calendar_screen.dart lib/data/providers.dart test/calendar_embedded_test.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/data/providers.dart lib/features/calendar/calendar_screen.dart test/calendar_embedded_test.dart
git commit -m "feat(calendar): add embedded mode for the customizable bottom nav (#70)"
```

---

## Task 3: Budgets — `embedded` mode

**Files:**
- Modify: `lib/features/budgets/budgets_screen.dart:41-77` (`BudgetsScreen` class header + `build`)
- Test: `test/budgets_embedded_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/budgets_embedded_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/budgets/budgets_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('embedded: false (default) still shows its own app bar', (
    tester,
  ) async {
    await pump(tester, const BudgetsScreen());
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(AppBar, 'Budgets'), findsOneWidget);
  });

  testWidgets('embedded: true renders no app bar of its own', (tester) async {
    await pump(tester, const BudgetsScreen(embedded: true));
    expect(tester.takeException(), isNull);
    expect(find.byType(AppBar), findsNothing);
    // The body itself still renders.
    expect(find.text('Categories'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/budgets_embedded_test.dart`
Expected: fails to compile — no `embedded` parameter.

- [ ] **Step 3: Swap the now-unused `go_router` import**

`_openDetail` (changed in Step 4 below) is the only thing in this file using `context.push`, a `go_router` extension — once it's gone, that import is unused and `flutter analyze` will flag it. In `lib/features/budgets/budgets_screen.dart`, replace:

```dart
import 'package:go_router/go_router.dart';
```

with:

```dart
import '../../core/routing/app_router.dart' show appRouter;
```

- [ ] **Step 4: Add `embedded` and split the Scaffold**

Replace `lib/features/budgets/budgets_screen.dart` lines 41-77 (the class header through the end of the `Scaffold(` opening/`appBar:` block, i.e. everything up to `body: categoriesAsync.when(`) with:

```dart
/// Per-category spending limits for the selected month. Only expenses count —
/// transfers between your own accounts are never budgeted.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then. Default `false`
/// keeps `/more/budgets` exactly as it was.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final categoriesAsync = ref.watch(categoriesProvider(CategoryKind.expense));
    final progress = ref.watch(budgetProgressProvider);
    final progressById = {for (final p in progress) p.category.id: p};

    var totalBudgeted = const Money.zero();
    var totalSpent = const Money.zero();
    for (final p in progress) {
      // A child's budget is a sub-allocation within its parent's cap, and a
      // budgeted parent's `spent` already rolls up every child's — when the
      // parent is budgeted too, counting the child's line again would double
      // both figures (Food 2000 + Junk food 1000 + Dinner 1000 must read as
      // 2000, not 4000).
      final parentId = p.category.parentId;
      if (parentId != null && progressById.containsKey(parentId)) continue;
      totalBudgeted += p.budget.amount;
      totalSpent += p.spent;
    }

    if (embedded) {
      return categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load budgets.\n$e',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
            ),
          ),
        ),
        data: (categories) =>
            _body(theme, cs, categories, progressById, totalBudgeted, totalSpent),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download budget statement',
            onPressed: () => _downloadBudgetStatement(context, ref),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load budgets.\n$e',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
            ),
          ),
        ),
        data: (categories) =>
            _body(theme, cs, categories, progressById, totalBudgeted, totalSpent),
      ),
    );
  }

  Widget _body(
    ThemeData theme,
    ColorScheme cs,
    List<CategoryRow> categories,
    Map<int, BudgetProgress> progressById,
    Money totalBudgeted,
    Money totalSpent,
  ) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    children: [
      _SummaryCard(budgeted: totalBudgeted, spent: totalSpent),
      const SizedBox(height: 24),
      Text(
        'Categories',
        style: theme.textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      if (categories.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No expense categories yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        )
      else
        ..._categoryTree(categories).expand(
          (node) => [
            _BudgetTile(
              category: node.category,
              progress: progressById[node.category.id],
              onTap: () => _openDetail(node.category.id),
            ),
            if (node.children.isNotEmpty)
              _ChildBudgetThread(
                parentColor: Color(node.category.colorValue),
                children: node.children,
                progressById: progressById,
                onTapChild: (c) => _openDetail(c.id),
              ),
          ],
        ),
      const SizedBox(height: 8),
      Text(
        'Budgets only count expenses. Transfers between your own '
        'accounts are never counted.',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    ],
  );
```

This introduces one behavior change worth calling out: `_openDetail` used to take `BuildContext` and call `context.push`. Since it's now called from a helper (`_body`) that isn't itself a `BuildContext`, replace the `_openDetail` method (previously right after `build`) with a version that pushes via the router instance directly (the import for `appRouter` was already added in Step 3):

```dart
  void _openDetail(int categoryId) {
    appRouter.push('/more/budgets/$categoryId');
  }
```

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/budgets_embedded_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Confirm existing Budgets tests still pass**

Run: `flutter test test/screens_smoke_test.dart`
Expected: `All tests passed!` (the "Budgets renders the expense categories" / detail-screen tests construct `const BudgetsScreen()` with no args.)

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/features/budgets/budgets_screen.dart test/budgets_embedded_test.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/budgets/budgets_screen.dart test/budgets_embedded_test.dart
git commit -m "feat(budgets): add embedded mode for the customizable bottom nav (#70)"
```

---

## Task 4: Stats — `embedded` mode

**Files:**
- Modify: `lib/features/reports/stats_screen.dart:15-90` (`StatsScreen` class header + `build`)
- Test: `test/stats_embedded_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/stats_embedded_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/reports/stats_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('embedded: false (default) still shows its own app bar', (
    tester,
  ) async {
    await pump(tester, const StatsScreen());
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(AppBar, 'Stats'), findsOneWidget);
  });

  testWidgets('embedded: true renders no app bar of its own', (tester) async {
    await pump(tester, const StatsScreen(embedded: true));
    expect(tester.takeException(), isNull);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('This month'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/stats_embedded_test.dart`
Expected: fails to compile — no `embedded` parameter.

- [ ] **Step 3: Add `embedded` and split the Scaffold**

Replace `lib/features/reports/stats_screen.dart` lines 15-90 (the whole `StatsScreen` class) with:

```dart
/// Read-only insight screen. Every number here is derived from the ledger, so
/// transfers between your own accounts never register as income or expense.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then. Default `false`
/// keeps `/more/stats` exactly as it was.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final showYear = ref.watch(statsShowYearProvider);

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const _Caption('This month'),
        const _ThisMonthSection(),
        const SizedBox(height: 28),
        const _Caption('Net worth'),
        const _NetWorthSection(),
        const SizedBox(height: 28),
        const _Caption('Income vs expense'),
        const _IncomeExpenseSection(),
        const SizedBox(height: 28),
        const _Caption('Spending by category'),
        _PeriodToggle(
          showYear: showYear,
          onChanged: (v) => ref.read(statsShowYearProvider.notifier).state = v,
        ),
        const SizedBox(height: 8),
        _PeriodStepper(
          month: month,
          showYear: showYear,
          onShift: (delta) =>
              ref.read(selectedMonthProvider.notifier).state = showYear
              ? DateTime(month.year + delta, month.month)
              : DateTime(month.year, month.month + delta),
        ),
        const SizedBox(height: 8),
        _CategoryDetailToggle(
          showSubcategories: ref.watch(statsShowSubcategoriesProvider),
          onChanged: (v) =>
              ref.read(statsShowSubcategoriesProvider.notifier).state = v,
        ),
        const SizedBox(height: 12),
        _CategorySection(
          showYear: showYear,
          year: month.year,
          showSubcategories: ref.watch(statsShowSubcategoriesProvider),
        ),
        const SizedBox(height: 28),
        const _Caption('Highlights'),
        _HighlightsSection(month: month, showYear: showYear),
        const SizedBox(height: 24),
        Text(
          'Transfers between your own accounts are never counted as income '
          'or expense.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download report',
            onPressed: () => _downloadReport(context, ref, month, showYear),
          ),
        ],
      ),
      body: body,
    );
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/stats_embedded_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Confirm existing Stats tests still pass**

Run: `flutter test test/screens_smoke_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/reports/stats_screen.dart test/stats_embedded_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/reports/stats_screen.dart test/stats_embedded_test.dart
git commit -m "feat(stats): add embedded mode for the customizable bottom nav (#70)"
```

---

## Task 5: Accounts — `embedded` mode

`AccountsScreen` uses a `SliverAppBar` inside its `CustomScrollView` rather than `Scaffold.appBar` — `embedded` just conditionally drops that one sliver.

**Files:**
- Modify: `lib/features/accounts/accounts_screen.dart:15-46`
- Test: `test/accounts_embedded_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/accounts_embedded_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/accounts/accounts_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('embedded: false (default) still shows its own app bar', (
    tester,
  ) async {
    await pump(tester, const AccountsScreen());
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(SliverAppBar, 'Accounts'), findsOneWidget);
  });

  testWidgets('embedded: true renders no app bar of its own', (tester) async {
    await pump(tester, const AccountsScreen(embedded: true));
    expect(tester.takeException(), isNull);
    expect(find.byType(SliverAppBar), findsNothing);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/accounts_embedded_test.dart`
Expected: fails to compile — no `embedded` parameter.

- [ ] **Step 3: Add `embedded`**

Replace `lib/features/accounts/accounts_screen.dart` lines 15-46 with:

```dart
/// Total money + per-account balances, grouped Cash · Bank · Cards.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then. Default `false`
/// keeps `/more/accounts` exactly as it was.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final accountMap = ref.watch(accountMapProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (!embedded)
            SliverAppBar(
              pinned: true,
              title: const Text('Accounts'),
              actions: [
                IconButton(
                  tooltip: 'Statement',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () => _downloadCombinedStatement(context, ref),
                ),
                IconButton(
                  tooltip: 'Archived accounts',
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: () => context.push('/more/accounts/archived'),
                ),
                IconButton(
                  tooltip: 'Add account',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => showAddAccountSheet(context),
                ),
              ],
            ),
          const SliverToBoxAdapter(child: _TotalMoneyCard()),
          ...accountsAsync.when(
            data: (accounts) => _sections(context, ref, accounts, accountMap),
            loading: () => const [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
            error: (_, _) => [
              SliverToBoxAdapter(
                child: Padding(
```

Everything from that last `Padding(` onward (the error state's remaining lines, `_sections`, and the rest of the file) is unchanged — only the class header and the opening of `build`/`slivers:` changed, wrapping the existing `SliverAppBar(...)` in `if (!embedded)`.

**Trade-off worth knowing:** when `embedded`, the "Statement", "Archived accounts" and "Add account" actions have no home yet — they simply disappear from the tab (they're still reachable via `/more/accounts`, the unembedded path, if the user isn't using Accounts as a tab). Porting them into `AppShell`'s per-tab `_TopBar` actions (Task 7) is optional follow-up, not required for this plan — flag this as a known gap in the plan's final summary rather than silently letting it look finished.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/accounts_embedded_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Confirm existing Accounts tests still pass**

Run: `flutter test test/screens_smoke_test.dart test/smoke_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/accounts/accounts_screen.dart test/accounts_embedded_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/accounts/accounts_screen.dart test/accounts_embedded_test.dart
git commit -m "feat(accounts): add embedded mode for the customizable bottom nav (#70)"
```

---

## Task 6: Payees — `embedded` mode

Same shape as Task 5, simpler (no actions to hide).

**Files:**
- Modify: `lib/features/payees/payees_screen.dart:13-25`
- Test: `test/payees_embedded_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/payees_embedded_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/payees/payees_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('embedded: false (default) still shows its own app bar', (
    tester,
  ) async {
    await pump(tester, const PayeesScreen());
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(SliverAppBar, 'Payees'), findsOneWidget);
  });

  testWidgets('embedded: true renders no app bar of its own', (tester) async {
    await pump(tester, const PayeesScreen(embedded: true));
    expect(tester.takeException(), isNull);
    expect(find.byType(SliverAppBar), findsNothing);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/payees_embedded_test.dart`
Expected: fails to compile — no `embedded` parameter.

- [ ] **Step 3: Add `embedded`**

Replace `lib/features/payees/payees_screen.dart` lines 13-25 with:

```dart
/// Who you pay, or who pays you. Derived from the `payee` typed on each
/// expense or income (GitHub #62) — there is no separate table, so this
/// screen is a grouped view, not a CRUD list.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title then. Default `false` keeps
/// `/more/payees` exactly as it was.
class PayeesScreen extends ConsumerWidget {
  const PayeesScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaries = ref.watch(payeeSummariesProvider);
    final net = summaries.fold(const Money.zero(), (sum, s) => sum + s.net);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (!embedded) SliverAppBar(pinned: true, title: const Text('Payees')),
```

Everything from the next line (`SliverToBoxAdapter(child: _TotalsHeader(...))`) onward is unchanged.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/payees_embedded_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Confirm existing Payees usages still pass**

Run: `flutter test test/screens_smoke_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/payees/payees_screen.dart test/payees_embedded_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/payees/payees_screen.dart test/payees_embedded_test.dart
git commit -m "feat(payees): add embedded mode for the customizable bottom nav (#70)"
```

---

## Task 7: Router — 5 new top-level branches

**Files:**
- Modify: `lib/core/routing/app_router.dart:1-45` (imports, `appRouter` field), `:90-97` (top of `StatefulShellRoute.indexedStack`), `:290-294` (right after the `More` branch, before the closing `],`)

- [ ] **Step 1: Add the new branches**

In `lib/core/routing/app_router.dart`, the `More` branch currently ends at line 291 with:

```dart
        ),
      ],
    ),

    // First run.
```

Insert 5 new `StatefulShellBranch`es between that closing `),` of the branches list and the `],` that closes it — i.e. change:

```dart
              ],
            ),
          ],
        ),
      ],
    ),

    // First run.
```

to:

```dart
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (_, _) => const CalendarScreen(embedded: true),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/budgets',
              builder: (_, _) => const BudgetsScreen(embedded: true),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accounts',
              builder: (_, _) => const AccountsScreen(embedded: true),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stats',
              builder: (_, _) => const StatsScreen(embedded: true),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/payees',
              builder: (_, _) => const PayeesScreen(embedded: true),
            ),
          ],
        ),
      ],
    ),

    // First run.
```

Every existing branch (Dashboard=0, Transactions=1, Persons=2, More=3) is untouched — the 5 new ones are appended, becoming indices 4 (calendar), 5 (budgets), 6 (accounts), 7 (stats), 8 (payees), matching the design spec's fixed branch-index table.

- [ ] **Step 2: Export `appRouter` for Task 3's `budgets_screen.dart` change**

`appRouter` is already a top-level `final` in this file (line 90), so `show appRouter` in Task 3 already works — no change needed here beyond confirming the import path `../../core/routing/app_router.dart` is correct relative to `lib/features/budgets/budgets_screen.dart` (it is — same depth as every other `features/*` file's `../../core/...` imports in this codebase).

- [ ] **Step 3: Run the app's existing router-adjacent tests**

Run: `flutter test test/screens_smoke_test.dart test/smoke_test.dart`
Expected: `All tests passed!` (these test screens directly, not through the router, so this just confirms nothing else broke.)

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/core/routing/app_router.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/routing/app_router.dart
git commit -m "feat(router): add 5 top-level branches for the customizable bottom nav (#70)"
```

---

## Task 8: `AppShell` — dynamic slots + 9-case `_TopBar`

**Files:**
- Modify: `lib/core/routing/app_shell.dart` (the whole file — see below for the complete replacement)
- Test: `test/app_shell_bottom_nav_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/app_shell_bottom_nav_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('default bar shows Dashboard, Transactions, Persons, More', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Persons'), findsWidgets);
    expect(find.text('More'), findsWidgets);
  });

  testWidgets('changing the setting swaps a slot label without touching '
      'Dashboard/More', (tester) async {
    await pump(tester);
    await tester.runAsync(() => db.setBottomNavSlots('calendar', 'stats'));
    // The shell rebuilds on the settings stream, not on a fresh navigation —
    // give it a beat.
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('More'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Stats'), findsWidgets);
    expect(find.text('Transactions'), findsNothing);
    expect(find.text('Persons'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/app_shell_bottom_nav_test.dart`
Expected: `Transactions`/`Persons` are found (the bar is still the old hardcoded 4-tab version), so the second test's final two assertions fail.

- [ ] **Step 3: Replace `lib/core/routing/app_shell.dart` in full**

The bar's structure (`Dashboard, slotLeft, ➕, slotRight, More`), the catalog, and `_TopBar`'s per-branch title/actions switch all change together, so replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/persons/persons_screen.dart' show showAddPersonDialog;
import '../../features/transactions/transaction_filters.dart';
import '../branding/app_info.dart';
import '../branding/brand_mark.dart';

/// `Dashboard · slotLeft · ➕ · slotRight · More`
///
/// The ➕ slot is not a tab — it pushes the Add Transaction route. Dashboard
/// (branch 0) and More (branch 3) are permanently pinned; `slotLeft`/
/// `slotRight` are resolved from `Settings.bottomNavSlots` through
/// [_catalog] — see GitHub #70's design spec for the full branch-index
/// table (0=dashboard, 1=transactions, 2=persons, 3=more, 4=calendar,
/// 5=budgets, 6=accounts, 7=stats, 8=payees; the last 5 were added by this
/// feature and are only reachable when a user picks them into a slot).
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _dashboard = _TabSpec(
    0,
    Icons.pie_chart_outline_rounded,
    Icons.pie_chart_rounded,
    'Dashboard',
  );
  static const _more = _TabSpec(
    3,
    Icons.grid_view_outlined,
    Icons.grid_view_rounded,
    'More',
  );

  /// The 7 destinations a configurable slot can be set to — must match
  /// `AppDatabase.bottomNavCatalogIds` exactly (a mismatch would let a slot
  /// resolve to nothing and silently vanish from the bar).
  static const _catalog = <String, _TabSpec>{
    'transactions': _TabSpec(
      1,
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      'Transactions',
    ),
    'persons': _TabSpec(
      2,
      Icons.people_alt_outlined,
      Icons.people_alt_rounded,
      'Persons',
    ),
    'calendar': _TabSpec(
      4,
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
      'Calendar',
    ),
    'budgets': _TabSpec(
      5,
      Icons.donut_large_outlined,
      Icons.donut_large_rounded,
      'Budgets',
    ),
    'accounts': _TabSpec(
      6,
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      'Accounts',
    ),
    'stats': _TabSpec(7, Icons.insights_outlined, Icons.insights_rounded, 'Stats'),
    'payees': _TabSpec(
      8,
      Icons.storefront_outlined,
      Icons.storefront_rounded,
      'Payees',
    ),
  };

  static (String, String) _slotIds(WidgetRef ref) {
    final raw =
        ref.watch(settingsProvider).valueOrNull?.bottomNavSlots ??
        'transactions,persons';
    final parts = raw.split(',');
    if (parts.length != 2 ||
        !_catalog.containsKey(parts[0]) ||
        !_catalog.containsKey(parts[1])) {
      // A value that somehow doesn't parse (shouldn't happen — only
      // `setBottomNavSlots` ever writes this column, and it validates) falls
      // back to the same default the column itself defaults to.
      return ('transactions', 'persons');
    }
    return (parts[0], parts[1]);
  }

  /// Re-tapping the tab you're already on doesn't navigate anywhere — instead
  /// it signals that tab's screen to scroll back to the top (GitHub #66).
  void _goBranch(WidgetRef ref, int branchIndex) {
    final alreadyActive = branchIndex == navigationShell.currentIndex;
    if (alreadyActive && branchIndex == 1) {
      ref.read(txScrollToTopProvider.notifier).state++;
    }
    navigationShell.goBranch(branchIndex, initialLocation: alreadyActive);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outline;
    final (leftId, rightId) = _slotIds(ref);
    final left = _catalog[leftId]!;
    final right = _catalog[rightId]!;

    return Scaffold(
      appBar: _TopBar(currentIndex: navigationShell.currentIndex),
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _navItem(context, ref, _dashboard),
                _navItem(context, ref, left),
                _addButton(context),
                _navItem(context, ref, right),
                _navItem(context, ref, _more),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, WidgetRef ref, _TabSpec tab) {
    final theme = Theme.of(context);
    final selected = navigationShell.currentIndex == tab.branch;
    final color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () => _goBranch(ref, tab.branch),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    return Expanded(
      child: Center(
        child: Material(
          color: Theme.of(context).colorScheme.secondary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/add'),
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.branch, this.icon, this.activeIcon, this.label);
  final int branch;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The app's persistent top bar — fixed on screen across every tab, sibling
/// to the bottom nav bar (a pushed detail route, e.g. a screen reached from
/// the More hub, covers both the same way, since both live outside the
/// shell).
///
/// Carries the current tab's own title and actions — one bar, sized like an
/// ordinary toolbar (`kToolbarHeight`, same as every pushed screen's bar —
/// see the screens under `lib/features/*`).
///
/// Indexed by branch, not by bar position — GitHub #70 made which catalog
/// item sits at bar position 2/4 configurable, but the 9 branch indices
/// themselves are permanent (see `AppShell`'s class doc).
class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _TopBar({required this.currentIndex});

  final int currentIndex;

  static const _titles = [
    'Dashboard', // 0
    'Transactions', // 1
    'Persons', // 2
    'More', // 3
    'Calendar', // 4
    'Budgets', // 5
    'Accounts', // 6
    'Stats', // 7
    'Payees', // 8
  ];

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outline)),
      ),
      child: AppBar(
        automaticallyImplyLeading: false,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(_titles[currentIndex], key: ValueKey(currentIndex)),
        ),
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Row(
              key: ValueKey(currentIndex),
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._tabActions(context, ref, currentIndex),
                _TonalIconButton(
                  tooltip: 'Review Inbox',
                  icon: const Icon(Icons.inbox_outlined),
                  onPressed: () => context.push('/inbox'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// Whatever's specific to the active tab, Review Inbox appended after by
  /// the caller — see the class doc for why Inbox always gets that trailing
  /// slot.
  List<Widget> _tabActions(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0: // Dashboard
        return [
          _TonalIconButton(
            tooltip: 'About ${AppInfo.name}',
            icon: const BrandMark(size: 22),
            onPressed: () => context.push('/more/about'),
          ),
          const SizedBox(width: 4),
        ];
      case 1: // Transactions
        return const [_TransactionsBarActions(), SizedBox(width: 4)];
      case 2: // Persons
        return [
          _TonalIconButton(
            tooltip: 'Archived people',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => context.push('/persons/archived'),
          ),
          const SizedBox(width: 4),
          _TonalIconButton(
            tooltip: 'Add person',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => showAddPersonDialog(context, ref),
          ),
          const SizedBox(width: 4),
        ];
      case 4: // Calendar
        return [
          _TonalIconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today_rounded),
            onPressed: () =>
                ref.read(calendarGoToTodaySignalProvider.notifier).state++,
          ),
          const SizedBox(width: 4),
          _TonalIconButton(
            tooltip: 'New reminder',
            icon: const Icon(Icons.add_rounded),
            onPressed: () =>
                ref.read(calendarNewReminderSignalProvider.notifier).state++,
          ),
          const SizedBox(width: 4),
        ];
      default: // More, Budgets, Accounts, Stats, Payees — no tab-specific
        // action yet (Budgets/Stats keep their PDF-download action reachable
        // only via /more/budgets · /more/stats for now; Accounts similarly
        // keeps Statement/Archived/Add reachable only via /more/accounts —
        // see Task 5's noted trade-off. Porting them here is optional
        // follow-up, not required for GitHub #70 itself).
        return const [];
    }
  }
}

/// The soft, tappable pill behind a top-bar icon — the same accent-tint idiom
/// [ThemePickerSheet]'s selected tile already uses, so a tonal icon reads as
/// *this app's* accent rather than a generic Material default. Its shape
/// isn't hardcoded — a `CircleBorder` already matches every preset, Cove's
/// bigger radius included, since a circle has no corner to disagree about.
class _TonalIconButton extends StatelessWidget {
  const _TonalIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondary.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: IconButton(tooltip: tooltip, icon: icon, onPressed: onPressed),
    );
  }
}

/// The Transactions tab's search + filter controls — the actions this bar
/// shows in place of nothing, only while that tab is active. State lives in
/// `txSearchActiveProvider`/`txAdvancedFiltersProvider` rather than in
/// `TransactionsScreen` itself, since these buttons are no longer a
/// descendant of the screen they control.
class _TransactionsBarActions extends ConsumerWidget {
  const _TransactionsBarActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(txAdvancedFiltersProvider);
    final searchActive = ref.watch(txSearchActiveProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TonalIconButton(
          tooltip: 'Filters',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Badge(
              key: ValueKey(filters.count),
              isLabelVisible: filters.count > 0,
              label: Text('${filters.count}'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          onPressed: () => _openFilters(context, ref, filters),
        ),
        const SizedBox(width: 4),
        _TonalIconButton(
          tooltip: searchActive ? 'Close search' : 'Search',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              searchActive ? Icons.close_rounded : Icons.search_rounded,
              key: ValueKey(searchActive),
            ),
          ),
          onPressed: () {
            final active = !searchActive;
            ref.read(txSearchActiveProvider.notifier).state = active;
            if (!active) ref.read(txSearchQueryProvider.notifier).state = '';
          },
        ),
      ],
    );
  }

  Future<void> _openFilters(
    BuildContext context,
    WidgetRef ref,
    TransactionFilters current,
  ) async {
    final result = await showModalBottomSheet<TransactionFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionFiltersSheet(initial: current),
    );
    if (result == null) return;
    ref.read(txAdvancedFiltersProvider.notifier).state = result;
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/app_shell_bottom_nav_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Confirm the full smoke suite still passes**

Run: `flutter test test/screens_smoke_test.dart test/smoke_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/core/routing/app_shell.dart test/app_shell_bottom_nav_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/routing/app_shell.dart test/app_shell_bottom_nav_test.dart
git commit -m "feat(shell): resolve bottom-nav slots from Settings.bottomNavSlots (#70)"
```

---

## Task 9: "Customize bottom nav" settings screen

**Files:**
- Create: `lib/features/settings/bottom_nav_settings_screen.dart`
- Modify: `lib/core/routing/app_router.dart` (one new nested route under `/more/settings`)
- Modify: `lib/features/settings/settings_screen.dart` (one new tile)
- Test: `test/bottom_nav_settings_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/bottom_nav_settings_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/settings/bottom_nav_settings_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const BottomNavSettingsScreen(),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows the current slots and lets you change one', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    // Defaults: Transactions on the left, Persons on the right.
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Persons'), findsOneWidget);

    await tester.tap(find.text('Transactions'));
    await tester.pump();
    await tester.tap(find.text('Calendar').last);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Calendar'), findsOneWidget);
    expect(await db.getSettings().then((s) => s.bottomNavSlots), 'calendar,persons');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/bottom_nav_settings_screen_test.dart`
Expected: fails to compile — `lib/features/settings/bottom_nav_settings_screen.dart` doesn't exist.

- [ ] **Step 3: Create the screen**

Create `lib/features/settings/bottom_nav_settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing/app_router.dart' show appRouter;
import '../../core/routing/app_shell.dart' show bottomNavCatalogLabels;
import '../../data/database.dart';
import '../../data/providers.dart';

/// Pick which of the 7 catalog destinations occupy the two configurable
/// bottom-nav slots flanking the ➕ button — GitHub #70. Dashboard and More
/// are pinned and don't appear here at all.
class BottomNavSettingsScreen extends ConsumerWidget {
  const BottomNavSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final raw =
        ref.watch(settingsProvider).valueOrNull?.bottomNavSlots ??
        'transactions,persons';
    final parts = raw.split(',');
    final leftId = parts.length == 2 ? parts[0] : 'transactions';
    final rightId = parts.length == 2 ? parts[1] : 'persons';

    Future<void> pick(bool isLeft) async {
      final excluded = isLeft ? rightId : leftId;
      final chosen = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (_) => _CatalogPickerSheet(excluded: excluded),
      );
      if (chosen == null) return;
      final db = ref.read(dbProvider);
      await db.setBottomNavSlots(
        isLeft ? chosen : leftId,
        isLeft ? rightId : chosen,
      );
      // `appRouter.go` (the GoRouter instance directly, not `context.go`) so
      // this works even in a widget test that pumps this screen standalone,
      // with no GoRouter ancestor in the tree — same workaround Task 3 uses
      // for `BudgetsScreen._openDetail`.
      appRouter.go('/dashboard');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Customize bottom nav')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Dashboard and More always stay put. Pick what goes in the two '
            'slots next to the ➕ button.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _PinnedRow(label: 'Dashboard'),
          const SizedBox(height: 8),
          _SlotTile(
            label: bottomNavCatalogLabels[leftId]!,
            onTap: () => pick(true),
          ),
          const SizedBox(height: 8),
          const _AddButtonRow(),
          const SizedBox(height: 8),
          _SlotTile(
            label: bottomNavCatalogLabels[rightId]!,
            onTap: () => pick(false),
          ),
          const SizedBox(height: 8),
          _PinnedRow(label: 'More'),
        ],
      ),
    );
  }
}

class _PinnedRow extends StatelessWidget {
  const _PinnedRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(
            'Fixed',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButtonRow extends StatelessWidget {
  const _AddButtonRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: cs.secondary, shape: BoxShape.circle),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        subtitle: Text(
          'Tap to change',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CatalogPickerSheet extends StatelessWidget {
  const _CatalogPickerSheet({required this.excluded});

  /// The id already used by the *other* slot — omitted so the result is
  /// always 2 distinct ids, with no dedup logic needed by the caller.
  final String excluded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in bottomNavCatalogLabels.entries)
              if (entry.key != excluded)
                ListTile(
                  title: Text(entry.value),
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Expose the catalog's labels from `app_shell.dart`**

The picker needs `id -> label` without duplicating `AppShell._catalog`. In `lib/core/routing/app_shell.dart`, right after the `AppShell` class's closing `}` (before `class _TabSpec`), add:

```dart
/// `id -> label` for every configurable bottom-nav destination — the same
/// set as `AppShell._catalog`'s keys, exposed for the "Customize bottom
/// nav" settings screen's picker (GitHub #70) without making the whole
/// catalog (icons included) public.
const bottomNavCatalogLabels = <String, String>{
  'transactions': 'Transactions',
  'persons': 'Persons',
  'calendar': 'Calendar',
  'budgets': 'Budgets',
  'accounts': 'Accounts',
  'stats': 'Stats',
  'payees': 'Payees',
};
```

- [ ] **Step 5: Wire the route**

In `lib/core/routing/app_router.dart`, add the import:

```dart
import '../../features/settings/bottom_nav_settings_screen.dart';
```

and, as a direct child of the `/more` route — a sibling of `budgets`/`calendar`/`settings`/etc., **not** nested under `settings` (right after the `settings` route's own block, before the `about` route):

```dart
                GoRoute(
                  path: 'bottom-nav',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const BottomNavSettingsScreen(),
                ),
```

giving the path `/more/bottom-nav`.

- [ ] **Step 6: Add the More hub tile**

In `lib/features/more/more_screen.dart`, inside the `'Setup'` group's list, right after the `Settings` tile:

```dart
        _Item(
          Icons.dashboard_customize_outlined,
          'Customize bottom nav',
          route: '/more/bottom-nav',
          subtitle: 'Choose what goes next to the ➕ button',
        ),
```

- [ ] **Step 7: Run it and watch it pass**

Run: `flutter test test/bottom_nav_settings_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 8: Confirm the More hub and router still work**

Run: `flutter test test/screens_smoke_test.dart`
Expected: `All tests passed!` ("More hub renders every tile" now also finds the new tile.)

- [ ] **Step 9: Analyze**

Run: `flutter analyze lib/features/settings/bottom_nav_settings_screen.dart lib/core/routing/app_shell.dart lib/core/routing/app_router.dart lib/features/more/more_screen.dart test/bottom_nav_settings_screen_test.dart`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/features/settings/bottom_nav_settings_screen.dart lib/core/routing/app_shell.dart lib/core/routing/app_router.dart lib/features/more/more_screen.dart test/bottom_nav_settings_screen_test.dart
git commit -m "feat(settings): add Customize bottom nav screen (#70)"
```

---

## Task 10: Full regression pass

**Files:** none (verification only)

- [ ] **Step 1: Regenerate Drift code once more (safety net)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0, no diff in `lib/data/database.g.dart` (nothing new was added to a table since Task 1).

- [ ] **Step 2: Full analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: Manual check on a device/emulator**

Launch the app, open More, tap "Customize bottom nav" (this is the one route/tile pairing no automated test exercises end-to-end — Task 9's own test pumps the screen directly, not via tapping the tile), change the left slot to Calendar, confirm: it lands back on Dashboard; the bar now shows Dashboard / Calendar / ➕ / Persons / More; tapping Calendar shows the month grid with no back arrow and the shared top bar's "Today"/"New reminder" icons; tapping "Calendar & Reminders" from the More hub still separately opens Calendar with its own back arrow at `/more/calendar`, unaffected.

- [ ] **Step 5: Commit (only if step 4 needed a fix)**

If step 4 surfaced nothing to fix, there is nothing to commit for this task — it exists purely to catch anything the automated tests structurally can't (visual/manual confirmation).
