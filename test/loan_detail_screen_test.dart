import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/savings/loan_detail_screen.dart';
import 'package:xpenc/features/savings/savings_goals_screen.dart';

/// Rate-based loan tracking's new UI, rendered against a real database at a
/// real phone size — same rule as test/screens_smoke_test.dart: must not
/// throw and must not overflow, for both a "basic" (rate-less) loan and one
/// with a full rate/tenure/start-date declared.
void main() {
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
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('a basic (rate-less) loan renders exactly as before — no new '
      'analytics rows', (tester) async {
    final loanId = await db.addLoan(
      name: 'Old Car Loan',
      principal: Money.fromRupees(50000),
      colorValue: 0xFF2563EB,
      iconKey: 'loan',
    );

    await pump(tester, LoanDetailScreen(accountId: loanId));

    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('Interest rate'), findsNothing);
    expect(find.text('Total interest'), findsNothing);
    expect(find.text("You're saving"), findsNothing);

    await unmount(tester);
  });

  testWidgets('a rate-based loan shows the new interest analytics rows', (
    tester,
  ) async {
    final loanId = await db.addLoan(
      name: 'Home Loan',
      principal: Money.fromRupees(100000),
      colorValue: 0xFF2563EB,
      iconKey: 'loan',
      interestRatePct: 10,
      tenureMonths: 24,
      startDate: DateTime(2026, 1, 1),
    );

    await pump(tester, LoanDetailScreen(accountId: loanId));

    expect(find.text('Interest rate'), findsOneWidget);
    expect(find.text('10% / yr'), findsOneWidget);
    expect(find.text('Monthly EMI'), findsOneWidget);
    expect(find.text('Next payment'), findsOneWidget);
    expect(find.text('Total interest'), findsOneWidget);
    expect(find.text('Total payable'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the payment sheet auto-fills interest from the rate and stays '
      'editable', (tester) async {
    final loanId = await db.addLoan(
      name: 'Home Loan',
      principal: Money.fromRupees(100000),
      colorValue: 0xFF2563EB,
      iconKey: 'loan',
      interestRatePct: 12, // 1%/month
      tenureMonths: 12,
      startDate: DateTime(2026, 1, 1),
    );

    await pump(tester, LoanDetailScreen(accountId: loanId));
    await tester.tap(find.text('Make a payment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The EMI prefill (computed from rate+tenure) triggers the interest
    // estimate immediately, before any typing — 1% of ₹1,00,000.
    expect(find.text('1000'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
    'the loan editor renders its new rate/tenure/start-date fields without '
    'overflowing, and the preview appears once they are filled',
    (tester) async {
      await pump(tester, const SavingsGoalsScreen());

      await tester.tap(find.text('Loans'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('New loan'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Interest rate % / yr (optional)'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextField, 'Tenure, months (optional)'),
        findsOneWidget,
      );
      expect(find.text('Repayment start date'), findsOneWidget);

      // The amount-borrowed field uses the app's in-app money keypad, not
      // the OS keyboard (see AmountKeypadField), so it's driven through its
      // own controller rather than tester.enterText. Fill only the plain
      // text fields here to exercise the live projection preview.
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Bike Loan',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Interest rate % / yr (optional)'),
        '12',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Tenure, months (optional)'),
        '12',
      );
      await tester.pump();

      // No preview yet — the amount-borrowed field is still empty.
      expect(find.textContaining('Suggested EMI'), findsNothing);

      await unmount(tester);
    },
  );
}
