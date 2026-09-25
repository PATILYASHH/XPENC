import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/settings/bottom_nav_settings_screen.dart';
import 'package:xpenc/features/settings/currency_settings_screen.dart';
import 'package:xpenc/features/settings/dashboard_settings_screen.dart';
import 'package:xpenc/features/settings/data_settings_screen.dart';
import 'package:xpenc/features/settings/font_settings_screen.dart';
import 'package:xpenc/features/settings/general_settings_screen.dart';
import 'package:xpenc/features/settings/mode_budgeting_settings_screen.dart';
import 'package:xpenc/features/settings/notifications_settings_screen.dart';
import 'package:xpenc/features/settings/persons_settings_screen.dart';
import 'package:xpenc/features/settings/quick_actions_settings_screen.dart';
import 'package:xpenc/features/settings/security_privacy_settings_screen.dart';
import 'package:xpenc/features/settings/settings_screen.dart';
import 'package:xpenc/features/settings/widgets_screen.dart';
import 'package:xpenc/features/transactions/transaction_detail_screen.dart';

/// GitHub #137: with the app drawing edge-to-edge, a ListView given an
/// explicit `padding` no longer adds the system nav bar's height itself, so
/// the last items sat under a 3-button nav bar and could never be scrolled
/// into view. Every affected page must add the bottom inset back.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const navBarDp = 48.0;

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(bottom: navBarDp * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: navBarDp * 3);
    addTearDown(tester.view.reset);

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

  void expectRoomForNavBar(WidgetTester tester) {
    final list = tester.widget<ListView>(find.byType(ListView).first);
    final padding = list.padding!.resolve(TextDirection.ltr);
    expect(padding.bottom, greaterThanOrEqualTo(navBarDp + 32));
  }

  final screens = <String, Widget>{
    'Settings': const SettingsScreen(),
    'General': const GeneralSettingsScreen(),
    'Mode & Budgeting': const ModeBudgetingSettingsScreen(),
    'Persons': const PersonsSettingsScreen(),
    'Security & Privacy': const SecurityPrivacySettingsScreen(),
    'Notifications': const NotificationsSettingsScreen(),
    'Quick Actions': const QuickActionsSettingsScreen(),
    'Data': const DataSettingsScreen(),
    'Currency': const CurrencySettingsScreen(),
    'Dashboard': const DashboardSettingsScreen(),
    'Font': const FontSettingsScreen(),
    'Bottom nav': const BottomNavSettingsScreen(),
    'Widgets': const WidgetsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} leaves room for the nav bar at the bottom', (
      tester,
    ) async {
      await pump(tester, entry.value);
      expectRoomForNavBar(tester);
      await unmount(tester);
    });
  }

  testWidgets('Transaction detail leaves room for the nav bar at the bottom', (
    tester,
  ) async {
    final accounts = await tester.runAsync(() => db.watchAccounts().first);
    final cash = accounts!.firstWhere((a) => a.type == AccountType.cash).id;
    final categories = await tester.runAsync(
      () => db.watchCategories(CategoryKind.expense).first,
    );
    final txId = (await tester.runAsync(
      () => db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(60),
        accountId: cash,
        categoryId: categories!.first.id,
        date: DateTime(2026, 9, 23),
      ),
    ))!;

    await pump(tester, TransactionDetailScreen(transactionId: txId));
    expectRoomForNavBar(tester);
    await unmount(tester);
  });
}
