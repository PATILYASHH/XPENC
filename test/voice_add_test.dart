import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/voice/speech_input.dart';
import 'package:xpenc/core/voice/voice_parser.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';
import 'package:xpenc/features/voice_add/voice_add_bar.dart';
import 'package:xpenc/features/voice_add/voice_add_controller.dart';

/// A microphone that says whatever the test tells it to.
class FakeSpeech implements SpeechEngine {
  final _events = StreamController<SpeechEvent>.broadcast();
  var starts = 0;
  var stops = 0;
  var cancels = 0;
  SpeechStart answer = SpeechStart.ok;

  String _heard = '';

  void say(String text) {
    _heard = text;
    _events.add(SpeechPartial(text));
  }

  @override
  Stream<SpeechEvent> get events => _events.stream;

  @override
  Future<SpeechStart> start(String locale) async {
    starts++;
    return answer;
  }

  @override
  Future<void> stop() async {
    stops++;
    // Like the real one: stopping settles the last words.
    _events.add(SpeechFinal(_heard));
  }

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<bool> downloadLanguage(String locale) async => true;
}

void main() {
  group('country', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a country turns on its own payment methods', () async {
      await db.setCountry('US');
      var s = await db.getSettings();
      expect(s.countryCode, 'US');
      expect(
        (s.upiEnabled, s.paypalEnabled, s.venmoEnabled, s.cashappEnabled),
        (false, true, true, true),
      );
      expect(s.revolutEnabled, isFalse);

      await db.setCountry('in');
      s = await db.getSettings();
      expect(s.countryCode, 'IN');
      expect((s.upiEnabled, s.paypalEnabled, s.venmoEnabled), (true, false, false));

      await db.setCountry('DE');
      s = await db.getSettings();
      expect((s.upiEnabled, s.revolutEnabled), (false, true));
    });

    test('before a country is stored, ₹ stands for India', () async {
      final c = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
      addTearDown(c.dispose);
      await db.setCurrencyCode('INR');
      await c.read(settingsProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(homeCountryProvider), 'IN');
      expect(c.read(indiaToolsProvider), isTrue);

      await db.setCurrencyCode('USD');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(homeCountryProvider), isNull);
      expect(c.read(indiaToolsProvider), isFalse);
    });

    test('a stored country wins over the currency', () async {
      final c = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
      addTearDown(c.dispose);
      await db.setCurrencyCode('INR');
      await db.setCountry('GB');
      await c.read(settingsProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(homeCountryProvider), 'GB');
      expect(c.read(indiaToolsProvider), isFalse);
      expect(c.read(voiceAddAvailableProvider), isFalse);
    });
  });

  test('the Add route carries everything heard', () {
    final route = voiceAddRoute(
      VoiceDraft(
        type: TxType.expense,
        amount: const Money(25050),
        categoryId: 3,
        note: 'Taxi',
        payee: 'Ola',
        date: DateTime(2026, 11, 22),
      ),
    );
    final uri = Uri.parse(route);
    expect(uri.path, '/add');
    expect(uri.queryParameters, {
      'type': 'expense',
      'amount': '250.5',
      'category': '3',
      'note': 'Taxi',
      'payee': 'Ola',
      'date': '2026-11-22',
    });
  });

  for (final glass in [true, false]) {
    final style = glass ? 'Glass' : 'Classic';

    Future<(AppDatabase, FakeSpeech)> pumpShell(
      WidgetTester tester, {
      String country = 'IN',
    }) async {
      final db = (await tester.runAsync(() async {
        final db = AppDatabase(NativeDatabase.memory());
        await db.setShowBottomNavLabels(false);
        await db.setCountry(country);
        return db;
      }))!;
      addTearDown(db.close);
      final speech = FakeSpeech();
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 120);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            speechEngineProvider.overrideWithValue(speech),
          ],
          child: MaterialApp.router(
            theme: glass
                ? AppTheme.of(
                    GlassBackdrop.black.palette,
                    ThemeStyle.glass.shape,
                    backdrop: GlassBackdrop.black,
                  )
                : AppTheme.light,
            routerConfig: appRouter,
          ),
        ),
      );
      appRouter.go('/dashboard');
      await settle(tester);
      return (db, speech);
    }

    Finder addButton() => glass
        ? find.byWidgetPredicate(
            (w) => w is GlassButton && w.semanticLabel == 'Add',
          )
        : find.byIcon(Icons.add_rounded);

    Future<void> doubleTap(WidgetTester tester) async {
      await tester.tap(addButton());
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(addButton());
      await settle(tester);
    }

    testWidgets('$style: double-tap ➕ listens, Continue fills in Add', (
      tester,
    ) async {
      final (db, speech) = await pumpShell(tester);
      await doubleTap(tester);
      expect(find.byType(VoiceAddBar), findsOneWidget);
      expect(find.byType(AddTransactionScreen), findsNothing);
      expect(speech.starts, 1);

      speech.say('I took a taxi for 250 rupees');
      await settle(tester);
      expect(find.text('I took a taxi for 250 rupees'), findsOneWidget);
      expect(find.textContaining('Transport'), findsOneWidget);

      await tester.tap(
        glass ? find.byTooltip('Continue') : find.text('Continue'),
      );
      await settle(tester);
      final screen = tester.widget<AddTransactionScreen>(
        find.byType(AddTransactionScreen),
      );
      expect(screen.initialType, TxType.expense);
      expect(screen.initialAmount, Money.fromRupees(250));
      expect(screen.initialNote, 'Taxi');
      final transport = (await tester.runAsync(
        () => db.watchCategories(CategoryKind.expense).first,
      ))!.firstWhere((c) => c.name == 'Transport');
      expect(screen.initialCategoryId, transport.id);
      expect(speech.stops, 1);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$style: ✕ closes voice add and the tabs come back', (
      tester,
    ) async {
      final (_, speech) = await pumpShell(tester);
      await doubleTap(tester);
      expect(find.byType(VoiceAddBar), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel'));
      await settle(tester);
      expect(find.byType(VoiceAddBar), findsNothing);
      expect(addButton(), findsOneWidget);
      expect(speech.cancels, greaterThan(0));
      await unmount(tester);
    });

    testWidgets('$style: a phone with no offline recognizer says so', (
      tester,
    ) async {
      final (_, speech) = await pumpShell(tester);
      speech.answer = SpeechStart.unsupported;
      await doubleTap(tester);
      expect(find.textContaining('Android 12'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('$style: one tap still opens Add', (tester) async {
      await pumpShell(tester);
      await tester.tap(addButton());
      await settle(tester);
      expect(find.byType(AddTransactionScreen), findsOneWidget);
      expect(find.byType(VoiceAddBar), findsNothing);
      await unmount(tester);
    });

    testWidgets('$style: outside India a double tap is just Add', (
      tester,
    ) async {
      await pumpShell(tester, country: 'US');
      await tester.tap(addButton());
      await settle(tester);
      expect(find.byType(VoiceAddBar), findsNothing);
      expect(find.byType(AddTransactionScreen), findsOneWidget);
      await unmount(tester);
    });
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}
