import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/accounts/add_account_sheet.dart';
import 'package:xpenc/features/auto/recurring_rule_sheet.dart';

/// GitHub #14: on a device with a 3-button navigation bar, several bottom
/// sheets drew their primary button behind it, and the Add Account sheet's
/// 5-segment type picker overflowed past the sheet's edge. Both symptoms
/// only ever showed up on a real button-nav device — gesture nav's inset is
/// thin enough that the same missing padding went unnoticed for months.
///
/// These tests fake a 48dp system nav bar (`tester.view.padding`) — a
/// gesture bar is closer to 24dp — so a regression here fails on CI even
/// though every developer's own phone uses gesture navigation.
///
/// Follows the three rules from test/smoke_test.dart: DB work inside
/// `runAsync`, never `pumpAndSettle` (Drift's live query stream and the
/// sheet's own animations never fully quiesce), unmount before the test ends.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// 360x800dp behind a simulated button-nav bar this tall.
  void pumpWithButtonNav(WidgetTester tester, {required double navBarDp}) {
    const dpr = 3.0;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = dpr;
    tester.view.padding = FakeViewPadding(bottom: navBarDp * dpr);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
  }

  Future<void> openSheet(
    WidgetTester tester,
    void Function(BuildContext) open,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => open(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    // Let the sheet's entrance animation (250ms) finish and Drift's
    // accounts stream resolve — bounded pumps, never pumpAndSettle.
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets(
    'Add Account sheet: the 5-segment type picker never overflows',
    (tester) async {
      pumpWithButtonNav(tester, navBarDp: 48);
      await openSheet(tester, showAddAccountSheet);

      expect(tester.takeException(), isNull);
      expect(find.text('Prepaid'), findsOneWidget);

      await unmount(tester);
    },
  );

  testWidgets(
    'Add Account sheet: the submit button clears a button-nav bar',
    (tester) async {
      const navBarDp = 48.0;
      pumpWithButtonNav(tester, navBarDp: navBarDp);
      await openSheet(tester, showAddAccountSheet);

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final buttonBottom = tester
          .getBottomLeft(find.widgetWithText(FilledButton, 'Add account'))
          .dy;

      expect(
        buttonBottom,
        lessThanOrEqualTo(screenHeight - navBarDp),
        reason: 'the button must sit above the simulated nav bar, not '
            'behind it',
      );

      await unmount(tester);
    },
  );

  testWidgets(
    'Recurring rule sheet: the submit button clears a button-nav bar',
    (tester) async {
      const navBarDp = 48.0;
      pumpWithButtonNav(tester, navBarDp: navBarDp);
      await openSheet(tester, showRecurringRuleSheet);

      // This sheet has enough fields to need scrolling, so the submit
      // button's on-screen position at rest isn't a meaningful check (it
      // may legitimately start below the fold). Check what actually
      // encodes the fix instead: the sheet's own bottom padding must
      // reserve at least the simulated nav bar's height.
      final paddings = tester
          .widgetList<Padding>(find.byType(Padding))
          .map((p) => p.padding.resolve(TextDirection.ltr).bottom);

      expect(
        paddings.any((bottom) => bottom >= navBarDp),
        isTrue,
        reason: 'no Padding in the sheet reserves the simulated nav bar '
            'inset ($navBarDp dp)',
      );

      await unmount(tester);
    },
  );
}
