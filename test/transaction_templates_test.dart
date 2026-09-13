import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// GitHub #125: "create template from this transaction", then pick it again
/// from the ➕ button. These cover the database layer only — the UI wiring
/// (choice sheet, AddTransactionScreen prefill) is covered by
/// `add_transaction_template_test.dart`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<int> addBank() => db.addAccount(
    name: 'Bank',
    type: AccountType.bank,
    colorValue: 0xFF0000FF,
    iconKey: 'bank',
    openingBalance: const Money.zero(),
  );

  Future<int> expenseCategory(String name) async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == name)
          .id;

  test('copies type, amount, account, category, note, payee and tags', () async {
    final cash = await cashId();
    final foodId = await expenseCategory('Food');
    final tagId = await db.addTag(name: 'Work', colorValue: 0xFF00FF00);

    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(499),
      accountId: cash,
      categoryId: foodId,
      note: 'Team lunch',
      payee: 'Cafe',
      date: DateTime(2026, 9, 1),
    );
    await db.setTransactionTags(txId, {tagId});

    final templateId = await db.createTemplateFromTransaction(
      transactionId: txId,
      name: 'Team lunch template',
    );

    final template = await db.transactionTemplateById(templateId);
    expect(template, isNotNull);
    expect(template!.name, 'Team lunch template');
    expect(template.type, TxType.expense);
    expect(template.amount, Money.fromRupees(499));
    expect(template.accountId, cash);
    expect(template.categoryId, foodId);
    expect(template.note, 'Team lunch');
    expect(template.payee, 'Cafe');

    expect(await db.tagIdsForTemplate(templateId), [tagId]);
  });

  test('a transfer keeps both accounts, no category', () async {
    final cash = await cashId();
    final bank = await addBank();

    final txId = await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(1000),
      accountId: cash,
      toAccountId: bank,
      date: DateTime(2026, 9, 1),
    );

    final templateId = await db.createTemplateFromTransaction(
      transactionId: txId,
      name: 'Move to bank',
    );
    final template = await db.transactionTemplateById(templateId);
    expect(template!.accountId, cash);
    expect(template.toAccountId, bank);
    expect(template.categoryId, isNull);
  });

  test('refuses a person-linked transaction', () async {
    final cash = await cashId();
    final ram = await db.addPerson('Ram');
    await db.addPersonEntry(
      personId: ram,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 9, 1),
      accountId: cash,
    );
    final linkedTx = (await db.watchTransactions(limit: 1).first).first;
    expect(linkedTx.type, TxType.personOut);

    expect(
      () => db.createTemplateFromTransaction(
        transactionId: linkedTx.id,
        name: 'Should fail',
      ),
      throwsArgumentError,
    );
  });

  test('refuses a split transaction', () async {
    final cash = await cashId();
    final foodId = await expenseCategory('Food');
    final transportId = await expenseCategory('Transport');

    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(300),
      accountId: cash,
      categoryId: foodId,
      date: DateTime(2026, 9, 1),
    );
    await db.setTransactionSplits(txId, [
      (categoryId: foodId, amount: Money.fromRupees(200)),
      (categoryId: transportId, amount: Money.fromRupees(100)),
    ]);

    expect(
      () => db.createTemplateFromTransaction(
        transactionId: txId,
        name: 'Should fail',
      ),
      throwsArgumentError,
    );
  });

  test('deleteTransactionTemplate removes the template and its tag links', () async {
    final cash = await cashId();
    final foodId = await expenseCategory('Food');
    final tagId = await db.addTag(name: 'Work', colorValue: 0xFF00FF00);
    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(50),
      accountId: cash,
      categoryId: foodId,
      date: DateTime(2026, 9, 1),
    );
    await db.setTransactionTags(txId, {tagId});
    final templateId = await db.createTemplateFromTransaction(
      transactionId: txId,
      name: 'Coffee',
    );

    await db.deleteTransactionTemplate(templateId);

    expect(await db.transactionTemplateById(templateId), isNull);
    expect(await db.tagIdsForTemplate(templateId), isEmpty);
  });

  test('deleteTag also drops it from any template that used it', () async {
    final cash = await cashId();
    final foodId = await expenseCategory('Food');
    final tagId = await db.addTag(name: 'Work', colorValue: 0xFF00FF00);
    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(50),
      accountId: cash,
      categoryId: foodId,
      date: DateTime(2026, 9, 1),
    );
    await db.setTransactionTags(txId, {tagId});
    final templateId = await db.createTemplateFromTransaction(
      transactionId: txId,
      name: 'Coffee',
    );

    await db.deleteTag(tagId);

    expect(await db.tagIdsForTemplate(templateId), isEmpty);
  });

  test('deleteAccount refuses while a template still points at it', () async {
    final foodId = await expenseCategory('Food');
    final newAccountId = await db.addAccount(
      name: 'Wallet',
      type: AccountType.cash,
      colorValue: 0xFF00FF00,
      iconKey: 'wallet',
      openingBalance: const Money.zero(),
    );
    final txId = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(50),
      accountId: newAccountId,
      categoryId: foodId,
      date: DateTime(2026, 9, 1),
    );
    await db.createTemplateFromTransaction(
      transactionId: txId,
      name: 'Uses wallet',
    );
    // The source transaction itself would already block deletion (an
    // account with any transaction history must be archived, not deleted)
    // — remove it so only the template's own reference is left to test.
    await db.deleteTransaction(txId);

    expect(() => db.deleteAccount(newAccountId), throwsArgumentError);
  });
}
