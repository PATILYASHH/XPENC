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

/// Pay / Request on a person's page: one button in the top bar (Request
/// when they owe you, Pay when you owe them) opening a sheet of payment
/// methods — same three rules as `smoke_test.dart` (DB work inside
/// `runAsync`, never `pumpAndSettle`, unmount before the test ends) since
/// it pumps against a real database.
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
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openPaySheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('person-pay')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  /// The method's row in the sheet, and whether it reads "set up".
  String subtitleOf(WidgetTester tester, String method) {
    final tile = find.byKey(Key('pay-method-$method'));
    expect(tile, findsOneWidget, reason: method);
    final texts = tester
        .widgetList<Text>(find.descendant(of: tile, matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .toList();
    return texts.last;
  }

  testWidgets(
    'balance positive: the bar offers Request; with no IDs of mine every '
    'method says where to add it',
    (tester) async {
      final ram = await tester.runAsync(() async {
        final id = await db.addPerson('Ram');
        await db.addPersonEntry(
          personId: id,
          direction: PersonDirection.theyOwe,
          amount: Money.fromRupees(500),
          date: DateTime.now(),
          accountId: await cashId(),
        );
        return id;
      });

      await pump(tester, PersonDetailScreen(personId: ram!));
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Request'), findsOneWidget);
      expect(find.byTooltip('Pay'), findsNothing);

      await openPaySheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Request from Ram'), findsOneWidget);
      expect(subtitleOf(tester, 'UPI'), 'Add your UPI ID in Settings');
      expect(subtitleOf(tester, 'PayPal'), 'Add your PayPal.me ID in Settings');
      expect(subtitleOf(tester, 'Venmo'), 'Add your Venmo username in Settings');
      expect(subtitleOf(tester, 'Cash App'), 'Add your Cashtag in Settings');
      expect(
        subtitleOf(tester, 'Revolut'),
        'Add your Revolut username in Settings',
      );
      await unmount(tester);
    },
  );

  testWidgets('setting my UPI ID readies only UPI in the Request sheet', (
    tester,
  ) async {
    final ram = await tester.runAsync(() async {
      final id = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: id,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime.now(),
        accountId: await cashId(),
      );
      await db.setMyUpiId('me@okhdfcbank');
      return id;
    });

    await pump(tester, PersonDetailScreen(personId: ram!));
    await openPaySheet(tester);
    expect(tester.takeException(), isNull);
    expect(subtitleOf(tester, 'UPI'), 'me@okhdfcbank');
    expect(subtitleOf(tester, 'PayPal'), 'Add your PayPal.me ID in Settings');
    await unmount(tester);
  });

  testWidgets(
    "balance negative: the bar offers Pay, and their UPI ID readies it",
    (tester) async {
      final ram = await tester.runAsync(() async {
        final id = await db.addPerson('Ram');
        await db.addPersonEntry(
          personId: id,
          direction: PersonDirection.iOwe,
          amount: Money.fromRupees(300),
          date: DateTime.now(),
          accountId: await cashId(),
        );
        return id;
      });

      await pump(tester, PersonDetailScreen(personId: ram!));
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Pay'), findsOneWidget);
      expect(find.byTooltip('Request'), findsNothing);
      await openPaySheet(tester);
      expect(find.text('Pay Ram'), findsOneWidget);
      expect(subtitleOf(tester, 'UPI'), "Add Ram's UPI ID");
      await unmount(tester);

      await tester.runAsync(
        () => db.updatePerson(id: ram, name: 'Ram', upiId: 'ram@okaxis'),
      );
      await pump(tester, PersonDetailScreen(personId: ram));
      await openPaySheet(tester);
      expect(subtitleOf(tester, 'UPI'), 'ram@okaxis');
      await unmount(tester);
    },
  );

  testWidgets('a settled balance shows neither Pay nor Request', (
    tester,
  ) async {
    final ram = await tester.runAsync(() => db.addPerson('Ram'));

    await pump(tester, PersonDetailScreen(personId: ram!));
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('person-pay')), findsNothing);
    await unmount(tester);
  });
}
