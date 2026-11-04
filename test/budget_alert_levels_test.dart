import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/notifications/notification_service.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/budgets/budgets_screen.dart';

/// #186: a budget can alert at several levels — 50%, 80%, 100% — each once
/// a period.
void main() {
  group('which level fires', () {
    test('the highest newly reached one, the rest passed quietly', () {
      final step = budgetAlertStep(
        levels: [50, 80, 100],
        pct: 0.85,
        claimed: {},
      );
      expect(step.fire, 80);
      expect(step.pass, [50]);
    });

    test('a level already seen this period stays quiet', () {
      final step = budgetAlertStep(
        levels: [50, 80, 100],
        pct: 0.85,
        claimed: {50, 80},
      );
      expect(step.fire, isNull);
      expect(step.pass, isEmpty);
    });

    test('climbing on, the next level fires', () {
      final step = budgetAlertStep(
        levels: [50, 80, 100],
        pct: 1.0,
        claimed: {50, 80},
      );
      expect(step.fire, 100);
    });

    test('over budget, the overspent alert speaks for every level', () {
      final step = budgetAlertStep(
        levels: [50, 80, 100],
        pct: 1.2,
        claimed: {50},
      );
      expect(step.fire, isNull);
      expect(step.pass, [80, 100]);
    });

    test('an older build\'s one alert covers the levels up to it', () {
      final step = budgetAlertStep(
        levels: [50, 80, 90],
        pct: 0.85,
        claimed: {},
        legacyUpTo: 80,
      );
      expect(step.fire, isNull);
      expect(
        budgetAlertStep(
          levels: [50, 80, 90],
          pct: 0.92,
          claimed: {},
          legacyUpTo: 80,
        ).fire,
        90,
      );
    });
  });

  group('stored levels', () {
    late AppDatabase db;
    late int food;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      food = (await db.watchCategories(CategoryKind.expense).first).first.id;
    });
    tearDown(() => db.close());

    Future<BudgetRow> budget() => (db.select(
      db.budgets,
    )..where((b) => b.categoryId.equals(food))).getSingle();

    test('a budget from before keeps its one level', () async {
      await db.upsertBudget(
        categoryId: food,
        amount: Money.fromRupees(5000),
        alertThresholdPct: 85,
      );
      final b = await budget();
      expect(b.alertLevels, isNull);
      expect(b.alertLevelsPct, [85]);
    });

    test('several levels are stored sorted, once each, 1–100', () async {
      await db.upsertBudget(
        categoryId: food,
        amount: Money.fromRupees(5000),
        alertLevels: [100, 50, 80, 50, 0, 140],
      );
      final b = await budget();
      expect(b.alertLevelsPct, [50, 80, 100]);
      expect(b.alertThresholdPct, 50, reason: 'the lowest drives "nearly"');
    });

    test('no levels at all leaves only going over', () async {
      await db.upsertBudget(
        categoryId: food,
        amount: Money.fromRupees(5000),
        alertLevels: [],
      );
      final b = await budget();
      expect(b.alertLevelsPct, isEmpty);
      expect(b.alertThresholdPct, 100);
    });

    test('an edit that doesn\'t touch the levels keeps them', () async {
      await db.upsertBudget(
        categoryId: food,
        amount: Money.fromRupees(5000),
        alertLevels: [50, 90],
      );
      await db.upsertBudget(categoryId: food, amount: Money.fromRupees(6000));
      expect((await budget()).alertLevelsPct, [50, 90]);
    });

    test('junk in the stored text is dropped', () {
      expect(parseBudgetAlertLevels('80, x,50,,101'), [50, 80]);
      expect(parseBudgetAlertLevels(null), isNull);
    });
  });

  test('a v90 database gains the column on upgrade', () async {
    final dir = Directory.systemTemp.createTempSync('xpenc_levels_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/v90.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    final food =
        (await db.watchCategories(CategoryKind.expense).first).first.id;
    await db.upsertBudget(categoryId: food, amount: Money.fromRupees(5000));
    await db.customStatement('ALTER TABLE budgets DROP COLUMN alert_levels');
    await db.customStatement('PRAGMA user_version = 90');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final b = await (db.select(db.budgets)).getSingle();
    expect(b.alertLevels, isNull);
    expect(b.alertLevelsPct, [80]);
  });

  testWidgets('the budget sheet turns one level into several', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // A budget saved before #186, alerting at its one 80%.
    final existing = await tester.runAsync(() async {
      final category =
          (await db.watchCategories(CategoryKind.expense).first).first;
      await db.upsertBudget(
        categoryId: category.id,
        amount: Money.fromRupees(4000),
      );
      final budget = await (db.select(db.budgets)).getSingle();
      return (
        budget: budget,
        category: category,
        spent: const Money.zero(),
        effectiveAmount: budget.amount,
        fraction: 0.0,
        overspent: false,
        nearingLimit: false,
      );
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BudgetEditSheet(
                category: existing!.category,
                existing: existing,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    FilterChip chip(String label) =>
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
    expect(chip('80%').selected, isTrue);
    expect(chip('50%').selected, isFalse);
    await tester.tap(find.widgetWithText(FilterChip, '50%'));
    await tester.tap(find.widgetWithText(FilterChip, '100%'));
    await tester.pump();
    expect(chip('50%').selected, isTrue);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    final b = await tester.runAsync(() => (db.select(db.budgets)).getSingle());
    expect(b!.alertLevelsPct, [50, 80, 100]);
    expect(tester.takeException(), isNull);
    // Unmount first: the sheet's open database streams would otherwise
    // keep the close in tearDown waiting.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
