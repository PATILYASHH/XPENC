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

  /// Tear the tree down inside the test so Drift's cleanup timer can fire —
  /// otherwise `flutter test` hangs/fails on a pending-timer assertion.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('embedded: false (default) still shows its own app bar', (
    tester,
  ) async {
    await pump(tester, const BudgetsScreen());
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(AppBar, 'Budgets'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('embedded: true renders no app bar of its own', (tester) async {
    await pump(tester, const BudgetsScreen(embedded: true));
    expect(tester.takeException(), isNull);
    expect(find.byType(AppBar), findsNothing);
    // The body itself still renders.
    expect(find.text('Categories'), findsOneWidget);

    await unmount(tester);
  });
}
