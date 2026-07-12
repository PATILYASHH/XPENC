import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/widgets/money_text.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/dashboard/dashboard_screen.dart';
import 'package:xpenc/features/transactions/transactions_screen.dart';

/// A person movement has no category. Both the dashboard and the transactions
/// list used to fall through to the "no category" branch and render it as
/// **Uncategorised**, with a meaningless `more_horiz` glyph — the money had a
/// name attached and the UI threw it away.
void main() {
  group('labelForTxType', () {
    test('names the counterparty when there is one', () {
      expect(
        labelForTxType(TxType.personOut, personName: 'Asha'),
        'Gave to Asha',
      );
      expect(
        labelForTxType(TxType.personIn, personName: 'Asha'),
        'Received from Asha',
      );
    });

    test('degrades to a generic noun rather than an empty gap', () {
      expect(labelForTxType(TxType.personOut), 'Gave to person');
      expect(labelForTxType(TxType.personIn), 'Received from person');
    });

    test('every type has an icon, and none of them is a telephone', () {
      final phoneGlyphs = {
        Icons.call_made_rounded,
        Icons.call_received_rounded,
      };
      for (final type in TxType.values) {
        expect(phoneGlyphs, isNot(contains(iconForTxType(type))));
      }
      expect(iconForTxType(TxType.personOut), Icons.person_outline_rounded);
      expect(iconForTxType(TxType.personIn), Icons.person_outline_rounded);
    });
  });

  group('a person movement is labelled by person', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
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
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    /// Lending Asha money from cash. This writes a `personOut` ledger row.
    Future<void> lendToAsha() async {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      final asha = await db.addPerson('Asha');
      await db.addPersonEntry(
        personId: asha,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime.now(),
        accountId: cash,
      );
    }

    testWidgets('on the transactions list', (tester) async {
      await tester.runAsync(lendToAsha);

      await pump(tester, const TransactionsScreen());
      expect(tester.takeException(), isNull);

      expect(find.text('Gave to Asha'), findsOneWidget);
      expect(find.text('Uncategorised'), findsNothing);
      await unmount(tester);
    });

    testWidgets('on the dashboard', (tester) async {
      await tester.runAsync(lendToAsha);

      await pump(tester, const DashboardScreen());
      expect(tester.takeException(), isNull);

      // Recent sits below the fold on a 360x800 screen; a sliver list does not
      // build what it cannot show.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      expect(tester.takeException(), isNull);

      expect(find.text('Gave to Asha'), findsOneWidget);
      expect(find.text('Uncategorised'), findsNothing);
      await unmount(tester);
    });
  });
}
