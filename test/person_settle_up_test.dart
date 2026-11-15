import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/persons/person_detail_screen.dart';

/// A person's page says which way the money went — Money out (you gave)
/// and Money in (you got) — and Settle up clears the balance in one tap.
/// Same rules as `persons_upi_button_test.dart`: DB work in `runAsync`,
/// no `pumpAndSettle`, unmount before the end.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

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
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> person({required PersonDirection direction, int? rupees}) async {
    final id = await db.addPerson('Ram');
    if (rupees != null) {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      await db.addPersonEntry(
        personId: id,
        direction: direction,
        amount: Money.fromRupees(rupees),
        date: DateTime.now(),
        accountId: cash,
      );
    }
    return id;
  }

  testWidgets('Money out and Money in, no Settle with nothing owed', (
    tester,
  ) async {
    final ram = await tester.runAsync(
      () => person(direction: PersonDirection.theyOwe),
    );
    await pump(tester, PersonDetailScreen(personId: ram!));
    expect(find.byKey(const Key('person-money-out')), findsOneWidget);
    expect(find.byKey(const Key('person-money-in')), findsOneWidget);
    expect(find.text('Money out'), findsOneWidget);
    expect(find.text('Money in'), findsOneWidget);
    expect(find.text('They owe'), findsNothing);
    expect(find.text('I owe'), findsNothing);
    expect(find.byKey(const Key('person-settle')), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Settle up opens with the whole balance, money coming in', (
    tester,
  ) async {
    final ram = await tester.runAsync(
      () => person(direction: PersonDirection.theyOwe, rupees: 500),
    );
    await pump(tester, PersonDetailScreen(personId: ram!));
    final button = find.byKey(const Key('person-settle'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.textContaining('500')),
      findsOneWidget,
    );

    await tester.tap(button);
    await settle(tester);
    expect(find.text('Settle up'), findsOneWidget);
    expect(find.textContaining('They pay you back'), findsOneWidget);
    // The amount field starts at the whole balance.
    expect(find.textContaining('500'), findsWidgets);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('owing them, Settle up pays it back — money going out', (
    tester,
  ) async {
    final ram = await tester.runAsync(
      () => person(direction: PersonDirection.iOwe, rupees: 250),
    );
    await pump(tester, PersonDetailScreen(personId: ram!));
    await tester.tap(find.byKey(const Key('person-settle')));
    await settle(tester);
    expect(find.text('Settle up'), findsOneWidget);
    expect(find.textContaining('You pay back what you owe'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  test('a settle entry the other way takes the balance to zero', () async {
    final ram = await person(direction: PersonDirection.theyOwe, rupees: 500);
    await db.addPersonEntry(
      personId: ram,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(500),
      date: DateTime.now(),
      note: 'Settled up',
    );
    final balances = await db.watchAllPersonBalances().first;
    expect(balances[ram] ?? Money.zero(), Money.zero());
  });
}
