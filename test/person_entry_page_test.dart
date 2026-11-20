import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/persons/person_detail_screen.dart';
import 'package:xpenc/features/persons/person_entry_detail_screen.dart';
import 'package:xpenc/features/share/share_cards.dart';
import 'package:xpenc/features/share/share_models.dart';

/// A person's history reads month by month, and tapping an entry opens its
/// own page — every detail, the balance after it, and Share / Edit /
/// Delete — instead of the edit sheet.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpRouter(WidgetTester tester, String initial) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/person/:id',
          builder: (_, s) =>
              PersonDetailScreen(personId: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/person/:id/entry/:entryId',
          builder: (_, s) => PersonEntryDetailScreen(
            personId: int.parse(s.pathParameters['id']!),
            entryId: int.parse(s.pathParameters['entryId']!),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 1, 9);
  final earlier = DateTime(now.year, now.month - 2, 15, 9);

  Future<int> seed() async {
    final id = await db.addPerson('Ram');
    await db.addPersonEntry(
      personId: id,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: earlier,
      note: 'Concert tickets',
    );
    await db.addPersonEntry(
      personId: id,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(200),
      date: thisMonth,
      note: 'Paid me back',
    );
    return id;
  }

  String monthLabel(DateTime m) => DateFormat(
    m.year == now.year ? 'MMMM' : 'MMMM yyyy',
  ).format(m).toUpperCase();

  testWidgets('history is grouped under each month, newest first', (
    tester,
  ) async {
    final ram = (await tester.runAsync(seed))!;
    await pumpRouter(tester, '/person/$ram');
    expect(tester.takeException(), isNull);

    final newer = find.text(monthLabel(thisMonth));
    final older = find.text(monthLabel(earlier));
    expect(newer, findsOneWidget);
    expect(older, findsOneWidget);
    expect(
      tester.getTopLeft(newer).dy,
      lessThan(tester.getTopLeft(older).dy),
    );
    await unmount(tester);
  });

  testWidgets('tapping an entry opens its page, not the edit sheet', (
    tester,
  ) async {
    final ram = (await tester.runAsync(seed))!;
    await pumpRouter(tester, '/person/$ram');

    await tester.tap(find.text('Concert tickets'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('Entry'), findsOneWidget);
    expect(find.text('You gave Ram'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    // Right after lending ₹500, Ram owed all of it.
    expect(find.text('Ram owes you'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets("the entry's Share opens a receipt of just that entry", (
    tester,
  ) async {
    final ram = (await tester.runAsync(seed))!;
    await pumpRouter(tester, '/person/$ram');
    await tester.tap(find.text('Concert tickets'));
    await settle(tester);

    await tester.tap(find.byKey(const Key('entry-share')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Share entry'), findsOneWidget);
    expect(find.byType(PersonEntryShareCard), findsOneWidget);
    await unmount(tester);
  });

  test('the balance after an entry runs in ledger order', () {
    PersonEntryRow row(int id, PersonDirection d, int rupees, DateTime date) =>
        PersonEntryRow(
          id: id,
          personId: 1,
          direction: d,
          amount: Money.fromRupees(rupees.toDouble()),
          date: date,
          createdAt: date,
        );
    final a = row(1, PersonDirection.theyOwe, 500, earlier);
    final b = row(2, PersonDirection.iOwe, 200, thisMonth);
    expect(PersonEntryShare.runningAfter([b, a], a), Money.fromRupees(500));
    expect(PersonEntryShare.runningAfter([b, a], b), Money.fromRupees(300));
  });
}
