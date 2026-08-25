import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('defaults to transactions,persons', () async {
    expect((await db.getSettings()).bottomNavSlots, 'transactions,persons');
  });

  test('setBottomNavSlots persists a valid pair', () async {
    await db.setBottomNavSlots('calendar', 'budgets');
    expect((await db.getSettings()).bottomNavSlots, 'calendar,budgets');
  });

  test('rejects an id outside the catalog', () async {
    expect(
      () => db.setBottomNavSlots('nonsense', 'persons'),
      throwsArgumentError,
    );
  });

  test('rejects the same id in both slots', () async {
    expect(
      () => db.setBottomNavSlots('calendar', 'calendar'),
      throwsArgumentError,
    );
  });

  test('rejects a pinned id (dashboard/more are not choosable)', () async {
    expect(
      () => db.setBottomNavSlots('dashboard', 'persons'),
      throwsArgumentError,
    );
    expect(
      () => db.setBottomNavSlots('transactions', 'more'),
      throwsArgumentError,
    );
  });

  test('showBottomNavLabels defaults to true', () async {
    expect((await db.getSettings()).showBottomNavLabels, isTrue);
  });

  test('setShowBottomNavLabels persists the flag', () async {
    await db.setShowBottomNavLabels(false);
    expect((await db.getSettings()).showBottomNavLabels, isFalse);
  });
}
