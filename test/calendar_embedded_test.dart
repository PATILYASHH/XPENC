import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('embedded: false (default) still shows its own app bar', (
    tester,
  ) async {
    await pump(tester, const CalendarScreen());
    expect(tester.takeException(), isNull);
    expect(
      find.ancestor(
        of: find.text('Calendar'),
        matching: find.byWidgetPredicate((w) => w is AppBar),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('embedded: true renders no app bar of its own', (tester) async {
    await pump(tester, const CalendarScreen(embedded: true));
    expect(tester.takeException(), isNull);
    expect(find.byWidgetPredicate((w) => w is AppBar), findsNothing);
    await unmount(tester);
  });

  Future<ProviderContainer> pumpEmbedded(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    // In a router, as in the app — the ➕ sheet hands off to `/add`.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const CalendarScreen(embedded: true),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    return container;
  }

  /// A day of this month that isn't today.
  final now = DateTime.now();
  final otherDay = now.day == 1 ? 2 : 1;
  Finder gridDay(int day) =>
      find.descendant(of: find.byType(GridView), matching: find.text('$day'));

  testWidgets('embedded: the ➕ signal offers money in, money out and a '
      'reminder, and Reminder still opens the reminder sheet', (tester) async {
    final container = await pumpEmbedded(tester);

    container.read(calendarAddSignalProvider.notifier).state++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Money in'), findsOneWidget);
    expect(find.text('Money out'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);

    await tester.tap(find.text('Reminder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('New reminder'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('embedded: Today shows once another day of this month is '
      'picked, and goes once back on today', (tester) async {
    final container = await pumpEmbedded(tester);
    expect(container.read(calendarAwayFromTodayProvider), isFalse);

    await tester.tap(gridDay(otherDay));
    await tester.pump();
    expect(container.read(calendarAwayFromTodayProvider), isTrue);

    container.read(calendarGoToTodaySignalProvider.notifier).state++;
    await tester.pump();
    expect(container.read(calendarAwayFromTodayProvider), isFalse);

    await unmount(tester);
  });

  testWidgets('standalone: the Today action follows the selected day', (
    tester,
  ) async {
    await pump(tester, const CalendarScreen());
    final today = find.byTooltip('Today');
    expect(today, findsNothing);

    await tester.tap(gridDay(otherDay));
    await tester.pump();
    expect(today, findsOneWidget);

    await tester.tap(today);
    await tester.pump();
    expect(today, findsNothing);
    expect(
      find.text(DateFormat('EEE, d MMM yyyy').format(now)),
      findsOneWidget,
      reason: 'today is selected again',
    );

    await unmount(tester);
  });

  testWidgets('Money in opens Add transaction on the selected day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Uri? opened;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const CalendarScreen()),
        GoRoute(
          path: '/add',
          builder: (_, state) {
            opened = state.uri;
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    await tester.tap(gridDay(otherDay));
    await tester.pump();
    await tester.tap(find.byTooltip('Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Money in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final day = DateTime(now.year, now.month, otherDay);
    expect(opened?.queryParameters, {
      'type': 'income',
      'date': DateFormat('yyyy-MM-dd').format(day),
    });

    await unmount(tester);
  });
}
