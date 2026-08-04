import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';

/// Before v17, every shopping item sat on one flat, unnamed list —
/// `listId` didn't exist. `backfillShoppingListIds()` repairs an item left
/// without one, whether that's from the v16→v17 migration itself or from
/// restoring a backup taken before this update (its export has no `listId`
/// to import — see `AppDatabase.importAll`).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Exactly the shape a pre-v17 item (or import) leaves: a row with no
  /// `listId` at all.
  Future<int> insertOrphanedItem(String name) => db
      .into(db.shoppingItems)
      .insert(ShoppingItemsCompanion.insert(name: name));

  test('moves orphaned items onto one newly-created default list', () async {
    await insertOrphanedItem('Milk');
    await insertOrphanedItem('Bread');

    final repaired = await db.backfillShoppingListIds();
    expect(repaired, 2);

    final lists = await db.watchShoppingLists().first;
    expect(lists, hasLength(1));
    expect(lists.single.name, 'Shopping List');

    final items = await db.watchShoppingItems(lists.single.id).first;
    expect(items.map((i) => i.name), containsAll(['Milk', 'Bread']));
    expect(items.every((i) => i.listId == lists.single.id), isTrue);
  });

  test('repair is idempotent — running it twice changes nothing', () async {
    await insertOrphanedItem('Milk');

    expect(await db.backfillShoppingListIds(), 1);
    expect(await db.backfillShoppingListIds(), 0);
    expect(await db.watchShoppingLists().first, hasLength(1));
  });

  test('an item that already has a list is left alone', () async {
    final listId = await db.addShoppingList(
      name: 'Diwali',
      colorValue: 0xFF2563EB,
    );
    await db.addShoppingItem(
      listId: listId,
      name: 'Sweets',
      estimatedAmount: Money.fromRupees(300),
    );

    expect(await db.backfillShoppingListIds(), 0);
    expect(await db.watchShoppingLists().first, hasLength(1));
    final items = await db.watchShoppingItems(listId).first;
    expect(items, hasLength(1));
    expect(items.single.listId, listId);
  });

  test('deleting a list deletes everything on it', () async {
    final listId = await db.addShoppingList(
      name: 'Groceries',
      colorValue: 0xFF16A34A,
    );
    await db.addShoppingItem(listId: listId, name: 'Milk');
    await db.addShoppingItem(listId: listId, name: 'Eggs');

    await db.deleteShoppingList(listId);

    expect(await db.watchShoppingLists().first, isEmpty);
    expect(await db.watchAllShoppingItems().first, isEmpty);
  });
}
