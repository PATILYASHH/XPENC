import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_colors.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_shape.dart';
import 'package:xpenc/core/widgets/motion.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';

/// Classic is the working look: no tab title in the top bar's corner, and
/// motion that confirms rather than performs (see `AppMotion`). Noir keeps
/// both, so it's the control here.
void main() {
  final noir = AppTheme.of(AppPalettes.noirLight, ThemeShape.noir);

  test('Classic is brisk, Noir smooth, Glass fluid', () {
    MotionStyle motionOf(ThemeData theme) =>
        theme.extension<ThemeShapeScope>()!.shape.motion;
    expect(motionOf(AppTheme.light), MotionStyle.brisk);
    expect(motionOf(AppTheme.dark), MotionStyle.brisk);
    expect(motionOf(noir), MotionStyle.smooth);
    expect(
      motionOf(AppTheme.of(AppPalettes.glass, ThemeShape.glass)),
      MotionStyle.fluid,
    );
  });

  group('top bar titles', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      // Labels off, so a tab's name can only come from the top bar.
      await db.setShowBottomNavLabels(false);
    });
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    Finder inTopBar(String text) =>
        find.descendant(of: find.byType(AppBar), matching: find.text(text));

    for (final (name, titled) in [('Classic', false), ('Noir', true)]) {
      testWidgets('$name: tab titles '
          '${titled ? 'show' : 'are hidden'} in the top bar', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [dbProvider.overrideWithValue(db)],
            child: MaterialApp.router(
              theme: titled ? noir : AppTheme.light,
              routerConfig: appRouter,
            ),
          ),
        );
        for (final (location, title) in [
          ('/dashboard', 'Dashboard'),
          ('/transactions', 'Transactions'),
          ('/more', 'More'),
        ]) {
          appRouter.go(location);
          await settle(tester);
          expect(
            inTopBar(title),
            titled ? findsOneWidget : findsNothing,
            reason: '$name on $location',
          );
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });

  group('Reveal', () {
    Future<double> opacityAfter(
      WidgetTester tester,
      ThemeData theme,
      Duration elapsed,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Reveal(index: 5, child: Text('row')),
        ),
      );
      await tester.pump(elapsed);
      return tester
          .widget<Opacity>(
            find.ancestor(of: find.text('row'), matching: find.byType(Opacity)),
          )
          .opacity;
    }

    testWidgets('Classic: no stagger, in within 160 ms', (tester) async {
      expect(
        await opacityAfter(
          tester,
          AppTheme.light,
          const Duration(milliseconds: 170),
        ),
        1,
      );
    });

    testWidgets('Noir: the sixth row still waits its turn', (tester) async {
      expect(
        await opacityAfter(tester, noir, const Duration(milliseconds: 170)),
        0,
      );
    });
  });
}
