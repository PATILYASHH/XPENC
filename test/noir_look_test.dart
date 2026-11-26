import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_colors.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_shape.dart';
import 'package:xpenc/core/widgets/app_surfaces.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';

/// Noir's own look: bold type, cards without divider lines, square-cornered
/// icons, and hold-to-edit drawn in its own colours. Classic is the control.
void main() {
  final noir = AppTheme.of(AppPalettes.noirLight, ThemeShape.noir);
  final classic = AppTheme.light;

  test('Noir type is two weights heavier than Classic', () {
    int rung(TextStyle? s) => FontWeight.values.indexOf(s!.fontWeight!);
    for (final role in [
      (TextTheme t) => t.bodyMedium,
      (TextTheme t) => t.titleMedium,
      (TextTheme t) => t.labelLarge,
    ]) {
      expect(rung(role(noir.textTheme)), rung(role(classic.textTheme)) + 2);
    }
    expect(noir.textTheme.bodyMedium!.fontWeight, FontWeight.w600);
  });

  Future<T> inTheme<T>(
    WidgetTester tester,
    ThemeData theme,
    Widget child,
    T Function(BuildContext context) read,
  ) async {
    late T value;
    // A fresh app each time: one app switching themes would animate between
    // them, and read the old one on the first frame.
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: theme,
        home: Material(
          child: Builder(
            builder: (context) {
              value = read(context);
              return child;
            },
          ),
        ),
      ),
    );
    return value;
  }

  testWidgets('Noir draws no divider lines; Classic does', (tester) async {
    Future<Color> dividerColor(ThemeData theme) => inTheme(
      tester,
      theme,
      const Divider(),
      (context) => Divider.createBorderSide(context).color,
    );
    expect(await dividerColor(noir), Colors.transparent);
    expect((await dividerColor(classic)).a, greaterThan(0));
  });

  testWidgets('Noir squares off rounded icons; outlined ones stay', (
    tester,
  ) async {
    Future<IconData?> shown(ThemeData theme, IconData icon) async {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: theme,
          home: Center(child: AppIcon(icon)),
        ),
      );
      return tester.widget<Icon>(find.byType(Icon)).icon;
    }

    // Icons the app uses (the table covers those).
    expect(await shown(noir, Icons.pie_chart_rounded), Icons.pie_chart_sharp);
    expect(await shown(noir, Icons.add), Icons.add_sharp);
    expect(
      await shown(noir, Icons.receipt_long_outlined),
      Icons.receipt_long_outlined,
    );
    expect(
      await shown(classic, Icons.pie_chart_rounded),
      Icons.pie_chart_rounded,
    );
  });

  group('hold to edit the bar', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    for (final (name, theme, dashboardIcon) in [
      ('Classic', classic, Icons.pie_chart_rounded),
      ('Noir', noir, Icons.pie_chart_sharp),
    ]) {
      testWidgets('$name: the editor is drawn in the theme\'s colours', (
        tester,
      ) async {
        final db = (await tester.runAsync(() async {
          final db = AppDatabase(NativeDatabase.memory());
          await db.setShowBottomNavLabels(false);
          return db;
        }))!;
        addTearDown(db.close);
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [dbProvider.overrideWithValue(db)],
            child: MaterialApp.router(theme: theme, routerConfig: appRouter),
          ),
        );
        appRouter.go('/dashboard');
        await settle(tester);

        final g = await tester.startGesture(
          tester.getCenter(find.byIcon(dashboardIcon).last),
        );
        await tester.pump(const Duration(milliseconds: 1100));
        await g.up();
        await settle(tester);

        final title = tester.widget<Text>(find.text('Edit bottom bar'));
        expect(title.style!.color, theme.colorScheme.onSurface);
        // The page washes over in its own background, not a black dim.
        final scrims = tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .where(
              (b) =>
                  b.color.a > 0.9 &&
                  b.color.withValues(alpha: 1) ==
                      theme.scaffoldBackgroundColor.withValues(alpha: 1),
            );
        expect(scrims, isNotEmpty);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('navEditorDone')));
        await settle(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      });
    }

    for (final (name, theme, floats) in [
      ('Noir', noir, true),
      ('Classic', classic, false),
    ]) {
      testWidgets('$name: the phone bar '
          '${floats ? 'floats off the foot' : 'runs edge to edge'}', (
        tester,
      ) async {
        final db = (await tester.runAsync(() async {
          final db = AppDatabase(NativeDatabase.memory());
          await db.setShowBottomNavLabels(false);
          return db;
        }))!;
        addTearDown(db.close);
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [dbProvider.overrideWithValue(db)],
            child: MaterialApp.router(theme: theme, routerConfig: appRouter),
          ),
        );
        appRouter.go('/dashboard');
        await settle(tester);

        final bar = find.byKey(const ValueKey('floatingBar'));
        if (!floats) {
          expect(bar, findsNothing);
        } else {
          final rect = tester.getRect(bar);
          expect(rect.left, 12);
          expect(rect.right, 360 - 12);
          expect(780 - rect.bottom, 10);
          // The page runs on under it.
          final scaffold = tester.widget<Scaffold>(
            find.ancestor(of: bar, matching: find.byType(Scaffold)).first,
          );
          expect(scaffold.extendBody, isTrue);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });
}
