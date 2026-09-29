import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/persons/settled_prompt_listener.dart';

/// The "Settled / Archive / Keep here" prompt that replaced the silent
/// auto-archive. Same rules as `smoke_test.dart`: DB work inside `runAsync`,
/// never `pumpAndSettle`, unmount before the test ends.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Lets streams deliver, then runs past the listener's debounce.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SettledPromptListener(child: Scaffold()),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> entry(int personId, PersonDirection direction) =>
      db.addPersonEntry(
        personId: personId,
        direction: direction,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 8),
      );

  testWidgets('reaching zero prompts, and Move to Settled settles them', (
    tester,
  ) async {
    final ram = (await tester.runAsync(() async {
      final id = await db.addPerson('Ram');
      await entry(id, PersonDirection.theyOwe);
      return id;
    }))!;
    await pump(tester);
    expect(find.text('All settled'), findsNothing);

    await tester.runAsync(() => entry(ram, PersonDirection.iOwe));
    await settle(tester);
    expect(find.text('All settled'), findsOneWidget);
    expect(find.text('Keep here'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);

    await tester.tap(find.text('Move to Settled'));
    await settle(tester);

    final row = (await tester.runAsync(() => db.watchPersons().first))!
        .firstWhere((p) => p.id == ram);
    expect(row.isSettled, isTrue);
    expect(row.isArchived, isFalse);
    await unmount(tester);
  });

  testWidgets('Keep here leaves them in place; no prompt for someone already '
      'at zero when the app opened', (tester) async {
    final ids = (await tester.runAsync(() async {
      final ram = await db.addPerson('Ram');
      await entry(ram, PersonDirection.theyOwe);
      final sita = await db.addPerson('Sita');
      await entry(sita, PersonDirection.theyOwe);
      await entry(sita, PersonDirection.iOwe);
      return (ram, sita);
    }))!;
    await pump(tester);
    expect(find.text('All settled'), findsNothing);

    await tester.runAsync(() => entry(ids.$1, PersonDirection.iOwe));
    await settle(tester);
    await tester.tap(find.text('Keep here'));
    await settle(tester);

    final people = (await tester.runAsync(() => db.watchPersons().first))!;
    expect(people.every((p) => !p.isSettled), isTrue);
    expect(people.map((p) => p.id), containsAll([ids.$1, ids.$2]));
    await unmount(tester);
  });
}
