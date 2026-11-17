import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/l10n/l10n.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/accounts/accounts_screen.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';
import 'package:xpenc/features/ai/ai_memory_screen.dart';
import 'package:xpenc/features/ai/ask_exo_screen.dart';
import 'package:xpenc/features/ai/local_ai_settings_screen.dart';
import 'package:xpenc/features/auto/auto_screen.dart';
import 'package:xpenc/features/calendar/calendar_screen.dart';
import 'package:xpenc/features/categories/categories_screen.dart';
import 'package:xpenc/features/more/more_screen.dart';
import 'package:xpenc/features/onboarding/onboarding_screen.dart';
import 'package:xpenc/features/persons/persons_screen.dart';
import 'package:xpenc/features/reports/account_reports_screen.dart';
import 'package:xpenc/features/reports/stats_screen.dart';
import 'package:xpenc/features/savings/archived_goals_loans_screen.dart';
import 'package:xpenc/features/savings/savings_goals_screen.dart';
import 'package:xpenc/features/settings/general_settings_screen.dart';
import 'package:xpenc/features/settings/security_privacy_settings_screen.dart';
import 'package:xpenc/features/settings/settings_screen.dart';
import 'package:xpenc/features/transactions/transactions_screen.dart';

/// Pseudo-localisation (GitHub #191): every catalogue string is shown as
/// ⟦…⟧, so any interface text on these screens that *isn't* bracketed never
/// went through tr() — it would stay English in every language. Data the
/// test itself seeds (account and category names) is allowed.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() {
    L10n.debugUse('en', const {});
    return db.close();
  });

  final catalog = (jsonDecode(
    File('tool/l10n/catalog.json').readAsStringSync(),
  ) as List).cast<String>();
  final pseudo = {for (final k in catalog) k: '⟦$k⟧'};

  Future<List<String>> unmarked(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    L10n.debugUse('xx', pseudo);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: L10nScope(code: 'xx', child: screen),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Names the default database seeds — data, not interface text.
    final seeded = <String>{
      for (final a in await tester.runAsync(() => db.watchAccounts().first) ??
          const [])
        a.name,
      for (final c
          in await tester.runAsync(() => db.select(db.categories).get()) ??
              const [])
        c.name,
    };
    final out = <String>{};
    for (final e in find.byType(RichText).evaluate()) {
      final text = (e.widget as RichText).text.toPlainText();
      for (final line in text.split('\n')) {
        final t = line.trim();
        if (t.isEmpty || t.contains('⟦') || t.contains('⟧')) continue;
        if (!RegExp('[A-Za-z]{2}').hasMatch(t)) continue;
        if (seeded.contains(t)) continue;
        out.add(t);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    return out.toList()..sort();
  }

  final screens = <String, Widget Function()>{
    'Settings': () => const SettingsScreen(),
    'General settings': () => const GeneralSettingsScreen(),
    'Security': () => const SecurityPrivacySettingsScreen(),
    'More': () => const MoreScreen(),
    'Accounts': () => const AccountsScreen(),
    'Transactions': () => const TransactionsScreen(),
    'Persons': () => const PersonsScreen(),
    'Stats': () => const StatsScreen(),
    'Account reports': () => const AccountReportsScreen(),
    'Categories': () => const CategoriesScreen(),
    'Auto': () => const AutoScreen(),
    'Goals & loans': () => const SavingsGoalsScreen(),
    'Archived goals & loans': () => const ArchivedGoalsLoansScreen(),
    'Local AI': () => const LocalAiSettingsScreen(),
    'AI Memory': () => const AiMemoryScreen(),
    'Ask Exo': () => const AskExoScreen(),
    'Calendar': () => const CalendarScreen(),
    'Onboarding': () => const OnboardingScreen(),
    'Add transaction': () => const AddTransactionScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key}: all interface text is translatable', (
      tester,
    ) async {
      final found = await unmarked(tester, entry.value());
      if (found.isNotEmpty) {
        // ignore: avoid_print
        print('UNTRANSLATED [${entry.key}]: ${found.join(' | ')}');
      }
    });
  }
}
