import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/data_export/statement_pdf.dart';

/// Building a PDF is where a real class of bug hides — a missing font glyph,
/// a widget that throws on empty data — that a pure data-layer test can't
/// see. These render the real bytes and just check they're a real PDF.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  bool looksLikePdf(List<int> bytes) =>
      bytes.length > 500 && bytes[0] == '%'.codeUnitAt(0);

  test('account statement PDF renders with rows', () async {
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash);
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food');
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(100),
      accountId: cash.id,
      categoryId: food.id,
      date: DateTime(2026, 7, 5),
      payee: 'Test Store',
    );

    final statement = await db.accountStatement(
      accountId: cash.id,
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    final bytes = await buildAccountStatementPdf(
      account: cash,
      statement: statement,
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('account statement PDF renders with no transactions in range',
      () async {
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash);
    final statement = await db.accountStatement(
      accountId: cash.id,
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    final bytes = await buildAccountStatementPdf(
      account: cash,
      statement: statement,
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('budget statement PDF renders with rows', () async {
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash);
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food');
    await db.upsertBudget(categoryId: food.id, amount: Money.fromRupees(5000));
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(300),
      accountId: cash.id,
      categoryId: food.id,
      date: DateTime(2026, 7, 5),
    );

    final lines = await db.budgetStatement(DateTime(2026, 7, 1));
    final bytes = await buildBudgetStatementPdf(
      month: DateTime(2026, 7, 1),
      lines: lines,
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('budget statement PDF renders with no budgets set', () async {
    final lines = await db.budgetStatement(DateTime(2026, 7, 1));
    final bytes = await buildBudgetStatementPdf(
      month: DateTime(2026, 7, 1),
      lines: lines,
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('category statement PDF renders a budget, its spend and split legs',
      () async {
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash);
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food');
    final shopping = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Shopping');
    await db.upsertBudget(categoryId: food.id, amount: Money.fromRupees(5000));
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(300),
      accountId: cash.id,
      categoryId: food.id,
      date: DateTime(2026, 7, 5),
      note: 'Dinner',
    );
    final splitTxId = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1000),
      accountId: cash.id,
      date: DateTime(2026, 7, 6),
      note: 'Big Bazaar run',
    );
    await db.setTransactionSplits(splitTxId, [
      (categoryId: food.id, amount: Money.fromRupees(400)),
      (categoryId: shopping.id, amount: Money.fromRupees(600)),
    ]);

    final statement = await db.categoryStatement(
      categoryId: food.id,
      month: DateTime(2026, 7, 1),
    );
    expect(statement.spent, Money.fromRupees(700));
    expect(statement.lines, hasLength(2));
    expect(statement.lines.any((l) => l.isSplit), isTrue);

    final bytes = await buildCategoryStatementPdf(
      month: DateTime(2026, 7, 1),
      statement: statement,
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('category statement PDF renders with no budget and no transactions',
      () async {
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food');
    final statement = await db.categoryStatement(
      categoryId: food.id,
      month: DateTime(2026, 7, 1),
    );
    final bytes = await buildCategoryStatementPdf(
      month: DateTime(2026, 7, 1),
      statement: statement,
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('combined statement PDF renders rows across accounts', () async {
    final cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash);
    final bank = await db.addAccount(
      name: 'IPPB',
      type: AccountType.bank,
      colorValue: 0,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(500),
    );
    final food = (await db.watchCategories(CategoryKind.expense).first)
        .firstWhere((c) => c.name == 'Food');
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(100),
      accountId: cash.id,
      categoryId: food.id,
      date: DateTime(2026, 7, 5),
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(50),
      accountId: cash.id,
      toAccountId: bank,
      date: DateTime(2026, 7, 6),
    );

    final lines = await db.combinedStatement(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    final bytes = await buildCombinedStatementPdf(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
      lines: lines,
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('combined statement PDF renders with no transactions', () async {
    final lines = await db.combinedStatement(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
    );
    final bytes = await buildCombinedStatementPdf(
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 31),
      lines: lines,
    );
    expect(looksLikePdf(bytes), isTrue);
  });
}
