import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/transactions/transaction_filters.dart';

/// GitHub #121: "Filter Transaction by Grouping week" — a week-at-a-time
/// stepper alongside the existing custom date-range picker. The ISO week
/// math itself is covered (fast, no widget tree) in iso_week_test.dart —
/// these prove the sheet renders and wires it into `TransactionFilters`
/// correctly.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    TransactionFilters initial = const TransactionFilters(),
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showModalBottomSheet<TransactionFilters>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TransactionFiltersSheet(initial: initial),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('defaults to Custom range, showing "Any time"', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('Any time'), findsOneWidget);
    expect(find.text('Previous week'), findsNothing);
    await unmount(tester);
  });

  testWidgets(
    'switching to Week mode immediately shows the current week',
    (tester) async {
      await pumpAndOpen(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Week'));
      await tester.pump();

      expect(find.text('Any time'), findsNothing);
      expect(find.byTooltip('Previous week'), findsOneWidget);
      // Some "Week N, YYYY · ..." label is now showing.
      expect(find.textContaining('Week '), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets(
    'stepping back a week changes the shown label, and Apply carries a '
    'Monday-Sunday range',
    (tester) async {
      TransactionFilters? applied;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      applied =
                          await showModalBottomSheet<TransactionFilters>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const TransactionFiltersSheet(
                              initial: TransactionFilters(),
                            ),
                          );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Week'));
      await tester.pump();
      final firstLabel = tester
          .widget<Text>(find.textContaining('Week ').first)
          .data;

      await tester.tap(find.byTooltip('Previous week'));
      await tester.pump();
      final secondLabel = tester
          .widget<Text>(find.textContaining('Week ').first)
          .data;
      expect(secondLabel, isNot(firstLabel));

      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(applied, isNotNull);
      final range = applied!.dateRange!;
      expect(range.start.weekday, DateTime.monday);
      expect(range.end.weekday, DateTime.sunday);
      expect(range.end.difference(range.start).inDays, 6);
      await unmount(tester);
    },
  );
}
