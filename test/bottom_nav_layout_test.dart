import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/routing/bottom_nav_layout.dart';
import 'package:xpenc/data/database.dart';

/// The bottom bar's four tab slots: any module in any slot, each once, and
/// More always on the bar.
void main() {
  group('resolveBottomNavLayout', () {
    test('the old two-slot form keeps Dashboard and More at the ends', () {
      expect(resolveBottomNavLayout('calendar,stats'), [
        'dashboard',
        'calendar',
        'stats',
        'more',
      ]);
    });

    test('a four-slot layout reads back as stored', () {
      expect(resolveBottomNavLayout('stats,more,dashboard,payees'), [
        'stats',
        'more',
        'dashboard',
        'payees',
      ]);
    });

    test('anything broken falls back to the default', () {
      for (final raw in [
        null,
        '',
        'nonsense',
        'stats,payees,calendar,persons', // no More
        'more,more,stats,payees', // twice
        'dashboard,more', // legacy form naming a pinned one
      ]) {
        expect(resolveBottomNavLayout(raw), defaultBottomNavLayout, reason: raw);
      }
    });

    test('Basic mode stands in for budgets and accounts', () {
      expect(
        resolveBottomNavLayout('budgets,dashboard,accounts,more', basic: true),
        ['transactions', 'dashboard', 'persons', 'more'],
      );
    });
  });

  group('pickBottomNavModule', () {
    const layout = ['dashboard', 'transactions', 'persons', 'more'];

    test('a module not on the bar just takes the slot', () {
      expect(pickBottomNavModule(layout, 1, 'stats'), [
        'dashboard',
        'stats',
        'persons',
        'more',
      ]);
    });

    test('a module already on the bar swaps with it', () {
      expect(pickBottomNavModule(layout, 0, 'more'), [
        'more',
        'transactions',
        'persons',
        'dashboard',
      ]);
    });

    test('More can\'t be replaced by something off the bar', () {
      expect(pickBottomNavModule(layout, 3, 'payees'), isNull);
    });
  });

  group('setBottomNavLayout', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('stores all four slots', () async {
      await db.setBottomNavLayout(['stats', 'dashboard', 'more', 'payees']);
      expect(
        (await db.getSettings()).bottomNavSlots,
        'stats,dashboard,more,payees',
      );
    });

    test('refuses a layout without More', () {
      expect(
        () => db.setBottomNavLayout(['stats', 'dashboard', 'calendar', 'payees']),
        throwsArgumentError,
      );
    });
  });
}
