import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/routing/hold_menu_geometry.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

/// Glass's hold-➕ quick actions: bubbles fan out of the ➕ onto two arcs, the
/// thumb picks one by sliding onto it, and the bubble flies back into the ➕,
/// which swells into the page.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.setHoldMenuEnabled(true);
    await db.setHoldMenuSlots(const [
      'add-expense',
      'add-income',
      'transactions',
      'accounts',
      'persons',
      'budgets',
      '',
      '',
    ]);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<Offset> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.of(
            GlassBackdrop.black.palette,
            ThemeStyle.glass.shape,
            backdrop: GlassBackdrop.black,
          ),
          routerConfig: appRouter,
        ),
      ),
    );
    appRouter.go('/dashboard');
    await settle(tester);
    return tester.getCenter(find.byIcon(CupertinoIcons.add).last);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('holding ➕ fans the actions out; sliding onto one names it, '
      'and letting go opens it out of the ➕', (tester) async {
    final anchor = await pumpShell(tester);
    final gesture = await tester.startGesture(anchor);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('release on × to cancel'), findsOneWidget);

    final centres = glassFanCenters(anchor, 6);
    for (var k = 1; k <= 6; k++) {
      await gesture.moveTo(Offset.lerp(anchor, centres.first, k / 6)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Add expense'), findsOneWidget);

    await gesture.up();
    // The fan plays out, then the page grows out of the ➕: a disc of the
    // ➕'s colour, the size of the ➕, carrying the picked action's glyph.
    var revealed = false;
    for (var f = 0; f < 50 && !revealed; f++) {
      await tester.pump(const Duration(milliseconds: 16));
      revealed = find.byType(GlassRevealTransition).evaluate().isNotEmpty;
    }
    expect(revealed, isTrue, reason: 'page should open with the reveal');
    final spec = tester
        .widget<GlassRevealTransition>(find.byType(GlassRevealTransition))
        .spec;
    expect(spec.centre.dx, closeTo(anchor.dx, 1));
    expect(spec.centre.dy, closeTo(anchor.dy, 1));
    expect(spec.radius, 32);
    expect(spec.color, isNotNull);
    expect(spec.icon, isNotNull);
    final page = tester.state(find.byType(AddTransactionScreen));
    await settle(tester);
    expect(find.byType(AddTransactionScreen), findsOneWidget);
    // The same page all the way through — not rebuilt as the disc clears.
    expect(
      identical(tester.state(find.byType(AddTransactionScreen)), page),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('letting go back on the ✕ cancels and opens nothing', (
    tester,
  ) async {
    final anchor = await pumpShell(tester);
    final gesture = await tester.startGesture(anchor);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
    final centres = glassFanCenters(anchor, 6);
    await gesture.moveTo(centres[2]);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(anchor + const Offset(4, -4));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await settle(tester);

    expect(find.textContaining('release on × to cancel'), findsNothing);
    expect(find.byType(AddTransactionScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
