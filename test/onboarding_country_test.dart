import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xpenc/core/countries.dart';
import 'package:xpenc/core/currency.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/onboarding/onboarding_screen.dart';

/// The first-run country pick: every listed country resolves to a currency
/// the app carries, and onboarding writes the pick as the parent currency.
void main() {
  group('kCountries', () {
    test("every country's currency is one the app carries", () {
      for (final c in kCountries) {
        expect(
          currencyForCode(c.currencyCode).code,
          c.currencyCode,
          reason: '${c.name} → ${c.currencyCode}',
        );
      }
    });

    test('codes are unique, two upper-case letters', () {
      final codes = kCountries.map((c) => c.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
      for (final code in codes) {
        expect(code, matches(RegExp(r'^[A-Z]{2}$')));
      }
    });

    test('names are in A–Z order, which the list headers rely on', () {
      for (var i = 1; i < kCountries.length; i++) {
        expect(
          kCountries[i - 1].name[0].compareTo(kCountries[i].name[0]),
          lessThanOrEqualTo(0),
          reason: '${kCountries[i - 1].name} before ${kCountries[i].name}',
        );
      }
    });

    test('a flag is the two regional-indicator letters of the code', () {
      expect(countryForCode('IN')!.flag, '🇮🇳');
      expect(countryForCode('us')!.flag, '🇺🇸');
    });

    test('search matches name, alias, code and currency', () {
      bool hit(String code, String q) => countryForCode(code)!.matches(q);
      expect(hit('GB', 'brit'), isTrue);
      expect(hit('US', 'usa'), isTrue);
      expect(hit('DE', 'euro'), isTrue);
      expect(hit('IN', 'rupee'), isTrue);
      expect(hit('IN', 'inr'), isTrue);
      expect(hit('IN', 'euro'), isFalse);
    });

    test('the region suggestion skips locales with no listed country', () {
      expect(
        countryForLocales(const [Locale('en'), Locale('hi', 'IN')])?.code,
        'IN',
      );
      expect(countryForLocales(const [Locale('en')]), isNull);
      expect(countryForLocales(const [Locale('en', 'AQ')]), isNull);
    });
  });

  group('OnboardingScreen country step', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pumpOnboarding(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const OnboardingScreen()),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const Scaffold(body: Text('dashboard')),
          ),
        ],
      );
      tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    Future<void> toCountryStep(WidgetTester tester) async {
      await tester.tap(find.text('Next'));
      await settle(tester);
      await tester.tap(find.text("I'm new here"));
      await settle(tester);
      expect(find.text('Where do you live?'), findsOneWidget);
    }

    FilledButton nextButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'));

    testWidgets('a picked country becomes the parent currency on finish', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await toCountryStep(tester);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'germ');
      await settle(tester);
      await tester.tap(find.text('Germany'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      // The card now previews the euro.
      expect(find.text('Euro · EUR'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await settle(tester);
      await tester.tap(find.text('Skip'));
      await settle(tester);
      await tester.tap(find.text('Get Started'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await settle(tester);

      final settings = await tester.runAsync(() => db.getSettings());
      expect(settings!.currencyCode, 'EUR');
      expect(settings.onboarded, isTrue);
      await unmount(tester);
    });

    testWidgets('with no region to suggest, Next waits for a pick', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpOnboarding(tester);
      await toCountryStep(tester);
      expect(find.text('Pick your country'), findsOneWidget);
      expect(nextButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'india');
      await settle(tester);
      await tester.tap(find.text('India'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(nextButton(tester).onPressed, isNotNull);
      await unmount(tester);
    });

    testWidgets('the region pre-selects its country and says so', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'IN')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpOnboarding(tester);
      await toCountryStep(tester);
      expect(find.text('Indian Rupee · INR'), findsOneWidget);
      expect(find.text("Suggested from your phone's region"), findsOneWidget);
      // Lakh grouping, the rupee's own.
      expect(find.text('₹12,34,567.00'), findsOneWidget);
      expect(nextButton(tester).onPressed, isNotNull);
      await unmount(tester);
    });
  });
}
