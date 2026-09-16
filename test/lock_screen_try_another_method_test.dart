import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/security/lock_screen.dart';

/// GitHub #127 — "when the selected options are more than one, the 'try
/// another method' button doesn't run at all". The button only ever shows
/// once 2+ unlock methods are enabled (with 1, there's nothing to switch
/// to), which is exactly why the bug only surfaced then.
///
/// Root cause: in the real app (app.dart), `LockScreen` is a `Stack` SIBLING
/// of the routed `child` MaterialApp.router's `builder` receives — not a
/// descendant of it. The real app's `Navigator` lives inside that routed
/// `child` (built by go_router), so `LockScreen`'s own `BuildContext` had no
/// `Navigator` ancestor at all. `_showMethodPicker`'s `showModalBottomSheet`
/// needs one, so tapping "Try another method" threw instead of opening the
/// sheet. Every existing LockScreen test wraps it in `MaterialApp(home: ...)`
/// instead, which supplies MaterialApp's own Navigator and never exercised
/// this — this test mimics the real composition instead, including the
/// fix: a small nested `Navigator` wrapping just `LockScreen`, same as
/// app.dart now has.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The bit of app.dart's `builder` that matters here: a `Stack` holding
  /// the routed content (itself wrapped in a real `Navigator`, standing in
  /// for go_router's) alongside `LockScreen`, as siblings — not one nested
  /// inside the other.
  Widget appLikeComposition() => MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: RouterConfig<Object>(
      routerDelegate: _SimpleRouterDelegate(),
    ),
    builder: (context, child) => Stack(
      children: [
        ?child,
        Positioned.fill(
          child: HeroControllerScope.none(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => LockScreen(onUnlocked: () {}),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: appLikeComposition(),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    '"Try another method" opens the picker sheet even though LockScreen '
    "sits outside the app's routed Navigator, same as in the real app",
    (tester) async {
      await tester.runAsync(() async {
        await db.setMasterPhrase(List.generate(12, (i) => 'word$i'));
        // Set up last, so it's the one the lock screen shows first — the
        // sheet then offers the *other* ready method, "Master password".
        await db.setPasscode('1234');
      });

      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Try another method'), findsOneWidget);

      await tester.tap(find.text('Try another method'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Master password'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}

/// Just enough of a real router to give `MaterialApp.router` a routed
/// `child` with its own `Navigator` — a single always-empty screen, since
/// what's actually under test is `LockScreen` sitting alongside it, not
/// anything about the route itself.
class _SimpleRouterDelegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: const [MaterialPage(child: SizedBox.shrink())],
    onDidRemovePage: (_) {},
  );

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}
