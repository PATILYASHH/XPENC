import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/payments/ussd_pay_screen.dart';
import 'package:xpenc/features/persons/persons_screen.dart';

/// "Pay without internet" (*99#, Beta) — defaults off, gates the Persons
/// FAB, and hands off to `/add` with a plain expense prefilled rather than
/// ever touching a Person/PersonEntry.
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

  group('ussdPayEnabled setting', () {
    test('defaults false — unlike the established payment methods', () async {
      final settings = await db.watchSettings().first;
      expect(settings.ussdPayEnabled, isFalse);
    });

    test('setUssdPayEnabled persists', () async {
      await db.setUssdPayEnabled(true);
      expect((await db.watchSettings().first).ussdPayEnabled, isTrue);
    });
  });

  group('Persons screen FAB', () {
    testWidgets('hidden on the Individual tab while the beta is off', (
      tester,
    ) async {
      await pump(tester, const PersonsScreen());
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
      await unmount(tester);
    });

    testWidgets('shown on the Individual tab once the beta is on', (
      tester,
    ) async {
      await tester.runAsync(() => db.setUssdPayEnabled(true));
      await pump(tester, const PersonsScreen());
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      await unmount(tester);
    });
  });

  group('UssdPayScreen', () {
    testWidgets(
      'logging with no ID entered warns instead of proceeding',
      (tester) async {
        await pump(tester, const UssdPayScreen());
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Log payment'));
        await tester.pump();

        expect(find.text('Enter who you paid first.'), findsOneWidget);
        await unmount(tester);
      },
    );

    testWidgets('Copy ID puts the typed UPI ID on the clipboard', (
      tester,
    ) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pump(tester, const UssdPayScreen());
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField).first, 'shop@okaxis');
      await tester.tap(find.text('Copy ID'));
      await tester.pump();

      expect(clipboardText, 'shop@okaxis');
      expect(find.text('Copied'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
      'Dial *99# copies the ID first, same as a separate Copy ID tap would',
      (tester) async {
        String? clipboardText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await pump(tester, const UssdPayScreen());
        expect(tester.takeException(), isNull);

        await tester.enterText(find.byType(TextField).first, 'shop@okaxis');
        await tester.ensureVisible(find.text('Dial *99#'));
        await tester.tap(find.text('Dial *99#'));
        await tester.pump();

        expect(clipboardText, 'shop@okaxis');
        await unmount(tester);
      },
    );

    testWidgets(
      'Dialing with no ID entered warns instead of copying or dialing',
      (tester) async {
        String? clipboardText;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await pump(tester, const UssdPayScreen());
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Dial *99#'));
        await tester.tap(find.text('Dial *99#'));
        await tester.pump();

        expect(find.text('Enter who you paid first.'), findsOneWidget);
        expect(clipboardText, isNull);
        await unmount(tester);
      },
    );

    testWidgets(
      'logging the payment hands off a plain expense — payee, note and '
      'amount carried over, nothing routed through a Person',
      (tester) async {
        Map<String, String>? capturedQuery;
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const UssdPayScreen()),
            GoRoute(
              path: '/add',
              builder: (_, state) {
                capturedQuery = state.uri.queryParameters;
                return const SizedBox.shrink();
              },
            ),
          ],
        );

        tester.view.physicalSize = const Size(1080, 2400);
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
        await tester.pump();

        await tester.enterText(find.byType(TextField).first, 'shop@okaxis');
        await tester.enterText(find.byType(TextField).last, '250');
        await tester.tap(find.text('Log payment'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(capturedQuery, isNotNull);
        expect(capturedQuery!['type'], 'expense');
        expect(capturedQuery!['payee'], 'shop@okaxis');
        expect(capturedQuery!['amount'], '250.00');
        expect(capturedQuery!['note'], 'Paid via *99# (offline UPI)');
      },
    );
  });
}
