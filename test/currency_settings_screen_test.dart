import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/settings/currency_settings_screen.dart';

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
          home: const CurrencySettingsScreen(),
        ),
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

  testWidgets('renders the parent currency and an empty rate list', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Currency'), findsWidgets);
    expect(find.text('PARENT CURRENCY'), findsOneWidget);
    expect(find.textContaining('INR'), findsWidgets);
    expect(
      find.textContaining("No exchange rates yet"),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('shows an existing rate in the list', (tester) async {
    await db.addCurrencyRate(
      currencyCode: 'USD',
      rateToBaseMicros: 83000000,
      effectiveAt: DateTime(2026, 1, 1),
    );

    await pump(tester);

    expect(find.textContaining('USD'), findsWidgets);
    expect(find.textContaining('83'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('adding a currency and its first rate shows up in the list', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Add a currency'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'USD');
    await tester.pumpAndSettle();
    await tester.tap(find.text('US Dollar').last);
    await tester.pumpAndSettle();

    final rateField = find.widgetWithText(TextField, 'Rate');
    expect(rateField, findsOneWidget);
    await tester.enterText(rateField, '83');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('USD'), findsWidgets);

    await unmount(tester);
  });
}
