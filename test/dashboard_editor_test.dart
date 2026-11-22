import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/dashboard/dashboard_layout.dart';
import 'package:xpenc/features/dashboard/dashboard_screen.dart';

/// Hold a Dashboard widget to edit the Dashboard in place, and each
/// widget's own options.
void main() {
  group('dashboard widget options', () {
    test('every widget offers options, each with 2–3 choices', () {
      for (final w in DashboardWidget.values) {
        expect(w.options, isNotEmpty, reason: w.name);
        for (final o in w.options) {
          expect(o.choices.length, inInclusiveRange(2, 3), reason: o.key);
          for (final c in o.choices) {
            expect(c.$1, matches(RegExp(r'^[a-zA-Z0-9]+$')));
          }
        }
      }
    });

    test("'' is every widget's default", () {
      final o = parseDashboardOptions('');
      expect(o, isEmpty);
      expect(dashboardOptionOf(o, DashboardWidget.recent, 'count'), '5');
      expect(dashboardOptionOf(o, DashboardWidget.cashFlow, 'months'), '6');
    });

    test('reads picks, skips junk, unknowns and defaults', () {
      final o = parseDashboardOptions(
        'recent.count=10,people.filter=owesYou,recent.type=bogus,'
        'nope.count=3,recent.zzz=1,garbage,cashFlow.months=6',
      );
      expect(o, {
        DashboardWidget.recent: {'count': '10'},
        DashboardWidget.people: {'filter': 'owesYou'},
      });
      expect(dashboardOptionOf(o, DashboardWidget.recent, 'type'), 'all');
    });

    test('set and encode round-trip; the default removes a pick', () {
      var o = setDashboardOption({}, DashboardWidget.spending, 'show', 'list');
      o = setDashboardOption(o, DashboardWidget.recent, 'count', '3');
      final encoded = encodeDashboardOptions(o);
      expect(encoded, 'spending.show=list,recent.count=3');
      expect(parseDashboardOptions(encoded), o);
      o = setDashboardOption(o, DashboardWidget.recent, 'count', '5');
      expect(encodeDashboardOptions(o), 'spending.show=list');
    });

    test('the database keeps them, and refuses a malformed value', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.setDashboardWidgetOptions('recent.count=10');
      expect(
        (await db.getSettings()).dashboardWidgetOptions,
        'recent.count=10',
      );
      expect(
        () => db.setDashboardWidgetOptions('recent.count=1,0'),
        throwsArgumentError,
      );
    });
  });

  group('editing the Dashboard in place', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const DashboardScreen(),
          ),
        ),
      );
      await settle(tester);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> hold(WidgetTester tester, Finder target) async {
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a short press does nothing; a held widget opens the editor, '
        'where ✕ takes it off and Done finishes', (tester) async {
      await pump(tester);
      final moneyIn = find.text('Money in').first;

      // Half the hold is just a press.
      final g = await tester.startGesture(tester.getCenter(moneyIn));
      await tester.pump(const Duration(milliseconds: 400));
      await g.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit dashboard'), findsNothing);

      await hold(tester, moneyIn);
      expect(find.text('Edit dashboard'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dashboard-remove-thisMonth')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('dashboard-remove-thisMonth')),
      );
      await settle(tester);
      expect(
        (await tester.runAsync(db.getSettings))!.dashboardLayout,
        contains('-thisMonth'),
      );
      expect(
        find.byKey(const ValueKey('dashboard-remove-thisMonth')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('dashboard-edit-done')));
      await settle(tester);
      expect(find.text('Edit dashboard'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('a widget\'s options apply on the Dashboard at once', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Saved'), findsOneWidget);

      await hold(tester, find.text('Money in').first);
      await tester.tap(
        find.byKey(const ValueKey('dashboard-options-thisMonth')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final netRow = find.byKey(
        const ValueKey('dashboard-option-thisMonth-net'),
      );
      expect(netRow, findsOneWidget);
      await tester.tap(
        find.descendant(of: netRow, matching: find.text('Hide')),
      );
      await settle(tester);
      expect(
        (await tester.runAsync(db.getSettings))!.dashboardWidgetOptions,
        'thisMonth.net=hide',
      );

      Navigator.of(tester.element(netRow)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('dashboard-edit-done')));
      await settle(tester);
      expect(find.text('Saved'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('every widget draws with every non-default option, on the '
        'Dashboard and in the editor', (tester) async {
      await tester.runAsync(() async {
        await db.setDashboardLayout(
          [for (final w in DashboardWidget.values) w.name].join(','),
        );
      });
      for (final pick in <String Function(DashboardOption)>[
        (o) => o.choices.last.$1,
        (o) => o.choices[1].$1,
      ]) {
        DashboardOptions options = {};
        for (final w in DashboardWidget.values) {
          for (final o in w.options) {
            options = setDashboardOption(options, w, o.key, pick(o));
          }
        }
        await tester.runAsync(
          () => db.setDashboardWidgetOptions(encodeDashboardOptions(options)),
        );
        await pump(tester);
        expect(tester.takeException(), isNull);
        await hold(tester, find.text('Money in').first);
        await settle(tester);
        expect(find.text('Edit dashboard'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      }
    });

    testWidgets('Add widget puts a taken-off widget back', (tester) async {
      await pump(tester);
      await hold(tester, find.text('Money in').first);
      await tester.tap(find.byKey(const Key('dashboard-edit-add')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('dashboard-add-cashFlow')));
      await settle(tester);
      expect(
        parseDashboardLayout(
          (await tester.runAsync(db.getSettings))!.dashboardLayout,
        ).firstWhere((s) => s.widget == DashboardWidget.cashFlow).visible,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
