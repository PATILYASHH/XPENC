import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/dashboard/dashboard_layout.dart';
import 'package:xpenc/features/settings/dashboard_settings_screen.dart';

/// Settings ▸ Customize dashboard: which widgets, in what order.
void main() {
  List<DashboardWidget> shownOf(List<DashboardSlot> slots) => [
    for (final s in slots)
      if (s.visible) s.widget,
  ];

  group('parseDashboardLayout', () {
    test("'' is the original dashboard, with the added widgets off", () {
      final slots = parseDashboardLayout('');
      expect(slots, hasLength(DashboardWidget.values.length));
      expect(shownOf(slots), [
        DashboardWidget.detected,
        DashboardWidget.totalMoney,
        DashboardWidget.thisMonth,
        DashboardWidget.accounts,
        DashboardWidget.readyToAssign,
        DashboardWidget.people,
        DashboardWidget.upcoming,
        DashboardWidget.budgets,
        DashboardWidget.spending,
        DashboardWidget.recent,
      ]);
    });

    test('keeps the stored order and what was taken off', () {
      final slots = parseDashboardLayout('recent,goals,-totalMoney,budgets');
      expect(shownOf(slots).take(3), [
        DashboardWidget.recent,
        DashboardWidget.goals,
        DashboardWidget.budgets,
      ]);
      expect(
        slots.firstWhere((s) => s.widget == DashboardWidget.totalMoney).visible,
        isFalse,
      );
    });

    test('a widget the value never named joins on its own default — so one '
        'added in a later version is not mistaken for removed', () {
      final slots = parseDashboardLayout('recent,-totalMoney');
      expect(slots, hasLength(DashboardWidget.values.length));
      final people = slots.firstWhere(
        (s) => s.widget == DashboardWidget.people,
      );
      final goals = slots.firstWhere((s) => s.widget == DashboardWidget.goals);
      expect(people.visible, isTrue);
      expect(goals.visible, isFalse);
    });

    test('skips junk and repeats', () {
      final slots = parseDashboardLayout('nope,recent,,recent,-recent,--x');
      expect(slots, hasLength(DashboardWidget.values.length));
      expect(shownOf(slots).first, DashboardWidget.recent);
    });

    test('round-trips through encode', () {
      const raw = 'goals,recent,-totalMoney,-shopping';
      final once = parseDashboardLayout(raw);
      expect(parseDashboardLayout(encodeDashboardLayout(once)), once);
    });
  });

  group('editing', () {
    test('adding puts the widget at the bottom of the dashboard', () {
      final next = setDashboardWidgetVisible(
        defaultDashboardLayout,
        DashboardWidget.goals,
        visible: true,
      );
      expect(shownOf(next).last, DashboardWidget.goals);
    });

    test('removing takes it off and keeps the rest in order', () {
      final next = setDashboardWidgetVisible(
        defaultDashboardLayout,
        DashboardWidget.totalMoney,
        visible: false,
      );
      expect(shownOf(next), isNot(contains(DashboardWidget.totalMoney)));
      expect(shownOf(next).take(2), [
        DashboardWidget.detected,
        DashboardWidget.thisMonth,
      ]);
    });

    test('reorder follows onReorder\'s index convention', () {
      // Drag the first shown widget below the third.
      final down = reorderDashboardWidgets(defaultDashboardLayout, 0, 3);
      expect(shownOf(down).take(3), [
        DashboardWidget.totalMoney,
        DashboardWidget.thisMonth,
        DashboardWidget.detected,
      ]);
      // And the third back to the top.
      final up = reorderDashboardWidgets(down, 2, 0);
      expect(shownOf(up), shownOf(defaultDashboardLayout));
    });
  });

  test('setDashboardLayout refuses a repeat or a malformed id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setDashboardLayout('recent,-goals');
    expect((await db.getSettings()).dashboardLayout, 'recent,-goals');
    expect(() => db.setDashboardLayout('recent,-recent'), throwsArgumentError);
    expect(() => db.setDashboardLayout('re cent'), throwsArgumentError);
  });

  group('Customize dashboard screen', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const DashboardSettingsScreen(),
          ),
        ),
      );
      await settle(tester);
    }

    /// Scrolls [finder] into view — down by default, up for [up].
    Future<void> reveal(
      WidgetTester tester,
      Finder finder, {
      bool up = false,
    }) async {
      // Until it can take a tap — merely built isn't enough.
      await tester.dragUntilVisible(
        finder,
        find.byType(CustomScrollView),
        Offset(0, up ? 150 : -150),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<String> stored(WidgetTester tester) async =>
        (await tester.runAsync(() => db.getSettings()))!.dashboardLayout;

    testWidgets('+ adds a widget, − takes one off, Reset puts it back', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('Reset to default'), findsNothing);

      await reveal(tester, find.byTooltip('Add Savings goals'));
      await tester.tap(find.byTooltip('Add Savings goals'));
      await settle(tester);
      var slots = parseDashboardLayout(await stored(tester));
      expect(shownOf(slots).last, DashboardWidget.goals);
      await reveal(tester, find.byTooltip('Remove Savings goals'), up: true);

      await reveal(tester, find.byTooltip('Remove Total money'), up: true);
      await tester.tap(find.byTooltip('Remove Total money'));
      await settle(tester);
      slots = parseDashboardLayout(await stored(tester));
      expect(shownOf(slots), isNot(contains(DashboardWidget.totalMoney)));
      await reveal(tester, find.byTooltip('Add Total money'));

      await reveal(tester, find.text('Reset to default'));
      await tester.tap(find.text('Reset to default'));
      await settle(tester);
      expect(
        parseDashboardLayout(await stored(tester)),
        defaultDashboardLayout,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('the dashboard draws its widgets in the stored order, and an '
      'empty one offers a way back', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(
      () => db.setDashboardLayout(
        'shortcuts,thisMonth,cashFlow,goals,loans,groups,shopping,'
        '-totalMoney,-detected,-accounts,-readyToAssign,-people,-upcoming,'
        '-budgets,-spending,-recent',
      ),
    );
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter,
        ),
      ),
    );
    appRouter.go('/dashboard');
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    await settle();
    // The added widgets, with nothing of their kind yet, invite a start.
    final shortcuts = find.text('Shortcuts');
    final income = find.text('Income');
    expect(shortcuts, findsOneWidget);
    expect(income, findsWidgets);
    expect(
      tester.getTopLeft(shortcuts).dy,
      lessThan(tester.getTopLeft(income.first).dy),
    );
    expect(find.text('Total money'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Make a shopping list'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Start a savings goal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Customize dashboard'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);

    await tester.runAsync(
      () => db.setDashboardLayout(
        [for (final w in DashboardWidget.values) '-${w.name}'].join(','),
      ),
    );
    await settle();
    expect(find.text('Your dashboard is empty'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
