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

/// The Pay/Request row on a person's detail page — same three rules as
/// `smoke_test.dart` (DB work inside `runAsync`, never `pumpAndSettle`,
/// unmount before the test ends) since it pumps against a real database.
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  ButtonStyleButton? findButton(String label) {
    final finder = find.widgetWithText(OutlinedButton, label);
    if (finder.evaluate().isEmpty) return null;
    return finder.evaluate().first.widget as ButtonStyleButton;
  }

  testWidgets(
    'balance positive shows Request, not Pay; app buttons disabled with no '
    'my-UPI-ID set',
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

      expect(find.text('Request'), findsOneWidget);
      expect(find.text('Pay'), findsNothing);
      expect(findButton('Google Pay')!.onPressed, isNull);
      expect(findButton('PhonePe')!.onPressed, isNull);
      expect(
        find.text('Add your UPI ID in Settings to request money'),
        findsOneWidget,
      );
      await unmount(tester);
    },
  );

  testWidgets(
    'setting my UPI ID enables the Request app buttons',
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
        await db.setMyUpiId('me@okhdfcbank');
        return id;
      });

      await pump(tester, PersonDetailScreen(personId: ram!));
      expect(tester.takeException(), isNull);

      expect(findButton('Google Pay')!.onPressed, isNotNull);
      expect(findButton('PhonePe')!.onPressed, isNotNull);
      expect(
        find.text('Add your UPI ID in Settings to request money'),
        findsNothing,
      );
      await unmount(tester);
    },
  );

  testWidgets(
    'balance negative shows Pay, not Request; app buttons disabled with no '
    "person UPI ID, enabled after editing the person",
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

      expect(find.text('Pay'), findsOneWidget);
      expect(find.text('Request'), findsNothing);
      expect(findButton('Google Pay')!.onPressed, isNull);
      expect(
        find.text("Add Ram's UPI ID to pay them directly"),
        findsOneWidget,
      );

      await tester.runAsync(
        () => db.updatePerson(
          id: ram,
          name: 'Ram',
          upiId: 'ram@okaxis',
        ),
      );
      await pump(tester, PersonDetailScreen(personId: ram));
      expect(findButton('Google Pay')!.onPressed, isNotNull);
      expect(findButton('PhonePe')!.onPressed, isNotNull);
      await unmount(tester);
    },
  );

  testWidgets('a settled balance shows neither Pay nor Request', (
    tester,
  ) async {
    final ram = await tester.runAsync(() => db.addPerson('Ram'));

    await pump(tester, PersonDetailScreen(personId: ram!));
    expect(tester.takeException(), isNull);

    expect(find.text('Pay'), findsNothing);
    expect(find.text('Request'), findsNothing);
    await unmount(tester);
  });
}
