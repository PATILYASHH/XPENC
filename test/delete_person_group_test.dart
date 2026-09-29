import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Deleting a person or group is "as if it never existed": every entry and
/// group expense goes with it, and any money those moved through an account
/// is reversed — nothing is left dangling on a foreign key.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<int> catId(CategoryKind k, String n) async =>
      (await db.watchCategories(k).first).firstWhere((c) => c.name == n).id;
  Future<Money> balance(int id) async => (await db.watchAccounts().first)
      .firstWhere((a) => a.id == id)
      .currentBalance;

  Future<void> seedCash(Money amount) async {
    await db.addTransaction(
      type: TxType.income,
      amount: amount,
      accountId: await cashId(),
      categoryId: await catId(CategoryKind.income, 'Salary'),
      date: DateTime(2026, 7, 1),
    );
  }

  test('deletePerson removes their history and reverses the money', () async {
    final cash = await cashId();
    await seedCash(Money.fromRupees(5000));
    final ram = await db.addPerson('Ram');
    await db.addPersonEntry(
      personId: ram,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(1000),
      date: DateTime(2026, 7, 2),
      accountId: cash,
    );
    expect(await balance(cash), Money.fromRupees(4000));
    final reminderId = await db.addReminder(
      title: 'Collect from Ram',
      direction: ReminderDirection.receive,
      dueDate: DateTime(2026, 7, 10),
      personId: ram,
    );

    await db.deletePerson(ram);

    expect(await db.watchPersons().first, isEmpty);
    expect(await db.countEntriesForPerson(ram), 0);
    expect(await balance(cash), Money.fromRupees(5000));
    final reminder = await (db.select(
      db.reminders,
    )..where((r) => r.id.equals(reminderId))).getSingle();
    expect(reminder.personId, isNull);
  });

  test('deletePerson drops them from groups, including expenses they paid '
      'and their share of mine', () async {
    final cash = await cashId();
    await seedCash(Money.fromRupees(5000));
    final food = await catId(CategoryKind.expense, 'Food');
    final ram = await db.addPerson('Ram');
    final shyam = await db.addPerson('Shyam');
    final groupId = await db.addGroup('Trip');
    await db.setGroupMembers(groupId, {ram, shyam});

    // I paid 900 split three ways; Ram paid 600 split with me.
    await db.addGroupExpense(
      groupId: groupId,
      amount: Money.fromRupees(900),
      splitMethod: GroupSplitMethod.equal,
      date: DateTime(2026, 7, 5),
      accountId: cash,
      categoryId: food,
      participantIds: {null, ram, shyam},
    );
    await db.addGroupExpense(
      groupId: groupId,
      amount: Money.fromRupees(600),
      splitMethod: GroupSplitMethod.equal,
      date: DateTime(2026, 7, 6),
      payerId: ram,
      participantIds: {null, ram},
    );

    await db.deletePerson(ram);

    expect((await db.watchPersons().first).map((p) => p.name), ['Shyam']);
    expect(
      (await db.watchGroupMembers(groupId).first).map((p) => p.id),
      [shyam],
    );
    // Ram's own expense is gone; mine stays, Shyam still owes his share.
    // The 300 I fronted for Ram's share was a lend out of cash — like any
    // deleted lend entry, it's reversed: 5000 − 900 + 300.
    expect(await db.watchGroupExpenses(groupId).first, hasLength(1));
    expect(await db.countEntriesForPerson(shyam), 1);
    expect(await balance(cash), Money.fromRupees(4400));
  });

  test('deleteGroup reverses every expense but keeps the members', () async {
    final cash = await cashId();
    await seedCash(Money.fromRupees(5000));
    final food = await catId(CategoryKind.expense, 'Food');
    final ram = await db.addPerson('Ram');
    final groupId = await db.addGroup('Trip');
    await db.setGroupMembers(groupId, {ram});
    await db.addGroupExpense(
      groupId: groupId,
      amount: Money.fromRupees(800),
      splitMethod: GroupSplitMethod.equal,
      date: DateTime(2026, 7, 5),
      accountId: cash,
      categoryId: food,
      participantIds: {null, ram},
    );
    expect(await balance(cash), Money.fromRupees(4200));

    await db.deleteGroup(groupId);

    expect(await db.watchGroups().first, isEmpty);
    expect(await db.countExpensesForGroup(groupId), 0);
    expect(await db.countEntriesForPerson(ram), 0);
    expect((await db.watchPersons().first).map((p) => p.name), ['Ram']);
    expect(await balance(cash), Money.fromRupees(5000));
  });

  test('an unused person or group still deletes cleanly', () async {
    final ram = await db.addPerson('Ram');
    final groupId = await db.addGroup('Empty');
    await db.deleteGroup(groupId);
    await db.deletePerson(ram);
    expect(await db.watchPersons().first, isEmpty);
    expect(await db.watchGroups().first, isEmpty);
  });
}
