import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/mode_providers.dart';
import 'package:xpenc/data/modes_db.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';
import 'package:xpenc/features/modes/mode_editor_screen.dart';
import 'package:xpenc/features/modes/mode_widgets.dart';
import 'package:xpenc/features/persons/edit_person_sheet.dart';

/// Fixes after the v2 beta: people could not be picked on a mode made
/// before v2, a Trip's module chips did not toggle, the bar over the tabs
/// became a circle in the corner, and paying a planned cost of a mode that
/// isn't ON landed outside it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<ProviderContainer> app(
    WidgetTester tester, {
    required String at,
    required List<RouteBase> routes,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(initialLocation: at, routes: routes),
        ),
      ),
    );
    await settle(tester);
    return container;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Finder chip(String label) => find.ancestor(
    of: find.text(label, skipOffstage: false),
    matching: find.byType(FilterChip, skipOffstage: false),
  );

  /// Scrolls the editor's list (built lazily) to [label]'s chip, taps it.
  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(chip(label));
    await tester.pump();
  }

  final editorRoutes = <RouteBase>[
    GoRoute(
      path: '/mode/:id',
      builder: (_, _) => const Text('mode page'),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (_, s) =>
              ModeEditorScreen(modeId: int.parse(s.pathParameters['id']!)),
        ),
      ],
    ),
    GoRoute(
      path: '/more/modes/new',
      builder: (_, s) =>
          ModeEditorScreen(presetKey: s.uri.queryParameters['preset']),
    ),
  ];

  testWidgets('people can be picked on a mode that has none yet', (
    tester,
  ) async {
    final asha = (await tester.runAsync(() => db.addPerson('Asha')))!;
    final id = (await tester.runAsync(
      () => db.addMode(name: 'Goa', iconKey: 'luggage', colorValue: 0),
    ))!;
    await app(tester, at: '/mode/$id/edit', routes: editorRoutes);
    await tapChip(tester, 'Asha');
    expect(tester.takeException(), isNull);
    expect(tester.widget<FilterChip>(chip('Asha')).selected, isTrue);
    await tester.tap(find.text('Save').first);
    await settle(tester);
    expect(await tester.runAsync(() => db.modePeopleIds(id)), {asha});
    await unmount(tester);
  });

  testWidgets("a Trip's module chips toggle", (tester) async {
    await app(tester, at: '/more/modes/new?preset=trip', routes: editorRoutes);
    await tapChip(tester, 'Stats');
    expect(tester.takeException(), isNull);
    expect(tester.widget<FilterChip>(chip('Stats')).selected, isTrue);
    await tapChip(tester, 'Persons');
    expect(tester.widget<FilterChip>(chip('Persons')).selected, isFalse);
    await unmount(tester);
  });

  testWidgets('the corner circle: Full app, back, and End with summary', (
    tester,
  ) async {
    final id = (await tester.runAsync(() async {
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0xFF0EA5E9,
      );
      await db.startMode(id);
      return id;
    }))!;
    final c = await app(
      tester,
      at: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            appBar: AppBar(leading: const Center(child: ModeOrb())),
          ),
        ),
        GoRoute(
          path: '/mode/:id/summary',
          builder: (_, _) => const Scaffold(body: Text('summary page')),
        ),
        GoRoute(
          path: '/mode/:id',
          builder: (_, _) => const Scaffold(body: Text('mode page')),
        ),
      ],
    );
    expect(find.byKey(const ValueKey('modeOrb')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('modeOrb')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full app'));
    await tester.pumpAndSettle();
    expect(c.read(modeFullAppProvider), isTrue);

    await tester.tap(find.byKey(const ValueKey('modeOrb')));
    await tester.pumpAndSettle();
    expect(find.text('Back to Goa'), findsOneWidget);
    await tester.tap(find.text('End Goa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'End'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(await tester.runAsync(db.activeModeId), isNull);
    expect(
      (await tester.runAsync(() => db.modeById(id)))!.status,
      ModeStatus.ended,
    );
    expect(find.text('summary page'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("paying a planned cost joins its mode even when it's off", (
    tester,
  ) async {
    final ids = (await tester.runAsync(() async {
      final mode = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
      );
      final cost = await db.addPlannedCost(
        modeId: mode,
        name: 'Hotel',
        amount: Money.fromRupees(3000),
      );
      return (mode: mode, cost: cost);
    }))!;
    await app(
      tester,
      at: '/add',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('home'),
          routes: [
            GoRoute(
              path: 'add',
              builder: (_, _) => AddTransactionScreen(
                initialType: TxType.expense,
                plannedCostId: ids.cost,
              ),
            ),
          ],
        ),
      ],
    );
    expect(find.text('Part of Goa'), findsOneWidget);
    // An account to pay from.
    final pick = find.text('Select account', skipOffstage: false).first;
    await tester.ensureVisible(pick);
    await tester.tap(pick);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await settle(tester);
    final tx = (await tester.runAsync(() => db.watchTransactions().first))!;
    expect(tx.single.modeId, ids.mode);
    await unmount(tester);
  });

  testWidgets('a person added while a mode is ON joins its people', (
    tester,
  ) async {
    final id = (await tester.runAsync(() async {
      final id = await db.addMode(
        name: 'Goa',
        iconKey: 'luggage',
        colorValue: 0,
      );
      await db.startMode(id);
      return id;
    }))!;
    await app(
      tester,
      at: '/add',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('home'),
          routes: [
            GoRoute(
              path: 'add',
              builder: (_, _) =>
                  const Scaffold(body: EditPersonSheet(person: null)),
            ),
          ],
        ),
      ],
    );
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Meera');
    final add = find.widgetWithText(FilledButton, 'Add');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await settle(tester);
    final people = (await tester.runAsync(() => db.modePeopleIds(id)))!;
    expect(people, hasLength(1));
    await unmount(tester);
  });
}
