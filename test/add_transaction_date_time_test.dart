import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

/// When an entry happened: a small `23 NOV 2:17 PM` at the amount's
/// bottom-left, which opens the date and the time together in one sheet
/// (GitHub #124: picking one never disturbs the other). Untouched, a new
/// entry is simply *now*. The date/time-combining logic itself is covered
/// (fast, no widget tree) in date_time_combine_test.dart — these just prove
/// the screen renders and wires it correctly.
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

  final label = find.byKey(const Key('whenLabel'));
  String labelText(WidgetTester tester) => tester
      .widget<Text>(find.descendant(of: label, matching: find.byType(Text)))
      .data!;

  testWidgets('an edited entry shows its own date and time, small, under '
      'the amount — no Date card', (tester) async {
    final id = await tester.runAsync(() async {
      return db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(200),
        accountId: await cashId(),
        date: DateTime(2020, 7, 8, 15, 44),
      );
    });

    await pump(tester, AddTransactionScreen(transactionId: id));
    expect(tester.takeException(), isNull);

    // Not this year, so the year shows.
    expect(labelText(tester), '8 JUL 2020 3:44 PM');
    final amount = tester.getRect(find.byKey(const Key('amountDisplay')));
    final when = tester.getRect(label);
    expect(when.top, greaterThanOrEqualTo(amount.bottom - 1));
    expect(when.left, lessThan(amount.left));
    // Above "Paid via".
    expect(when.bottom, lessThan(tester.getTopLeft(find.text('Paid via')).dy));
    expect(find.byIcon(Icons.event_outlined), findsNothing);
    await unmount(tester);
  });

  testWidgets('a new entry is now, this year shown without the year', (
    tester,
  ) async {
    await pump(tester, const AddTransactionScreen(initialType: TxType.expense));
    final now = DateTime.now();
    expect(
      labelText(tester),
      startsWith(DateFormat('d MMM ').format(now).toUpperCase()),
    );
    expect(labelText(tester), isNot(contains('${now.year}')));
    await unmount(tester);
  });

  testWidgets("a day handed in by the calendar is the new entry's date", (
    tester,
  ) async {
    await pump(
      tester,
      AddTransactionScreen(
        initialType: TxType.income,
        initialDate: DateTime(2020, 7, 8),
      ),
    );
    expect(tester.takeException(), isNull);

    expect(labelText(tester), startsWith('8 JUL 2020 '));
    await unmount(tester);
  });

  testWidgets('the label opens the date and time together; a new day keeps '
      'the time, and a cancelled time keeps both', (tester) async {
    final id = await tester.runAsync(() async {
      return db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(200),
        accountId: await cashId(),
        date: DateTime(2020, 7, 8, 15, 44),
      );
    });

    await pump(tester, AddTransactionScreen(transactionId: id));
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);

    // The time, on its own picker, cancelled: nothing moves.
    await tester.tap(find.byKey(const Key('whenTime')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Yesterday, at the same time.
    await tester.tap(find.text('Yesterday'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('whenDone')));
    await tester.pumpAndSettle();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dayPattern = yesterday.year == DateTime.now().year
        ? 'd MMM'
        : 'd MMM yyyy';
    final day = DateFormat(dayPattern).format(yesterday).toUpperCase();
    expect(labelText(tester), '$day 3:44 PM');

    // "Now" gives the entry back to the clock.
    await tester.tap(label);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('whenNow')));
    await tester.pumpAndSettle();
    expect(
      labelText(tester),
      startsWith(DateFormat('d MMM ').format(DateTime.now()).toUpperCase()),
    );
    await unmount(tester);
  });
}
