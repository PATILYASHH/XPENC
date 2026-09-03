import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Restore replaces the whole ledger. If it is wrong, everything is lost.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> catId(CategoryKind k, String name) async =>
      (await db.watchCategories(k).first).firstWhere((c) => c.name == name).id;

  /// Build a realistic ledger: bank, debit card, credit card, transfers,
  /// a person, a budget and a reminder.
  Future<void> seedRealisticData() async {
    final cash = await cashId();
    final bank = await db.addAccount(
      name: 'IPPB',
      type: AccountType.bank,
      bankName: 'India Post Payments Bank',
      last4: '1234',
      colorValue: 0xFF2563EB,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(20000),
    );
    await db.addAccount(
      name: 'IPPB Debit',
      type: AccountType.card,
      cardKind: CardKind.debit,
      linkedAccountId: bank,
      colorValue: 0xFF2563EB,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    final card = await db.addAccount(
      name: 'Yes Bank Credit Card',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0xFFDC2626,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );

    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(50000),
      accountId: bank,
      categoryId: await catId(CategoryKind.income, 'Salary'),
      date: DateTime(2026, 7, 1),
    );
    await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1234.56),
      accountId: card,
      categoryId: await catId(CategoryKind.expense, 'Shopping'),
      date: DateTime(2026, 7, 3),
      note: 'has, a comma "and quotes"',
    );
    await db.addTransaction(
      type: TxType.transfer,
      amount: Money.fromRupees(5000),
      accountId: bank,
      toAccountId: cash,
      date: DateTime(2026, 7, 4),
    );

    final ram = await db.addPerson('Ram');
    await db.addPersonEntry(
      personId: ram,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 7, 5),
      accountId: cash,
    );

    await db.upsertBudget(
      categoryId: await catId(CategoryKind.expense, 'Food'),
      amount: Money.fromRupees(6000),
    );
    await db.addReminder(
      title: 'EMI',
      amount: Money.fromRupees(5000),
      direction: ReminderDirection.pay,
      dueDate: DateTime(2026, 8, 5),
    );
    await db.addRecurringRule(
      name: 'Netflix',
      kind: CategoryKind.expense,
      amount: Money.fromRupees(649),
      accountId: card,
      categoryId: await catId(CategoryKind.expense, 'Entertainment'),
      frequency: RecurringFrequency.monthly,
      startsOn: DateTime(2026, 7, 10),
    );
  }

  group('export', () {
    test('captures every table and keeps money as integer paise', () async {
      await seedRealisticData();
      final dump = await db.exportAll();

      expect(dump['formatVersion'], AppDatabase.backupFormatVersion);
      expect(dump['accounts'], hasLength(4));
      // 3 manual transactions + the personOut row created by lending Ram 500.
      expect(dump['transactions'], hasLength(4));
      expect(dump['persons'], hasLength(1));
      expect(dump['personEntries'], hasLength(1));
      expect(dump['budgets'], hasLength(1));
      expect(dump['reminders'], hasLength(1));
      expect(dump['recurringRules'], hasLength(1));

      final tx = (dump['transactions'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((t) => t['type'] == 'expense');
      expect(tx['amount'], 123456, reason: 'paise, never a float');
    });

    test('survives a JSON round-trip', () async {
      await seedRealisticData();
      final dump = await db.exportAll();
      final decoded =
          jsonDecode(jsonEncode(dump)) as Map<String, dynamic>;
      expect(decoded['transactions'], hasLength(4));
    });
  });

  group('import', () {
    test('restores the exact ledger, balances and all', () async {
      await seedRealisticData();

      final netBefore = await db.watchNetWorth().first;
      final txBefore = await db.watchTransactions().first;
      final personBefore = await db.watchAllPersonBalances().first;
      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      // Wipe by importing into a completely fresh database.
      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      await fresh.importAll(dump);

      expect(await fresh.watchNetWorth().first, netBefore);
      expect(await fresh.watchTransactions().first, hasLength(txBefore.length));
      expect(await fresh.watchAllPersonBalances().first, personBefore);

      final accs = await fresh.watchAccounts().first;
      expect(accs, hasLength(4));

      // The debit card must still be an instrument holding nothing.
      final debit = accs.firstWhere((a) => a.name == 'IPPB Debit');
      expect(debit.linkedAccountId, isNotNull);
      expect(debit.currentBalance, const Money.zero());

      // The credit card must still be a liability.
      final card = accs.firstWhere((a) => a.name == 'Yes Bank Credit Card');
      expect(card.currentBalance, Money.fromRupees(-1234.56));

      final rules = await fresh.watchRecurringRules().first;
      expect(rules, hasLength(1));
      expect(rules.single.name, 'Netflix');
      expect(rules.single.amount, Money.fromRupees(649));

      final reminders = await fresh.watchReminders().first;
      expect(reminders, hasLength(1));
      expect(reminders.single.title, 'EMI');
    });

    test('restoring twice is idempotent (no duplicated rows)', () async {
      await seedRealisticData();
      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      await db.importAll(dump);
      final once = await db.watchTransactions().first;
      await db.importAll(dump);
      final twice = await db.watchTransactions().first;

      expect(twice.length, once.length, reason: 'import must replace, not append');
      expect(await db.watchNetWorth().first, Money.fromRupees(68265.44));
    });

    test('rejects a file that is not a backup, leaving data intact', () async {
      await seedRealisticData();
      final before = await db.watchNetWorth().first;

      await expectLater(
        db.importAll({'hello': 'world'}),
        throwsArgumentError,
      );
      expect(await db.watchNetWorth().first, before,
          reason: 'a bad file must never destroy the ledger');
    });

    test('rejects a backup from a newer app version', () async {
      await expectLater(
        db.importAll({
          'formatVersion': AppDatabase.backupFormatVersion + 1,
          'accounts': <dynamic>[],
          'transactions': <dynamic>[],
        }),
        throwsArgumentError,
      );
    });

    test('a malformed row rolls the whole restore back', () async {
      await seedRealisticData();
      final before = await db.watchTransactions().first;

      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
      // Point a transaction at an account that does not exist.
      (dump['transactions'] as List)[0]['account_id'] = 999999;

      await expectLater(db.importAll(dump), throwsA(isA<Exception>()));

      // The original ledger must survive untouched.
      expect(await db.watchTransactions().first, hasLength(before.length));
      expect(await db.watchNetWorth().first, Money.fromRupees(68265.44));
    });
  });

  // §5 of the 1.4.0 spec: every module, not just the core ledger, must
  // round-trip. Each assertion below is one line of that audit checklist.
  group('full-app round trip (§5 backup audit)', () {
    test('every module survives export -> wipe -> import', () async {
      await seedRealisticData();
      final bank = (await db.watchAccounts().first)
          .firstWhere((a) => a.name == 'IPPB')
          .id;

      // Tags, and their usage on a transaction.
      final tagId = await db.addTag(name: 'Work', colorValue: 0xFF00FF00);
      final expenseTx = (await db.watchTransactions().first)
          .firstWhere((t) => t.type == TxType.expense);
      await db.setTransactionTags(expenseTx.id, {tagId});

      // A preset tag on a recurring rule (#63) — its own join table
      // (`recurringRuleTags`), separate from the transaction-tag one above.
      await db.addRecurringRule(
        name: 'Spotify',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(199),
        accountId: bank,
        categoryId: await catId(CategoryKind.expense, 'Entertainment'),
        frequency: RecurringFrequency.monthly,
        startsOn: DateTime(2026, 7, 15),
        tagIds: {tagId},
      );

      // A tag group bundling that same tag (#92) — its own join table
      // (`tagGroupTags`), separate from both tag joins above.
      final tagGroupId = await db.addTagGroup(
        name: 'Work trip',
        colorValue: 0xFF0000FF,
      );
      await db.setTagGroupTags(tagGroupId, {tagId});

      // A manual link between two transactions (#64).
      final incomeTx = (await db.watchTransactions().first)
          .firstWhere((t) => t.type == TxType.income);
      await db.addTransactionLink(expenseTx.id, incomeTx.id);

      // Receipt path + payee on that same transaction.
      await db.updateTransaction(
        id: expenseTx.id,
        type: expenseTx.type,
        amount: expenseTx.amount,
        accountId: expenseTx.accountId,
        date: expenseTx.date,
        note: expenseTx.note,
        payee: 'Big Bazaar',
        imagePath: '/data/user/0/com.yash.xpenc/app_flutter/receipts/r1.jpg',
      );

      // Shopping lists — more than the default one, each with its own items.
      final list1 = await db.addShoppingList(
        name: 'Weekly groceries',
        colorValue: 0xFFAA0000,
      );
      final list2 = await db.addShoppingList(
        name: 'Diwali',
        colorValue: 0xFF0000AA,
      );
      await db.addShoppingItem(
        listId: list1,
        name: 'Milk',
        estimatedAmount: Money.fromRupees(60),
      );
      await db.addShoppingItem(listId: list2, name: 'Diyas');

      // A savings goal (a real account) plus its contribution history (an
      // ordinary transfer into it).
      final goalId = await db.addGoal(
        name: 'Trip to Goa',
        targetAmount: Money.fromRupees(20000),
        colorValue: 0xFF123456,
        iconKey: 'flight',
      );
      await db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(2000),
        accountId: bank,
        toAccountId: goalId,
        date: DateTime(2026, 7, 6),
      );

      // Credit card statement/due-date tracking (GitHub #91).
      // `seedRealisticData` above already added a "Yes Bank Credit Card",
      // so this one gets its own distinct name — otherwise the two
      // same-named accounts make `firstWhere` below ambiguous about which
      // one actually has statement details attached.
      final creditCard = await db.addAccount(
        name: 'HDFC Credit Card',
        type: AccountType.card,
        cardKind: CardKind.credit,
        colorValue: 0xFF442200,
        iconKey: 'card',
        openingBalance: const Money.zero(),
      );
      await db.upsertCreditCardDetails(
        accountId: creditCard,
        statementDay: 5,
        dueDay: 25,
        notifyDaysBefore: 2,
      );

      // Archived account and archived person must survive, not just active
      // ones.
      final archivedAccId = await db.addAccount(
        name: 'Old Wallet',
        type: AccountType.cash,
        colorValue: 0xFF888888,
        iconKey: 'wallet',
        openingBalance: const Money.zero(),
      );
      await db.archiveAccount(archivedAccId);
      final archivedPersonId = await db.addPerson('Retired Debtor');
      await db.archivePerson(archivedPersonId);

      // App settings, pushed away from every default so a restore that
      // silently keeps local values (instead of the imported ones) shows up.
      await db.setCurrencyCode('USD');
      await db.setShowCurrencySymbol(false);
      await db.setNotificationsEnabled(false);
      await db.setCountRepaymentsAsIncome(true);
      await db.setPreventScreenshots(true);
      await db.setAutoBackupSettings(
        enabled: true,
        frequency: AutoBackupFrequency.monthly,
        retentionDays: 60,
      );
      // Theme and passcode are the deliberate exception: a backup must not
      // repaint or (re-)lock a device it's restored onto, so these are
      // captured here only to prove the *other* settings above are not
      // caught by that same local-wins rule.
      await db.setThemeName('amoled');
      await db.setPasscode('1357');

      final dump =
          jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      // Restore onto a database with its own different local state, to
      // prove the restore actually overwrites rather than coincidentally
      // matching.
      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      await fresh.setThemeName('mono');
      await fresh.setPasscode('9999');
      await fresh.importAll(dump);

      // Tags + usage.
      final freshTags = await fresh.watchTags().first;
      expect(freshTags.map((t) => t.name), contains('Work'));
      final freshExpense = (await fresh.watchTransactions().first)
          .firstWhere((t) => t.payee == 'Big Bazaar');
      expect(
        await fresh.tagIdsForTransaction(freshExpense.id),
        hasLength(1),
        reason: 'the tag link on the transaction must survive too',
      );

      // Preset tag on a recurring rule (recurringRuleTags, #63).
      final freshSpotify = (await fresh.watchRecurringRules().first)
          .firstWhere((r) => r.name == 'Spotify');
      expect(
        await fresh.tagIdsForRecurringRule(freshSpotify.id),
        hasLength(1),
        reason: 'the preset tag on a recurring rule must survive too',
      );

      // Tag group bundling that tag (tagGroupTags, #92).
      final freshGroup = (await fresh.watchTagGroups().first)
          .firstWhere((g) => g.name == 'Work trip');
      expect(
        await fresh.tagIdsForGroup(freshGroup.id),
        hasLength(1),
        reason: 'the tag link on the group must survive too',
      );

      // Manual link between two transactions (transactionLinks, #64).
      final freshIncome = (await fresh.watchTransactions().first)
          .firstWhere((t) => t.type == TxType.income);
      expect(
        (await fresh.linkedTransactions(freshExpense.id)).map((t) => t.id),
        [freshIncome.id],
        reason: 'the manual link between the two transactions must survive',
      );

      // Receipt path + payee.
      expect(
        freshExpense.imagePath,
        '/data/user/0/com.yash.xpenc/app_flutter/receipts/r1.jpg',
      );
      expect(freshExpense.payee, 'Big Bazaar');

      // Shopping lists — both lists, each with its item.
      final freshLists = await fresh.watchAllShoppingItems().first;
      expect(freshLists.map((i) => i.name), containsAll(['Milk', 'Diyas']));

      // Savings goal + its contribution transfer.
      final freshGoalAccount = (await fresh.watchAccounts().first)
          .firstWhere((a) => a.name == 'Trip to Goa');
      expect(freshGoalAccount.currentBalance, Money.fromRupees(2000));
      final freshGoalDetail = await fresh
          .watchGoalDetail(freshGoalAccount.id)
          .first;
      expect(freshGoalDetail?.targetAmount, Money.fromRupees(20000));

      // Credit card statement/due-date tracking.
      final freshCard = (await fresh.watchAccounts().first).firstWhere(
        (a) => a.name == 'HDFC Credit Card',
      );
      final freshCardDetail = await fresh.getCreditCardDetails(freshCard.id);
      expect(freshCardDetail?.statementDay, 5);
      expect(freshCardDetail?.dueDay, 25);
      expect(freshCardDetail?.notifyDaysBefore, 2);

      // Archived account and person.
      final freshArchivedAccounts = await fresh.watchArchivedAccounts().first;
      expect(freshArchivedAccounts.map((a) => a.name), contains('Old Wallet'));
      final freshArchivedPersons = await fresh.watchArchivedPersons().first;
      expect(
        freshArchivedPersons.map((p) => p.name),
        contains('Retired Debtor'),
      );

      // App settings restored from the backup...
      final freshSettings = await fresh.getSettings();
      expect(freshSettings.currencyCode, 'USD');
      expect(freshSettings.showCurrencySymbol, isFalse);
      expect(freshSettings.notificationsEnabled, isFalse);
      expect(freshSettings.countRepaymentsAsIncome, isTrue);
      expect(freshSettings.preventScreenshots, isTrue);
      expect(freshSettings.autoBackupEnabled, isTrue);
      expect(freshSettings.autoBackupFrequency, AutoBackupFrequency.monthly);
      expect(freshSettings.backupRetentionDays, 60);

      // ...but theme and passcode stay whatever the device already had —
      // restoring a ledger must never repaint or re-lock the phone it lands
      // on.
      expect(freshSettings.themeName, 'mono');
      expect(await fresh.verifyPasscode('9999'), isTrue);
      expect(await fresh.verifyPasscode('1357'), isFalse);
    });
  });

  group('CSV export', () {
    test('escapes commas and quotes, and writes decimal rupees', () async {
      await seedRealisticData();
      final csv = await db.transactionsCsv();
      final lines = csv.trim().split('\n');

      expect(
        lines.first,
        'Date,Type,Amount,Account,To Account,Category,Person,Note,'
        'Foreign Amount,Foreign Currency',
      );
      // header + 3 manual transactions + the personOut row for lending Ram 500
      expect(lines, hasLength(5));

      // Lending names the person, carries no category, and is its own type.
      final loan = lines.firstWhere((l) => l.contains('personOut'));
      expect(loan, contains('Ram'));
      expect(loan, contains('500.00'));

      final shopping = lines.firstWhere((l) => l.contains('Shopping'));
      expect(shopping, contains('1234.56'));
      expect(shopping, contains('"has, a comma ""and quotes"""'));

      final transfer = lines.firstWhere((l) => l.contains('transfer'));
      expect(transfer, contains('IPPB'));
      expect(transfer, contains('Cash'));
    });
  });
}
