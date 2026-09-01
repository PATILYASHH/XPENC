import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../core/group_split_math.dart';
import '../core/money.dart';
import '../core/security/passcode.dart';
import '../features/message_capture/parser/bank_message.dart';
import '../features/message_capture/parser/message_parser.dart';
import 'tables.dart';

part 'database.g.dart';

/// Money movement for a transaction relative to one particular account (or an
/// "own" family of accounts — that account plus any debit card drawing on it).
///
/// - income    → `+amount`  (money in)
/// - expense   → `-amount`  (money out)
/// - personIn  → `+amount`  (a person handed money to you)
/// - personOut → `-amount`  (you handed money to a person)
/// - transfer  → `-amount` when this account (or a debit card on it) is the
///   source, otherwise `+amount` because it is the destination.
Money accountMovement(TransactionRow tx, Set<int> ownIds) => switch (tx.type) {
  TxType.income || TxType.personIn => tx.amount,
  TxType.expense || TxType.personOut => -tx.amount,
  TxType.transfer => ownIds.contains(tx.accountId) ? -tx.amount : tx.amount,
};

/// The gap between automatic backups for a given schedule. `monthly` is
/// approximated as 30 days — good enough for "about once a month" without
/// pulling in calendar-month arithmetic for what is, after all, just a
/// safety copy, not a bill due date.
Duration autoBackupInterval({
  required AutoBackupFrequency frequency,
  int customDays = 0,
  int customHours = 0,
}) => switch (frequency) {
  AutoBackupFrequency.daily => const Duration(days: 1),
  AutoBackupFrequency.monthly => const Duration(days: 30),
  AutoBackupFrequency.custom => Duration(days: customDays, hours: customHours),
};

/// Whether an automatic backup is due, given the schedule in [settings] and
/// the current time [now]. Pure — no I/O — so every combination of
/// frequency and elapsed time is trivial to test without a database.
bool isAutoBackupDue(SettingRow settings, DateTime now) {
  if (!settings.autoBackupEnabled) return false;
  final last = settings.lastAutoBackupAt;
  if (last == null) return true; // never run — due immediately
  final interval = autoBackupInterval(
    frequency: settings.autoBackupFrequency,
    customDays: settings.autoBackupCustomDays,
    customHours: settings.autoBackupCustomHours,
  );
  return !now.isBefore(last.add(interval));
}

/// One priced row of an account statement, already carrying the running
/// balance *after* it posted.
typedef StatementLine = ({
  int transactionId,
  DateTime date,
  String description,
  Money debit,
  Money credit,
  Money balance,
});

/// Everything needed to render one account's statement for a period.
typedef AccountStatement = ({
  Money openingBalance,
  List<StatementLine> lines,
  Money closingBalance,
});

/// One category's planned-vs-actual line for a budget statement.
typedef BudgetStatementLine = ({
  CategoryRow category,
  Money budgeted,
  Money spent,
});

/// One expense row on a single category's statement — either a normal
/// transaction wholly in that category, or one leg of a split expense, in
/// which case [amount] is that leg's slice, not the whole transaction.
typedef CategoryStatementLine = ({
  DateTime date,
  String description,
  Money amount,
  bool isSplit,
});

/// Everything needed to render one category's budget statement for a month.
typedef CategoryStatement = ({
  CategoryRow category,
  Money budgeted,
  Money spent,
  List<CategoryStatementLine> lines,
});

/// One row of the combined, every-account statement — a real bank-style
/// statement merged date-wise across every account rather than grouped by
/// one. [amount] is always the transaction's own stored (positive) amount;
/// [type] is what tells a reader whether it left, arrived, or just moved
/// between two of the user's own accounts.
typedef CombinedStatementLine = ({
  DateTime date,
  String accountName,
  String type,
  String description,
  Money amount,
});

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Budgets,
    Persons,
    PersonEntries,
    Groups,
    GroupMembers,
    GroupExpenses,
    GroupExpenseShares,
    Reminders,
    Settings,
    PendingTxns,
    MerchantRules,
    SenderRules,
    BudgetAlerts,
    RecurringRules,
    Tags,
    TransactionTags,
    RecurringRuleTags,
    TagGroups,
    TagGroupTags,
    TransactionSplits,
    TransactionLinks,
    GoalDetails,
    LoanDetails,
    ShoppingLists,
    ShoppingItems,
    BackupRecords,
    Allocations,
    OcrCorrections,
    CreditCardDetails,
  ],
)
class AppDatabase extends _$AppDatabase {
  // The SQLite filename, NOT a brand. It survived the rename to XPENC on
  // purpose: it is a persistence key no user ever sees, and renaming it would
  // point the app at a fresh, empty database — silently losing the ledger of
  // anyone whose data directory carries over.
  //
  // `shareAcrossIsolates: true`: the quick-add notification's reply handler
  // (see `notification_service.dart`) opens its own `AppDatabase` from a
  // background isolate flutter_local_notifications spawns for it. Without
  // this, two independent connections to the same file race each other —
  // drift's own docs recommend this exact flag for "used on multiple
  // isolates." Every other `AppDatabase()` call (including every test)
  // shares the same default, so the main app gets the same safety for free.
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'money_manager',
              native: const DriftNativeOptions(shareAcrossIsolates: true),
            ),
      );

  @override
  int get schemaVersion => 57;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seed();
      await _seedSenderRules();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(pendingTxns);
        await m.createTable(merchantRules);
        await m.createTable(senderRules);
        await m.createTable(budgetAlerts);
        await _addColumnIfMissing(m, settings, settings.messageCaptureEnabled);
        await _addColumnIfMissing(m, settings, settings.lastMessageScanAt);
        await _addColumnIfMissing(m, settings, settings.notificationsEnabled);
        await _seedSenderRules();
      }
      if (from < 3) {
        await _addColumnIfMissing(m, transactions, transactions.personId);
        await _addColumnIfMissing(
          m,
          personEntries,
          personEntries.transactionId,
        );
        await backfillPersonTransactions();
      }
      if (from < 4) {
        await _addColumnIfMissing(m, settings, settings.themeName);
      }
      if (from < 5) {
        // Additive and nullable: every existing category becomes a
        // top-level one (parentId stays null). Nothing to backfill.
        await _addColumnIfMissing(m, categories, categories.parentId);
      }
      if (from < 6) {
        // Defaults true, so existing users keep seeing their symbol.
        await _addColumnIfMissing(m, settings, settings.showCurrencySymbol);
      }
      if (from < 7) {
        // Additive and nullable: every existing transaction just has no
        // payee. Nothing to backfill.
        await _addColumnIfMissing(m, transactions, transactions.payee);
      }
      if (from < 8) {
        await m.createTable(recurringRules);
        await _addColumnIfMissing(
          m,
          transactions,
          transactions.recurringRuleId,
        );
      }
      if (from < 9) {
        await m.createTable(tags);
        await m.createTable(transactionTags);
      }
      if (from < 10) {
        await m.createTable(transactionSplits);
      }
      if (from < 11) {
        await _addColumnIfMissing(m, transactions, transactions.imagePath);
      }
      if (from < 12) {
        await _addColumnIfMissing(m, personEntries, personEntries.categoryId);
        await _addColumnIfMissing(
          m,
          settings,
          settings.countRepaymentsAsIncome,
        );
      }
      if (from < 14) {
        await _addColumnIfMissing(m, settings, settings.passcodeHash);
        await _addColumnIfMissing(m, settings, settings.passcodeSalt);
        await _addColumnIfMissing(m, settings, settings.biometricEnabled);
      }
      if (from < 15) {
        await _addColumnIfMissing(m, settings, settings.expenseReminderEnabled);
        await _addColumnIfMissing(m, settings, settings.expenseReminderHour);
        await _addColumnIfMissing(m, settings, settings.expenseReminderMinute);
      }
      if (from < 16) {
        await m.createTable(shoppingItems);
      }
      if (from < 17) {
        await m.createTable(shoppingLists);
        await _addColumnIfMissing(m, shoppingItems, shoppingItems.listId);
        await backfillShoppingListIds();
      }
      if (from < 18) {
        await m.createTable(backupRecords);
        await _addColumnIfMissing(m, settings, settings.autoBackupEnabled);
        await _addColumnIfMissing(m, settings, settings.autoBackupFrequency);
        await _addColumnIfMissing(m, settings, settings.autoBackupCustomDays);
        await _addColumnIfMissing(m, settings, settings.autoBackupCustomHours);
        await _addColumnIfMissing(m, settings, settings.lastAutoBackupAt);
        await _addColumnIfMissing(m, settings, settings.backupRetentionDays);
      }
      if (from < 19) {
        await _addColumnIfMissing(m, recurringRules, recurringRules.isEstimate);
        await _addColumnIfMissing(
          m,
          transactions,
          transactions.needsAmountReview,
        );
      }
      if (from < 20) {
        await _addColumnIfMissing(m, settings, settings.preventScreenshots);
      }
      if (from < 21) {
        // A goal used to be a metadata row that merely pointed at — and
        // read the live balance of — some other account. It's now a real
        // account of its own (AccountType.goal), same as Prepaid Balance,
        // funded only by transfers. GoalDetails is the (much smaller)
        // replacement for the old SavingsGoals table, which this step also
        // retires. Nothing else in the schema ever referenced SavingsGoals,
        // so — unlike every migration above it — this one is safe to
        // collapse into a single step instead of replaying each version's
        // history: whatever `from` a database starts at, migrating its
        // savings_goals rows (if the table even exists) straight to the
        // final shape lands on the same result.
        await m.createTable(goalDetails);
        await migrateSavingsGoalsToGoalAccounts();
      }
      if (from < 22) {
        await _addColumnIfMissing(m, budgets, budgets.note);
      }
      if (from < 23) {
        await _addColumnIfMissing(m, accounts, accounts.envelopeMode);
        await m.createTable(allocations);
      }
      if (from < 24) {
        await _addColumnIfMissing(m, settings, settings.passcodeLength);
      }
      if (from < 25) {
        await _addColumnIfMissing(m, transactions, transactions.paymentGroupId);
      }
      if (from < 26) {
        await _addColumnIfMissing(
          m,
          settings,
          settings.notificationQuickAddEnabled,
        );
      }
      if (from < 27) {
        await _addColumnIfMissing(m, settings, settings.quickAddAccountId);
      }
      if (from < 28) {
        await _addColumnIfMissing(m, pendingTxns, pendingTxns.sourceImagePath);
      }
      if (from < 29) {
        await _addColumnIfMissing(m, settings, settings.hideAmounts);
      }
      if (from < 30) {
        await m.createTable(ocrCorrections);
      }
      if (from < 31) {
        await _addColumnIfMissing(m, settings, settings.pinTimeoutMinutes);
      }
      if (from < 32) {
        await m.createTable(recurringRuleTags);
      }
      if (from < 33) {
        await m.createTable(transactionLinks);
      }
      if (from < 34) {
        await _addColumnIfMissing(m, settings, settings.bottomNavSlots);
      }
      if (from < 35) {
        await _addColumnIfMissing(m, goalDetails, goalDetails.categoryId);
      }
      if (from < 36) {
        await m.createTable(loanDetails);
      }
      if (from < 37) {
        await _addColumnIfMissing(m, goalDetails, goalDetails.notes);
      }
      if (from < 38) {
        await _addColumnIfMissing(m, settings, settings.showCalendarDayTotals);
      }
      if (from < 39) {
        await _addColumnIfMissing(m, settings, settings.fontScalePercent);
        await _addColumnIfMissing(m, settings, settings.fontWeightDelta);
        await _addColumnIfMissing(m, settings, settings.fontFamily);
      }
      if (from < 40) {
        await _addColumnIfMissing(m, accounts, accounts.includeInNetWorth);
      }
      if (from < 41) {
        await _addColumnIfMissing(m, settings, settings.masterPhraseHash);
        await _addColumnIfMissing(m, settings, settings.masterPhraseSalt);
        await _addColumnIfMissing(
          m,
          settings,
          settings.masterPhraseAttemptThreshold,
        );
        await _addColumnIfMissing(
          m,
          settings,
          settings.failedPasscodeAttempts,
        );
      }
      if (from < 42) {
        await _addColumnIfMissing(m, settings, settings.showBottomNavLabels);
      }
      if (from < 43) {
        await _addColumnIfMissing(m, settings, settings.extraBottomInset);
      }
      if (from < 44) {
        await _addColumnIfMissing(m, persons, persons.upiId);
        await _addColumnIfMissing(m, persons, persons.phone);
        await _addColumnIfMissing(m, persons, persons.paypal);
        await _addColumnIfMissing(m, settings, settings.myUpiId);
        await _addColumnIfMissing(m, settings, settings.myUpiName);
      }
      if (from < 45) {
        await _addColumnIfMissing(m, settings, settings.holdMenuEnabled);
        await _addColumnIfMissing(m, settings, settings.holdMenuSlots);
      }
      if (from < 46) {
        await m.createTable(groups);
        await m.createTable(groupMembers);
        await m.createTable(groupExpenses);
        await m.createTable(groupExpenseShares);
      }
      if (from < 47) {
        await _addColumnIfMissing(m, recurringRules, recurringRules.note);
      }
      if (from < 48) {
        await _addColumnIfMissing(m, recurringRules, recurringRules.promoAmount);
        await _addColumnIfMissing(
          m,
          recurringRules,
          recurringRules.promoOccurrencesLeft,
        );
      }
      if (from < 49) {
        await _addColumnIfMissing(m, settings, settings.myPaypal);
      }
      if (from < 50) {
        await _addColumnIfMissing(m, persons, persons.venmo);
        await _addColumnIfMissing(m, persons, persons.cashapp);
        await _addColumnIfMissing(m, persons, persons.revolut);
        await _addColumnIfMissing(m, settings, settings.myVenmo);
        await _addColumnIfMissing(m, settings, settings.myCashapp);
        await _addColumnIfMissing(m, settings, settings.myRevolut);
      }
      if (from < 51) {
        await _addColumnIfMissing(m, settings, settings.upiEnabled);
        await _addColumnIfMissing(m, settings, settings.paypalEnabled);
        await _addColumnIfMissing(m, settings, settings.venmoEnabled);
        await _addColumnIfMissing(m, settings, settings.cashappEnabled);
        await _addColumnIfMissing(m, settings, settings.revolutEnabled);
      }
      if (from < 52) {
        await _addColumnIfMissing(m, settings, settings.lockScreenStyle);
      }
      if (from < 53) {
        await _addColumnIfMissing(
          m,
          settings,
          settings.screenshotReminderEnabled,
        );
      }
      if (from < 54) {
        await m.createTable(creditCardDetails);
      }
      if (from < 55) {
        // Adds RecurringRules.toAccountId and loosens categoryId to
        // nullable (a G&L rule's transfer carries neither) — SQLite can't
        // relax a NOT NULL via a plain ALTER TABLE, so this recreates the
        // table against the current Dart schema, copying existing rows by
        // column name.
        await m.alterTable(
          TableMigration(
            recurringRules,
            newColumns: [recurringRules.toAccountId],
          ),
        );
      }
      if (from < 56) {
        await _addColumnIfMissing(m, settings, settings.moreScreenViewMode);
      }
      if (from < 57) {
        await m.createTable(tagGroups);
        await m.createTable(tagGroupTags);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      final hasSettings = await select(settings).get();
      if (hasSettings.isEmpty) {
        await into(settings).insert(const SettingsCompanion());
      }
      // Safety net. `recalculateBalances` now reads only `transactions`, so
      // an entry left without its ledger row (a migration that died halfway,
      // an old backup restored) would quietly stop affecting the balance.
      // This is a no-op once everything is linked.
      await backfillPersonTransactions();
      // Same idea: an old backup restored after this update has no
      // `listId` to import (see `importAll`), which reintroduces the
      // exact orphaned shape the v17 migration repairs.
      await backfillShoppingListIds();
    },
  );

  /// True if [table] already has a column named [column].
  ///
  /// `Migrator.createTable` already guards itself with `CREATE TABLE IF NOT
  /// EXISTS`, but `Migrator.addColumn` is a bare `ALTER TABLE ADD COLUMN`
  /// with no such guard — SQLite has no `ADD COLUMN IF NOT EXISTS`. If a
  /// database's stored `user_version` ever undercounts its real shape (a
  /// build from the rolling BETA-branch APK channel applied a step under a
  /// version number since reused for something else, a migration died
  /// half-way through a batched step, ...), re-running `addColumn` throws
  /// `duplicate column name` and the app can never open the database again
  /// — see GitHub #49 / #50. [_addColumnIfMissing] makes that a no-op
  /// instead.
  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect(
      "SELECT 1 FROM pragma_table_info('$table') WHERE name = '$column'",
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    if (await _hasColumn(table.actualTableName, column.name)) return;
    await m.addColumn(table, column);
  }

  /// v2 → v3: person entries used to poke the account balance directly, with no
  /// ledger row. Give each one that moved money a real `personOut`/`personIn`
  /// transaction, then rebuild balances from that single ledger.
  ///
  /// Inserts go in raw — `addTransaction` would adjust the cached balance a
  /// second time on top of what the old code already applied.
  ///
  /// **Idempotent**, and also run on every open (see `beforeOpen`) so an entry
  /// orphaned by a half-finished migration is repaired rather than silently
  /// dropped out of `recalculateBalances`, which now reads only `transactions`.
  Future<int> backfillPersonTransactions() async {
    final entries = await (select(
      personEntries,
    )..where((e) => e.accountId.isNotNull() & e.transactionId.isNull())).get();
    if (entries.isEmpty) return 0;

    for (final e in entries) {
      final person = await (select(
        persons,
      )..where((p) => p.id.equals(e.personId))).getSingleOrNull();

      final txId = await into(transactions).insert(
        TransactionsCompanion.insert(
          type: e.direction == PersonDirection.theyOwe
              ? TxType.personOut
              : TxType.personIn,
          amount: e.amount,
          accountId: e.accountId!,
          personId: Value(e.personId),
          date: e.date,
          note: Value(
            e.note ??
                (e.direction == PersonDirection.theyOwe
                    ? 'Gave to ${person?.name ?? 'person'}'
                    : 'Received from ${person?.name ?? 'person'}'),
          ),
        ),
      );

      await (update(personEntries)..where((x) => x.id.equals(e.id))).write(
        PersonEntriesCompanion(transactionId: Value(txId)),
      );
    }

    // The cache was built from the old two-ledger maths. Rebuild it from the
    // one ledger that now holds every movement.
    await recalculateBalances();
    return entries.length;
  }

  /// v16 -> v17: a shopping item made before named lists existed has no
  /// list. Moves every orphaned item onto one newly-created default list, so
  /// nothing already on a user's list vanishes.
  ///
  /// **Idempotent** (a second call finds nothing orphaned and does nothing),
  /// and also run on every open (see `beforeOpen`) for the same reason
  /// [backfillPersonTransactions] is: a backup taken before this update has
  /// no `listId` to import, which reintroduces this exact orphaned shape.
  Future<int> backfillShoppingListIds() async {
    final orphaned = await (select(
      shoppingItems,
    )..where((i) => i.listId.isNull())).get();
    if (orphaned.isEmpty) return 0;

    final defaultListId = await into(shoppingLists).insert(
      ShoppingListsCompanion.insert(
        name: 'Shopping List',
        colorValue: 0xFF16A34A,
      ),
    );
    await (update(shoppingItems)..where((i) => i.listId.isNull())).write(
      ShoppingItemsCompanion(listId: Value(defaultListId)),
    );
    return orphaned.length;
  }

  /// v20 -> v21: a goal used to be a metadata row pointing at some other
  /// account and reading its live balance. Raw SQL, not the typed API,
  /// because the `SavingsGoals` Dart table this once was no longer exists —
  /// see the migration step that calls this.
  ///
  /// For each old goal: a new [AccountType.goal] account is seeded with the
  /// linked account's current balance (the same "saved so far" figure the
  /// old UI showed), so the new goal starts already reflecting what the
  /// user was seeing — no transaction is fabricated to explain how it got
  /// there. The linked account itself is left completely untouched.
  ///
  /// Not private: exercised directly in `database_test.dart` against a
  /// hand-seeded `savings_goals` table, since this app has no schema-snapshot
  /// tooling to replay a real v13-v20 database through `onUpgrade`.
  @visibleForTesting
  Future<void> migrateSavingsGoalsToGoalAccounts() async {
    final exists = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'savings_goals'",
    ).getSingleOrNull();
    if (exists == null) return;

    final oldGoals = await customSelect('SELECT * FROM savings_goals').get();
    for (final row in oldGoals) {
      await _createGoalAccountFromLegacy(
        name: row.read<String>('name'),
        colorValue: row.read<int>('color_value'),
        iconKey: row.read<String>('icon_key'),
        isArchived: row.read<bool>('is_archived'),
        createdAt: row.read<DateTime>('created_at'),
        targetAmount: Money(row.read<int>('target_amount')),
        targetDate: row.readNullable<DateTime>('target_date'),
        linkedAccountId: row.read<int>('account_id'),
      );
    }

    await customStatement('DROP TABLE savings_goals');
  }

  /// Shared by the live-database migration above and [importAll]'s handling
  /// of a backup taken before this version — both need to turn one old
  /// "goal that tracks another account" row into a real [AccountType.goal]
  /// account. [openingBalance] (not just [currentBalance]) carries the
  /// snapshot, or [recalculateBalances] — run after every import, and
  /// available any time from Settings — would rebuild this account from an
  /// empty ledger and silently zero it back out.
  Future<void> _createGoalAccountFromLegacy({
    required String name,
    required int colorValue,
    required String iconKey,
    required bool isArchived,
    required DateTime createdAt,
    required Money targetAmount,
    DateTime? targetDate,
    required int linkedAccountId,
  }) async {
    final linked = await (select(
      accounts,
    )..where((a) => a.id.equals(linkedAccountId))).getSingleOrNull();
    final savedSoFar = linked?.currentBalance ?? const Money.zero();

    final goalAccountId = await into(accounts).insert(
      AccountsCompanion.insert(
        name: name,
        type: AccountType.goal,
        colorValue: colorValue,
        iconKey: iconKey,
        openingBalance: savedSoFar,
        currentBalance: savedSoFar,
        isArchived: Value(isArchived),
        createdAt: Value(createdAt),
      ),
    );
    await into(goalDetails).insert(
      GoalDetailsCompanion.insert(
        accountId: Value(goalAccountId),
        targetAmount: targetAmount,
        targetDate: Value(targetDate),
      ),
    );
  }

  Future<void> _seedSenderRules() async {
    for (final r in kSeedSenderRules) {
      await into(senderRules).insert(
        SenderRulesCompanion.insert(senderPattern: r.pattern, bankName: r.bank),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  // ── Seed ──────────────────────────────────────────────────────────────────

  Future<void> _seed() async {
    await into(settings).insert(const SettingsCompanion());
    await _seedDefaultAccountsAndCategories();
  }

  /// Just the starting ledger shape — one Cash account plus the default
  /// category set — shared by [_seed] (brand-new database) and
  /// [clearAllData] (an existing database wiped back to a fresh start), so
  /// neither can drift from the other.
  Future<void> _seedDefaultAccountsAndCategories() async {
    // Only Cash is seeded. The user adds their own Bank/Card accounts.
    await into(accounts).insert(
      AccountsCompanion.insert(
        name: 'Cash',
        type: AccountType.cash,
        colorValue: 0xFF16A34A,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
        currentBalance: const Money.zero(),
      ),
    );

    const income = <(String, String, int)>[
      ('Salary', 'salary', 0xFF16A34A),
      ('Profit', 'profit', 0xFF0EA5E9),
      ('Gift', 'gift', 0xFFA855F7),
      ('Cash', 'cash', 0xFF22C55E),
      ('Interest', 'interest', 0xFF14B8A6),
      ('Refund', 'refund', 0xFF64748B),
    ];
    const expense = <(String, String, int)>[
      ('Rent', 'rent', 0xFFDC2626),
      ('Food', 'food', 0xFFF97316),
      ('Groceries', 'groceries', 0xFF84CC16),
      ('Transport', 'transport', 0xFF3B82F6),
      ('Bills', 'bills', 0xFF8B5CF6),
      ('Shopping', 'shopping', 0xFFEC4899),
      ('Health', 'health', 0xFFEF4444),
      ('Entertainment', 'entertainment', 0xFF06B6D4),
      ('EMI', 'emi', 0xFF78716C),
    ];

    var order = 0;
    for (final (name, icon, color) in income) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: name,
          kind: CategoryKind.income,
          colorValue: color,
          iconKey: icon,
          sortOrder: Value(order++),
        ),
      );
    }
    order = 0;
    for (final (name, icon, color) in expense) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: name,
          kind: CategoryKind.expense,
          colorValue: color,
          iconKey: icon,
          sortOrder: Value(order++),
        ),
      );
    }
  }

  /// Wipes every account, transaction, category, budget, person and
  /// everything else that makes up the ledger, then reseeds the same
  /// defaults a brand-new install gets — a fresh start without an actual
  /// reinstall.
  ///
  /// Preferences (currency, theme, passcode, notification and backup
  /// settings) are left alone — this resets the *data*, not the app around
  /// it. Bank-sender seed rules ([senderRules]) are static reference data,
  /// not user data, and stay too. Backup records are also left alone: they
  /// describe files still sitting in `Download/BACKUP XPENC` on the device,
  /// which this method never touches — forgetting about them here would just
  /// orphan them.
  ///
  /// Deletes go children-before-parents, the same order [importAll] already
  /// established, so foreign keys never reject a delete partway through.
  Future<void> clearAllData() => transaction(() async {
    await delete(budgetAlerts).go();
    await delete(pendingTxns).go();
    await delete(merchantRules).go();
    await delete(reminders).go();
    await delete(personEntries).go();
    await delete(budgets).go();
    await delete(transactionSplits).go();
    await delete(transactionTags).go();
    await delete(goalDetails).go();
    await delete(creditCardDetails).go();
    await delete(shoppingItems).go();
    await delete(shoppingLists).go();
    // transactions references accounts/categories/persons/recurringRules,
    // so it must go before all four.
    await delete(transactions).go();
    await delete(recurringRules).go();
    await delete(persons).go();
    await delete(categories).go();
    await delete(accounts).go();
    await delete(tags).go();
    await _seedDefaultAccountsAndCategories();
  });

  // ── Balance mechanics ─────────────────────────────────────────────────────

  /// Debit cards and UPI instruments hold no balance of their own — they draw
  /// from the bank they are linked to. Resolve to the account that actually
  /// holds the money, so `Bank + Debit Card` can never double-count.
  Future<int> _balanceTarget(int accountId) async {
    final row = await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    return row.linkedAccountId ?? row.id;
  }

  Future<void> _adjust(int accountId, Money delta) async {
    if (delta.isZero) return;
    final target = await _balanceTarget(accountId);
    await customUpdate(
      'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
      variables: [Variable.withInt(delta.paise), Variable.withInt(target)],
      updates: {accounts},
    );
  }

  /// Net effect of one transaction on account balances, applied or reversed.
  Future<void> _applyTxEffect(TransactionRow t, {required bool reverse}) async {
    final sign = reverse ? -1 : 1;
    final amt = Money(t.amount.paise * sign);

    switch (t.type) {
      case TxType.income:
      // Money came back from a person (they repaid you, or you borrowed).
      case TxType.personIn:
        await _adjust(t.accountId, amt);
      case TxType.expense:
      // Money went to a person (you lent, or you repaid them).
      case TxType.personOut:
        await _adjust(t.accountId, -amt);
      case TxType.transfer:
        await _adjust(t.accountId, -amt);
        await _adjust(t.toAccountId!, amt);
    }
  }

  Future<void> _validateTx({
    required TxType type,
    required Money amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    int? personId,
    String? payee,
    int? recurringRuleId,
  }) async {
    // Zero is a legitimate income/expense (GitHub #87) — a free item, a
    // discount that fully covers the price, a promo month that costs
    // nothing. A transfer or person movement of ₹0 has no real meaning
    // (nothing actually moved), so those stay strictly positive.
    final amountValid = type.isIncomeOrExpense
        ? !amount.isNegative
        : amount.isPositive;
    if (!amountValid) {
      throw ArgumentError(
        type.isIncomeOrExpense
            ? 'Amount cannot be negative; direction comes from type.'
            : 'Amount must be positive; direction comes from type.',
      );
    }
    // Goals and loans are not spendable accounts — they are only ever funded
    // or drawn down by a transfer.
    if (type != TxType.transfer) {
      final account = await (select(
        accounts,
      )..where((a) => a.id.equals(accountId))).getSingleOrNull();
      if (account?.type == AccountType.goal ||
          account?.type == AccountType.loan) {
        throw ArgumentError(
          'A goal or loan account is not spendable — transfer funds instead.',
        );
      }
    }
    if (!type.isPersonMovement && personId != null) {
      throw ArgumentError('Only a person movement names a person.');
    }
    if (!type.isIncomeOrExpense && payee != null) {
      throw ArgumentError('Only an income or expense names a payee.');
    }
    if (!type.isIncomeOrExpense &&
        type != TxType.transfer &&
        recurringRuleId != null) {
      throw ArgumentError(
        'Only income, expense or a transfer can come from a rule.',
      );
    }
    switch (type) {
      case TxType.transfer:
        if (toAccountId == null) {
          throw ArgumentError('A transfer needs a destination account.');
        }
        if (toAccountId == accountId) {
          throw ArgumentError('Cannot transfer to the same account.');
        }
        if (categoryId != null) {
          final from = await (select(
            accounts,
          )..where((a) => a.id.equals(accountId))).getSingleOrNull();
          final to = await (select(
            accounts,
          )..where((a) => a.id.equals(toAccountId))).getSingleOrNull();
          final touchesGoalOrLoan = {
            from?.type,
            to?.type,
          }.any((t) => t == AccountType.goal || t == AccountType.loan);
          if (!touchesGoalOrLoan) {
            throw ArgumentError(
              'Only a goal or loan contribution can carry a category.',
            );
          }
        }
      case TxType.personOut:
      case TxType.personIn:
        if (personId == null) {
          throw ArgumentError('A person movement must name the person.');
        }
        if (categoryId != null) {
          throw ArgumentError(
            'Lending is not spending — a person movement carries no category.',
          );
        }
        if (toAccountId != null) {
          throw ArgumentError('Only transfers have a destination account.');
        }
      case TxType.income:
      case TxType.expense:
        if (toAccountId != null) {
          throw ArgumentError('Only transfers have a destination account.');
        }
    }
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  /// Best-effort: a receipt photo missing from disk (moved, already gone, a
  /// restored backup pointing at a path that never existed on this device) is
  /// never a reason to fail the transaction write it's attached to.
  Future<void> _deleteReceiptFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignored — see above.
    }
  }

  Future<int> addTransaction({
    required TxType type,
    required Money amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    int? personId,
    required DateTime date,
    String? note,
    String? payee,
    int? recurringRuleId,
    String? imagePath,
    bool needsAmountReview = false,
  }) async {
    await _validateTx(
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      personId: personId,
      payee: payee,
      recurringRuleId: recurringRuleId,
    );

    return transaction(() async {
      final id = await into(transactions).insert(
        TransactionsCompanion.insert(
          type: type,
          amount: amount,
          accountId: accountId,
          toAccountId: Value(toAccountId),
          categoryId: Value(categoryId),
          personId: Value(personId),
          date: date,
          note: Value(note),
          payee: Value(payee),
          recurringRuleId: Value(recurringRuleId),
          imagePath: Value(imagePath),
          needsAmountReview: Value(needsAmountReview),
        ),
      );
      final row = await (select(
        transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      await _applyTxEffect(row, reverse: false);
      return id;
    });
  }

  /// Posts one expense split across several accounts at once — e.g. ₹25
  /// from the bank, ₹5 cash, ₹0.80 from a prepaid balance, for one ₹30.80
  /// purchase. Each [legs] entry becomes its own ordinary transaction row,
  /// all sharing a `paymentGroupId` — see the doc on
  /// `Transactions.paymentGroupId`. Returns every leg's id, first leg
  /// (the group's anchor) first.
  ///
  /// Expense-only and deliberately kept apart from [TransactionSplits]
  /// (which splits one expense across *categories* instead of accounts) —
  /// combining both at once is a 2-D matrix this app doesn't offer yet.
  Future<List<int>> addHybridPaymentTransaction({
    required List<({int accountId, Money amount})> legs,
    int? categoryId,
    required DateTime date,
    String? note,
    String? payee,
    String? imagePath,
  }) async {
    if (legs.length < 2) {
      throw ArgumentError('A split payment needs at least two accounts.');
    }
    for (final leg in legs) {
      await _validateTx(
        type: TxType.expense,
        amount: leg.amount,
        accountId: leg.accountId,
        categoryId: categoryId,
        payee: payee,
      );
    }

    return transaction(() async {
      final ids = <int>[];
      for (final leg in legs) {
        // The receipt (if any) is attached to the anchor leg only — the
        // rest are plain money movements with nothing more to say.
        final isAnchor = ids.isEmpty;
        ids.add(
          await into(transactions).insert(
            TransactionsCompanion.insert(
              type: TxType.expense,
              amount: leg.amount,
              accountId: leg.accountId,
              categoryId: Value(categoryId),
              date: date,
              note: Value(note),
              payee: Value(payee),
              imagePath: Value(isAnchor ? imagePath : null),
            ),
          ),
        );
      }

      // Every leg — including the anchor itself — points at the first
      // leg's id, so "every row in this group" is one equality filter with
      // no separate id space to track.
      final groupId = ids.first;
      await (update(transactions)..where((t) => t.id.isIn(ids))).write(
        TransactionsCompanion(paymentGroupId: Value(groupId)),
      );

      for (final id in ids) {
        final row = await (select(
          transactions,
        )..where((t) => t.id.equals(id))).getSingle();
        await _applyTxEffect(row, reverse: false);
      }
      return ids;
    });
  }

  /// Posts a cash expense where part of the change received lands in a
  /// different account instead of back in the paying one — e.g. paying with
  /// a banknote and the coins received as change go into a separate "Coins"
  /// account (see GitHub #55). [amount] is the real cost of the purchase
  /// (never the amount handed over) — the change leg is an ordinary
  /// transfer of [changeAmount] out of [accountId] into [changeAccountId],
  /// linked to the expense via `paymentGroupId` the same way a hybrid
  /// payment's legs are. Returns `[expenseId, changeId]`.
  Future<List<int>> addExpenseWithChange({
    required Money amount,
    required int accountId,
    required int categoryId,
    required int changeAccountId,
    required Money changeAmount,
    required DateTime date,
    String? note,
    String? payee,
    String? imagePath,
  }) async {
    if (changeAccountId == accountId) {
      throw ArgumentError('Change must go to a different account.');
    }
    await _validateTx(
      type: TxType.expense,
      amount: amount,
      accountId: accountId,
      categoryId: categoryId,
      payee: payee,
    );
    await _validateTx(
      type: TxType.transfer,
      amount: changeAmount,
      accountId: accountId,
      toAccountId: changeAccountId,
    );

    return transaction(() async {
      final expenseId = await into(transactions).insert(
        TransactionsCompanion.insert(
          type: TxType.expense,
          amount: amount,
          accountId: accountId,
          categoryId: Value(categoryId),
          date: date,
          note: Value(note),
          payee: Value(payee),
          imagePath: Value(imagePath),
        ),
      );
      final changeId = await into(transactions).insert(
        TransactionsCompanion.insert(
          type: TxType.transfer,
          amount: changeAmount,
          accountId: accountId,
          toAccountId: Value(changeAccountId),
          date: date,
        ),
      );

      final ids = [expenseId, changeId];
      // Same anchor-points-at-itself shape as a hybrid payment's legs — see
      // the doc on [Transactions.paymentGroupId].
      await (update(transactions)..where((t) => t.id.isIn(ids))).write(
        TransactionsCompanion(paymentGroupId: Value(expenseId)),
      );

      for (final id in ids) {
        final row = await (select(
          transactions,
        )..where((t) => t.id.equals(id))).getSingle();
        await _applyTxEffect(row, reverse: false);
      }
      return ids;
    });
  }

  /// Every leg of the split payment [transactionId] belongs to, itself
  /// included — empty for an ordinary, ungrouped transaction.
  Future<List<TransactionRow>> paymentGroupLegs(int transactionId) async {
    final row = await (select(
      transactions,
    )..where((t) => t.id.equals(transactionId))).getSingleOrNull();
    final groupId = row?.paymentGroupId;
    if (groupId == null) return const [];
    return (select(
      transactions,
    )..where((t) => t.paymentGroupId.equals(groupId))).get();
  }

  // ── Transaction links (GitHub #64) ──────────────────────────────────────

  /// Every transaction manually linked to [transactionId], either direction
  /// — see [TransactionLinks].
  Future<List<TransactionRow>> linkedTransactions(int transactionId) async {
    final rows =
        await (select(transactionLinks)..where(
              (l) =>
                  l.transactionAId.equals(transactionId) |
                  l.transactionBId.equals(transactionId),
            ))
            .get();
    if (rows.isEmpty) return const [];
    final otherIds = rows.map(
      (r) => r.transactionAId == transactionId
          ? r.transactionBId
          : r.transactionAId,
    );
    return (select(transactions)..where((t) => t.id.isIn(otherIds))).get();
  }

  Stream<List<TransactionLinkRow>> watchTransactionLinks() =>
      select(transactionLinks).watch();

  /// Links [aId] and [bId] together, both directions at once — tapping
  /// either transaction's link chip reaches the other. Linking an
  /// already-linked pair again is a silent no-op rather than a duplicate-row
  /// error, since the picker has no way to know a link already exists.
  Future<void> addTransactionLink(int aId, int bId) async {
    if (aId == bId) {
      throw ArgumentError('A transaction cannot be linked to itself.');
    }
    final lo = aId < bId ? aId : bId;
    final hi = aId < bId ? bId : aId;
    await into(transactionLinks).insert(
      TransactionLinksCompanion.insert(transactionAId: lo, transactionBId: hi),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Removes the link between [aId] and [bId], if any.
  Future<void> removeTransactionLink(int aId, int bId) async {
    final lo = aId < bId ? aId : bId;
    final hi = aId < bId ? bId : aId;
    await (delete(transactionLinks)..where(
          (l) => l.transactionAId.equals(lo) & l.transactionBId.equals(hi),
        ))
        .go();
  }

  Future<void> deleteTransaction(int id) {
    return transaction(() async {
      final row = await (select(
        transactions,
      )..where((t) => t.id.equals(id))).getSingle();

      // A person movement belongs to that person's ledger. Deleting only the
      // money row would reverse the balance while still claiming the debt was
      // settled. Refuse, and send the user to the person instead.
      // (`deletePersonEntry` removes its entry first, so it never trips this.)
      final owner = await (select(
        personEntries,
      )..where((e) => e.transactionId.equals(id))).getSingleOrNull();
      if (owner != null) {
        throw ArgumentError(
          'This belongs to a person. Delete it from their page instead.',
        );
      }

      await _applyTxEffect(row, reverse: true);

      // Other rows point at this transaction. Clear those references first or
      // the foreign key constraint fires and the delete throws — leaving the
      // money reversed but the row still there.
      await (update(reminders)..where((r) => r.transactionId.equals(id))).write(
        const RemindersCompanion(transactionId: Value(null)),
      );
      await (update(pendingTxns)
            ..where((t) => t.createdTransactionId.equals(id)))
          .write(const PendingTxnsCompanion(createdTransactionId: Value(null)));
      // Deleting a hybrid-payment group's anchor leg must not orphan the
      // other legs' foreign key — ungroup them instead. They stay exactly
      // as valid, ordinary transactions on their own.
      await (update(transactions)..where((t) => t.paymentGroupId.equals(id)))
          .write(const TransactionsCompanion(paymentGroupId: Value(null)));
      // A tag link (or split line) is meaningless without its transaction —
      // drop the rows outright rather than nulling a reference, unlike the
      // two updates above.
      await (delete(
        transactionTags,
      )..where((t) => t.transactionId.equals(id))).go();
      await (delete(
        transactionSplits,
      )..where((s) => s.transactionId.equals(id))).go();
      // A manual link is meaningless once one side is gone — same hard
      // delete as the tag/split rows above, not a null-out.
      await (delete(transactionLinks)..where(
            (l) => l.transactionAId.equals(id) | l.transactionBId.equals(id),
          ))
          .go();
      await _deleteReceiptFile(row.imagePath);

      await (delete(transactions)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> updateTransaction({
    required int id,
    required TxType type,
    required Money amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    int? personId,
    required DateTime date,
    String? note,
    String? payee,
    String? imagePath,
  }) async {
    await _validateTx(
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      personId: personId,
      payee: payee,
    );

    return transaction(() async {
      final old = await (select(
        transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      await _applyTxEffect(old, reverse: true);
      // The caller always hands over the complete intended receipt, same as
      // note/payee — a changed or removed one leaves the old file orphaned
      // unless it's cleaned up here.
      if (old.imagePath != null && old.imagePath != imagePath) {
        await _deleteReceiptFile(old.imagePath);
      }

      await (update(transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          type: Value(type),
          amount: Value(amount),
          accountId: Value(accountId),
          toAccountId: Value(toAccountId),
          categoryId: Value(categoryId),
          personId: Value(personId),
          date: Value(date),
          note: Value(note),
          imagePath: Value(imagePath),
          payee: Value(payee),
          updatedAt: Value(DateTime.now()),
          // Editing and saving *is* the confirmation — whatever amount is
          // typed here is now the real one, estimate or not.
          needsAmountReview: const Value(false),
        ),
      );

      final fresh = await (select(
        transactions,
      )..where((t) => t.id.equals(id))).getSingle();
      await _applyTxEffect(fresh, reverse: false);
    });
  }

  /// Renames every expense that named [from] to [to] instead. If [to] already
  /// names another payee, this merges the two — they simply share a name.
  Future<void> renamePayee({required String from, required String to}) {
    final trimmed = to.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Payee name cannot be empty.');
    }
    return (update(transactions)..where((t) => t.payee.equals(from))).write(
      TransactionsCompanion(payee: Value(trimmed)),
    );
  }

  // ── Tags ──────────────────────────────────────────────────────────────────

  Stream<List<TagRow>> watchTags() => (select(
    tags,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<int> addTag({required String name, required int colorValue}) => into(
    tags,
  ).insert(TagsCompanion.insert(name: name, colorValue: colorValue));

  Future<void> updateTag({
    required int id,
    required String name,
    required int colorValue,
  }) => (update(tags)..where((t) => t.id.equals(id))).write(
    TagsCompanion(name: Value(name), colorValue: Value(colorValue)),
  );

  /// A tag is never "in use" the way an account or category is — dropping it
  /// just untags whatever carried it, nothing about those transactions
  /// changes. So, unlike categories/accounts/persons, this is a hard delete
  /// with no archive step.
  Future<void> deleteTag(int id) => transaction(() async {
    await (delete(transactionTags)..where((t) => t.tagId.equals(id))).go();
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  });

  /// Every tag link, across every transaction — composed with [watchTags] by
  /// the provider layer to build a `transactionId -> tags` map without a
  /// query per row.
  Stream<List<TransactionTagRow>> watchAllTransactionTags() =>
      select(transactionTags).watch();

  Future<List<int>> tagIdsForTransaction(int transactionId) async {
    final rows = await (select(
      transactionTags,
    )..where((t) => t.transactionId.equals(transactionId))).get();
    return rows.map((r) => r.tagId).toList();
  }

  /// Replaces every tag on [transactionId] with exactly [tagIds] — the whole
  /// set is rewritten each save rather than diffed, since the picker always
  /// hands over the complete selection.
  Future<void> setTransactionTags(int transactionId, Set<int> tagIds) {
    return transaction(() async {
      await (delete(
        transactionTags,
      )..where((t) => t.transactionId.equals(transactionId))).go();
      for (final tagId in tagIds) {
        await into(transactionTags).insert(
          TransactionTagsCompanion.insert(
            transactionId: transactionId,
            tagId: tagId,
          ),
        );
      }
    });
  }

  // ── Tag groups ───────────────────────────────────────────────────────────
  //
  // A shortcut for [TagPickerSheet]: pick one group and every tag in it gets
  // selected at once, instead of hunting each one down individually every
  // time the same combination is used (GitHub #92). A group is never itself
  // written to a transaction — only the [Tags] it names are.

  Stream<List<TagGroupRow>> watchTagGroups() => (select(
    tagGroups,
  )..orderBy([(g) => OrderingTerm(expression: g.name)])).watch();

  Future<int> addTagGroup({required String name, required int colorValue}) =>
      into(tagGroups).insert(
        TagGroupsCompanion.insert(name: name, colorValue: colorValue),
      );

  Future<void> updateTagGroup({
    required int id,
    required String name,
    required int colorValue,
  }) => (update(tagGroups)..where((g) => g.id.equals(id))).write(
    TagGroupsCompanion(name: Value(name), colorValue: Value(colorValue)),
  );

  /// Same hard-delete shape as [deleteTag]: a group is only ever a picker
  /// shortcut, so dropping it touches no transaction — just its own tag list.
  Future<void> deleteTagGroup(int id) => transaction(() async {
    await (delete(tagGroupTags)..where((t) => t.groupId.equals(id))).go();
    await (delete(tagGroups)..where((g) => g.id.equals(id))).go();
  });

  /// Every group's tag link, across every group — composed with
  /// [watchTagGroups] by the provider layer, same shape as
  /// [watchAllTransactionTags].
  Stream<List<TagGroupTagRow>> watchAllTagGroupTags() =>
      select(tagGroupTags).watch();

  Future<List<int>> tagIdsForGroup(int groupId) async {
    final rows = await (select(
      tagGroupTags,
    )..where((t) => t.groupId.equals(groupId))).get();
    return rows.map((r) => r.tagId).toList();
  }

  /// Replaces every tag in [groupId] with exactly [tagIds] — same
  /// whole-set-rewrite shape as [setTransactionTags].
  Future<void> setTagGroupTags(int groupId, Set<int> tagIds) {
    return transaction(() async {
      await (delete(
        tagGroupTags,
      )..where((t) => t.groupId.equals(groupId))).go();
      for (final tagId in tagIds) {
        await into(tagGroupTags).insert(
          TagGroupTagsCompanion.insert(groupId: groupId, tagId: tagId),
        );
      }
    });
  }

  // ── Savings goals ────────────────────────────────────────────────────────
  //
  // A goal is a real [AccountType.goal] account — see [GoalDetails]. Archive
  // and delete reuse [archiveAccount] / [deleteAccount]; funding or drawing
  // one down is an ordinary transfer via [addTransaction], not a method here.

  Stream<List<GoalDetailRow>> watchGoalDetails() => select(goalDetails).watch();

  Stream<GoalDetailRow?> watchGoalDetail(int accountId) => (select(
    goalDetails,
  )..where((g) => g.accountId.equals(accountId))).watchSingleOrNull();

  /// Creates the goal account and its target/deadline row together, always
  /// starting at zero. The "turn an existing account into a goal" flow funds
  /// it afterward with a real [addTransaction] transfer — this never
  /// fabricates a starting balance.
  Future<int> addGoal({
    required String name,
    required Money targetAmount,
    DateTime? targetDate,
    required int colorValue,
    required String iconKey,
    int? categoryId,
    String? notes,
  }) {
    if (!targetAmount.isPositive) {
      throw ArgumentError('Target amount must be greater than zero.');
    }
    return transaction(() async {
      final accountId = await into(accounts).insert(
        AccountsCompanion.insert(
          name: name,
          type: AccountType.goal,
          colorValue: colorValue,
          iconKey: iconKey,
          openingBalance: const Money.zero(),
          currentBalance: const Money.zero(),
        ),
      );
      await into(goalDetails).insert(
        GoalDetailsCompanion.insert(
          accountId: Value(accountId),
          targetAmount: targetAmount,
          targetDate: Value(targetDate),
          categoryId: Value(categoryId),
          notes: Value(notes),
        ),
      );
      return accountId;
    });
  }

  /// Never touches the account's balance — only a transfer does that.
  Future<void> updateGoal({
    required int accountId,
    required String name,
    required Money targetAmount,
    DateTime? targetDate,
    required int colorValue,
    required String iconKey,
    int? categoryId,
    String? notes,
  }) {
    if (!targetAmount.isPositive) {
      throw ArgumentError('Target amount must be greater than zero.');
    }
    return transaction(() async {
      await (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(
          name: Value(name),
          colorValue: Value(colorValue),
          iconKey: Value(iconKey),
        ),
      );
      await (update(
        goalDetails,
      )..where((g) => g.accountId.equals(accountId))).write(
        GoalDetailsCompanion(
          targetAmount: Value(targetAmount),
          targetDate: Value(targetDate),
          categoryId: Value(categoryId),
          notes: Value(notes),
        ),
      );
    });
  }

  // ── Loans ─────────────────────────────────────────────────────────────────

  Stream<List<LoanDetailRow>> watchLoanDetails() => select(loanDetails).watch();

  Future<LoanDetailRow?> getLoanDetail(int accountId) => (select(
    loanDetails,
  )..where((l) => l.accountId.equals(accountId))).getSingleOrNull();

  Future<int> addLoan({
    required String name,
    required Money principal,
    required int colorValue,
    required String iconKey,
    int? categoryId,
    Money? emiAmount,
  }) {
    if (!principal.isPositive) {
      throw ArgumentError('Principal must be greater than zero.');
    }
    final negative = Money.fromPaise(-principal.paise);
    return transaction(() async {
      final accountId = await into(accounts).insert(
        AccountsCompanion.insert(
          name: name,
          type: AccountType.loan,
          colorValue: colorValue,
          iconKey: iconKey,
          openingBalance: negative,
          currentBalance: negative,
        ),
      );
      await into(loanDetails).insert(
        LoanDetailsCompanion.insert(
          accountId: Value(accountId),
          categoryId: Value(categoryId),
          emiAmount: Value(emiAmount),
        ),
      );
      return accountId;
    });
  }

  Future<void> updateLoan({
    required int accountId,
    required String name,
    required int colorValue,
    required String iconKey,
    int? categoryId,
    Money? emiAmount,
  }) {
    return transaction(() async {
      await (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(
          name: Value(name),
          colorValue: Value(colorValue),
          iconKey: Value(iconKey),
        ),
      );
      await (update(
        loanDetails,
      )..where((l) => l.accountId.equals(accountId))).write(
        LoanDetailsCompanion(
          categoryId: Value(categoryId),
          emiAmount: Value(emiAmount),
        ),
      );
    });
  }

  // ── Credit card statements (GitHub #91) ─────────────────────────────────

  Future<CreditCardDetailRow?> getCreditCardDetails(int accountId) =>
      (select(
        creditCardDetails,
      )..where((c) => c.accountId.equals(accountId))).getSingleOrNull();

  Stream<CreditCardDetailRow?> watchCreditCardDetails(int accountId) =>
      (select(
        creditCardDetails,
      )..where((c) => c.accountId.equals(accountId))).watchSingleOrNull();

  /// Every credit card currently tracking a statement cycle — what
  /// [NotificationService.syncCreditCardReminders] schedules a due-date
  /// notification for on every app open/resume.
  Future<List<CreditCardDetailRow>> allCreditCardDetails() =>
      select(creditCardDetails).get();

  /// Turns statement/due-date tracking on (or updates it) for a credit card
  /// account. [accountId] must already be a [CardKind.credit] account —
  /// this never creates the account itself, unlike [addLoan].
  Future<void> upsertCreditCardDetails({
    required int accountId,
    required int statementDay,
    required int dueDay,
    int notifyDaysBefore = 3,
  }) async {
    if (statementDay < 1 || statementDay > 31 || dueDay < 1 || dueDay > 31) {
      throw ArgumentError('Pick a day between 1 and 31.');
    }
    final account = await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account == null ||
        account.type != AccountType.card ||
        account.cardKind != CardKind.credit) {
      throw ArgumentError('Only a credit card can track a statement cycle.');
    }
    await into(creditCardDetails).insertOnConflictUpdate(
      CreditCardDetailsCompanion.insert(
        accountId: Value(accountId),
        statementDay: statementDay,
        dueDay: dueDay,
        notifyDaysBefore: Value(notifyDaysBefore),
      ),
    );
  }

  /// Turns tracking back off — the card itself is untouched, only the
  /// cycle it was reporting against.
  Future<void> deleteCreditCardDetails(int accountId) =>
      (delete(
        creditCardDetails,
      )..where((c) => c.accountId.equals(accountId))).go();

  /// The last real day of [year]/[month] if [day] overshoots it (e.g. the
  /// 31st in a 30-day month) — the same snapping [_nextOccurrence] applies
  /// to a monthly [RecurringRules] rule.
  static DateTime _snappedDayInMonth(int year, int month, int day) {
    var y = year;
    var m = month;
    while (m > 12) {
      m -= 12;
      y++;
    }
    while (m < 1) {
      m += 12;
      y--;
    }
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day > lastDay ? lastDay : day);
  }

  /// The current open statement period as of [today] — from the day after
  /// the last close through the upcoming (or just-passed-today) close.
  static ({DateTime start, DateTime end}) creditCardStatementPeriod({
    required DateTime today,
    required int statementDay,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    var end = _snappedDayInMonth(day.year, day.month, statementDay);
    if (end.isBefore(day)) {
      end = _snappedDayInMonth(day.year, day.month + 1, statementDay);
    }
    final start = _snappedDayInMonth(
      end.year,
      end.month - 1,
      statementDay,
    ).add(const Duration(days: 1));
    return (start: start, end: end);
  }

  /// The next date payment is due, as of [today]. Whether the due date
  /// lands in the same month as a statement close or the month after is
  /// derived by comparing the two days-of-month, not stored: if [dueDay]
  /// comes after [statementDay] within a month, the bill is due that same
  /// month; otherwise it rolls into the next one (e.g. close on the 28th,
  /// due on the 20th means the 20th *after* that close, not before it).
  static DateTime creditCardNextDueDate({
    required DateTime today,
    required int statementDay,
    required int dueDay,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    // Two cycles back is always enough headroom to find the first due date
    // on or after `day`, whatever statementDay/dueDay turn out to be.
    var closeYear = day.year;
    var closeMonth = day.month - 2;
    while (true) {
      final close = _snappedDayInMonth(closeYear, closeMonth, statementDay);
      final dueMonthOffset = dueDay > statementDay ? 0 : 1;
      final due = _snappedDayInMonth(
        close.year,
        close.month + dueMonthOffset,
        dueDay,
      );
      if (!due.isBefore(day)) return due;
      closeMonth++;
    }
  }

  /// One-time correction for a goal whose "saved so far" figure is wrong,
  /// not a general balance editor — [updateGoal] above still holds for
  /// everything else ("only a transfer" touches a goal's balance).
  ///
  /// The v20→v21 migration (`_createGoalAccountFromLegacy`) seeded a
  /// migrated goal's `openingBalance` from its old linked account's whole
  /// balance, with no transaction to explain how it got there — for anyone
  /// who hadn't actually saved that much, the goal opened "already funded"
  /// with no way to fix it in-app (see GitHub #44). This lets the user set
  /// the correct starting figure directly, then rebuilds `currentBalance`
  /// from it the same way any other ledger change does.
  Future<void> correctGoalOpeningBalance({
    required int accountId,
    required Money openingBalance,
  }) {
    if (openingBalance.isNegative) {
      throw ArgumentError('Starting amount cannot be negative.');
    }
    return transaction(() async {
      final account = await (select(
        accounts,
      )..where((a) => a.id.equals(accountId))).getSingleOrNull();
      if (account == null || account.type != AccountType.goal) {
        throw ArgumentError('This account is not a goal.');
      }
      await (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(openingBalance: Value(openingBalance)),
      );
      await recalculateBalances();
    });
  }

  // ── Shopping lists ───────────────────────────────────────────────────────

  Stream<List<ShoppingListRow>> watchShoppingLists() => (select(
    shoppingLists,
  )..orderBy([(l) => OrderingTerm(expression: l.createdAt)])).watch();

  Future<int> addShoppingList({
    required String name,
    required int colorValue,
  }) => into(
    shoppingLists,
  ).insert(ShoppingListsCompanion.insert(name: name, colorValue: colorValue));

  Future<void> updateShoppingList({
    required int id,
    required String name,
    required int colorValue,
  }) => (update(shoppingLists)..where((l) => l.id.equals(id))).write(
    ShoppingListsCompanion(name: Value(name), colorValue: Value(colorValue)),
  );

  /// Deletes the list and everything on it. A shopping list has no ledger
  /// meaning to preserve the way a category or account does, so unlike
  /// those, this is a hard delete straight through.
  Future<void> deleteShoppingList(int id) => transaction(() async {
    await (delete(shoppingItems)..where((i) => i.listId.equals(id))).go();
    await (delete(shoppingLists)..where((l) => l.id.equals(id))).go();
  });

  // ── Shopping list items ──────────────────────────────────────────────────

  Stream<List<ShoppingItemRow>> watchShoppingItems(int listId) =>
      (select(shoppingItems)
            ..where((i) => i.listId.equals(listId))
            ..orderBy([
              (i) => OrderingTerm(expression: i.isChecked),
              (i) => OrderingTerm(
                expression: i.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  /// Every item across every list, for the lists overview's item counts —
  /// grouping happens client-side rather than with N separate queries.
  Stream<List<ShoppingItemRow>> watchAllShoppingItems() =>
      select(shoppingItems).watch();

  Future<int> addShoppingItem({
    required int listId,
    required String name,
    Money? estimatedAmount,
  }) => into(shoppingItems).insert(
    ShoppingItemsCompanion.insert(
      listId: Value(listId),
      name: name,
      estimatedAmount: Value(estimatedAmount),
    ),
  );

  Future<void> updateShoppingItem({
    required int id,
    required String name,
    Money? estimatedAmount,
  }) => (update(shoppingItems)..where((i) => i.id.equals(id))).write(
    ShoppingItemsCompanion(
      name: Value(name),
      estimatedAmount: Value(estimatedAmount),
    ),
  );

  Future<void> setShoppingItemChecked(int id, bool checked) =>
      (update(shoppingItems)..where((i) => i.id.equals(id))).write(
        ShoppingItemsCompanion(isChecked: Value(checked)),
      );

  Future<void> deleteShoppingItem(int id) =>
      (delete(shoppingItems)..where((i) => i.id.equals(id))).go();

  /// Clears every checked-off item on one list — the usual "done, empty the
  /// list" action once a shopping trip is over.
  Future<void> clearCheckedShoppingItems(int listId) => (delete(
    shoppingItems,
  )..where((i) => i.listId.equals(listId) & i.isChecked.equals(true))).go();

  // ── Persons ───────────────────────────────────────────────────────────────

  /// `theyOwe` = you handed money over (account goes **down**, they owe you more).
  /// `iOwe`    = you received money (account goes **up**, you owe them more).
  ///
  /// When [accountId] is given the money really moved, so a real ledger row is
  /// created (`personOut` / `personIn`). That row moves the balance and shows up
  /// in Transactions and in the account's history — money is never seen to
  /// vanish. It still never counts as income or expense: lending is not
  /// spending, and being repaid is not earning.
  ///
  /// [categoryId] is the one deliberate exception — "Mark as repaid" (see
  /// [Settings.countRepaymentsAsIncome]). Only valid on an `iOwe` entry that
  /// moves real money: the linked row posts as ordinary [TxType.income] under
  /// that category instead of [TxType.personIn], so the repayment counts in
  /// every income total the normal way. Every other entry keeps `categoryId`
  /// null, exactly as before.
  ///
  /// With no [accountId] the entry only records who owes whom, and no balance
  /// changes.
  Future<int> addPersonEntry({
    required int personId,
    required PersonDirection direction,
    required Money amount,
    required DateTime date,
    DateTime? dueDate,
    int? accountId,
    String? note,
    int? categoryId,
  }) {
    if (!amount.isPositive) {
      throw ArgumentError('Amount must be positive.');
    }
    if (categoryId != null) {
      if (direction != PersonDirection.iOwe) {
        throw ArgumentError('Only a repayment can be counted as income.');
      }
      if (accountId == null) {
        throw ArgumentError('A repayment counted as income must move money.');
      }
    }
    return transaction(() async {
      int? txId;
      if (accountId != null) {
        final person = await (select(
          persons,
        )..where((p) => p.id.equals(personId))).getSingleOrNull();
        final asRepaymentIncome =
            categoryId != null && direction == PersonDirection.iOwe;
        txId = await addTransaction(
          // theyOwe -> you gave money away. iOwe -> money came to you, either
          // as a fresh loan or (marked) a repayment counted as income.
          type: asRepaymentIncome
              ? TxType.income
              : direction == PersonDirection.theyOwe
              ? TxType.personOut
              : TxType.personIn,
          amount: amount,
          accountId: accountId,
          categoryId: asRepaymentIncome ? categoryId : null,
          personId: personId,
          date: date,
          note:
              note ??
              (direction == PersonDirection.theyOwe
                  ? 'Gave to ${person?.name ?? 'person'}'
                  : 'Received from ${person?.name ?? 'person'}'),
        );
      }

      return into(personEntries).insert(
        PersonEntriesCompanion.insert(
          personId: personId,
          direction: direction,
          amount: amount,
          date: date,
          dueDate: Value(dueDate),
          accountId: Value(accountId),
          transactionId: Value(txId),
          note: Value(note),
          categoryId: Value(categoryId),
        ),
      );
    });
  }

  Future<void> deletePersonEntry(int id) {
    return transaction(() async {
      final row = await (select(
        personEntries,
      )..where((e) => e.id.equals(id))).getSingle();
      // Drop the entry first: it references the transaction we are about to
      // delete, and the foreign key would reject the delete.
      await (delete(personEntries)..where((e) => e.id.equals(id))).go();
      // Deleting the ledger row reverses the money.
      if (row.transactionId != null) {
        await deleteTransaction(row.transactionId!);
      }
    });
  }

  /// Edits an existing entry in place, keeping its id and history position.
  ///
  /// Whatever ledger row it was linked to is always rebuilt from scratch
  /// rather than patched — the direction, account and repayment flag can all
  /// change between calls, which can also change the linked row's *type*
  /// (`personOut` ↔ `personIn` ↔ `income`), so patching in place would need
  /// to duplicate every rule [addPersonEntry] already encodes. Same
  /// validation as [addPersonEntry].
  Future<void> updatePersonEntry({
    required int id,
    required PersonDirection direction,
    required Money amount,
    required DateTime date,
    DateTime? dueDate,
    int? accountId,
    String? note,
    int? categoryId,
  }) {
    if (!amount.isPositive) {
      throw ArgumentError('Amount must be positive.');
    }
    if (categoryId != null) {
      if (direction != PersonDirection.iOwe) {
        throw ArgumentError('Only a repayment can be counted as income.');
      }
      if (accountId == null) {
        throw ArgumentError('A repayment counted as income must move money.');
      }
    }
    return transaction(() async {
      final existing = await (select(
        personEntries,
      )..where((e) => e.id.equals(id))).getSingle();

      // Detach before deleting: deleteTransaction refuses to delete a
      // transaction a person entry still points to (see deleteTransaction).
      if (existing.transactionId != null) {
        final oldTxId = existing.transactionId!;
        await (update(personEntries)..where((e) => e.id.equals(id))).write(
          const PersonEntriesCompanion(transactionId: Value(null)),
        );
        await deleteTransaction(oldTxId);
      }

      int? txId;
      if (accountId != null) {
        final person = await (select(
          persons,
        )..where((p) => p.id.equals(existing.personId))).getSingleOrNull();
        final asRepaymentIncome =
            categoryId != null && direction == PersonDirection.iOwe;
        txId = await addTransaction(
          type: asRepaymentIncome
              ? TxType.income
              : direction == PersonDirection.theyOwe
              ? TxType.personOut
              : TxType.personIn,
          amount: amount,
          accountId: accountId,
          categoryId: asRepaymentIncome ? categoryId : null,
          personId: existing.personId,
          date: date,
          note:
              note ??
              (direction == PersonDirection.theyOwe
                  ? 'Gave to ${person?.name ?? 'person'}'
                  : 'Received from ${person?.name ?? 'person'}'),
        );
      }

      await (update(personEntries)..where((e) => e.id.equals(id))).write(
        PersonEntriesCompanion(
          direction: Value(direction),
          amount: Value(amount),
          date: Value(date),
          dueDate: Value(dueDate),
          accountId: Value(accountId),
          transactionId: Value(txId),
          note: Value(note),
          categoryId: Value(categoryId),
        ),
      );
    });
  }

  /// `+` they owe you, `-` you owe them.
  Stream<Money> watchPersonBalance(int personId) {
    return (select(
      personEntries,
    )..where((e) => e.personId.equals(personId))).watch().map(_netOf);
  }

  Stream<Map<int, Money>> watchAllPersonBalances() {
    return select(personEntries).watch().map((rows) {
      final byPerson = <int, List<PersonEntryRow>>{};
      for (final r in rows) {
        byPerson.putIfAbsent(r.personId, () => []).add(r);
      }
      return byPerson.map((k, v) => MapEntry(k, _netOf(v)));
    });
  }

  static Money _netOf(List<PersonEntryRow> rows) => rows.fold(
    const Money.zero(),
    (sum, e) => e.direction == PersonDirection.theyOwe
        ? sum + e.amount
        : sum - e.amount,
  );

  // ── Repair ────────────────────────────────────────────────────────────────

  /// The ledger is the source of truth; `currentBalance` is only a cache.
  /// Rebuild every balance from scratch. Safe to run any time.
  ///
  /// Only `transactions` is read. Person movements create a `personOut` /
  /// `personIn` row, so counting `person_entries` here as well would
  /// double-count every loan.
  Future<void> recalculateBalances() {
    return transaction(() async {
      final accs = await select(accounts).get();
      final targetOf = {for (final a in accs) a.id: a.linkedAccountId ?? a.id};

      final running = <int, Money>{
        for (final a in accs)
          if (a.linkedAccountId == null) a.id: a.openingBalance,
      };

      void bump(int accountId, Money delta) {
        final t = targetOf[accountId]!;
        running[t] = (running[t] ?? const Money.zero()) + delta;
      }

      for (final t in await select(transactions).get()) {
        switch (t.type) {
          case TxType.income:
          case TxType.personIn:
            bump(t.accountId, t.amount);
          case TxType.expense:
          case TxType.personOut:
            bump(t.accountId, -t.amount);
          case TxType.transfer:
            bump(t.accountId, -t.amount);
            bump(t.toAccountId!, t.amount);
        }
      }

      for (final a in accs) {
        final value = a.linkedAccountId == null
            ? (running[a.id] ?? const Money.zero())
            : const Money.zero(); // instruments hold nothing
        await (update(accounts)..where((x) => x.id.equals(a.id))).write(
          AccountsCompanion(currentBalance: Value(value)),
        );
      }
    });
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Stream<List<AccountRow>> watchAccounts() =>
      (select(accounts)
            ..where((a) => a.isArchived.equals(false))
            ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
          .watch();

  /// Accounts that actually hold money. Debit cards / UPI excluded.
  Stream<List<AccountRow>> watchBalanceHoldingAccounts() =>
      (select(accounts)
            ..where(
              (a) => a.isArchived.equals(false) & a.linkedAccountId.isNull(),
            )
            ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
          .watch();

  /// Total money = Cash + Bank + Credit Card. Instruments never double-count.
  /// An account with [Accounts.includeInNetWorth] off — opted out from
  /// Settings > Customize Dashboard — contributes nothing here, though it
  /// still shows its own balance everywhere else in the app.
  Stream<Money> watchNetWorth() => watchBalanceHoldingAccounts().map(
    (rows) => rows
        .where((a) => a.includeInNetWorth)
        .fold(const Money.zero(), (sum, a) => sum + a.currentBalance),
  );

  /// Flips whether [id]'s balance counts toward [watchNetWorth] — the toggle
  /// behind Settings > Customize Dashboard.
  Future<void> setAccountIncludeInNetWorth(int id, bool value) =>
      (update(accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(includeInNetWorth: Value(value)),
      );

  Stream<List<CategoryRow>> watchCategories(CategoryKind kind) =>
      (select(categories)
            ..where(
              (c) => c.kind.equalsValue(kind) & c.isArchived.equals(false),
            )
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();

  Stream<List<TransactionRow>> watchTransactions({int? limit}) {
    final q = select(transactions)
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]);
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Stream<List<TransactionRow>> watchTransactionsBetween(
    DateTime start,
    DateTime end,
  ) =>
      (select(transactions)
            ..where((t) => t.date.isBetweenValues(start, end))
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
            ]))
          .watch();

  /// Income and expense only. Transfers are excluded **by definition** — they
  /// move your own money between your own accounts.
  Stream<({Money income, Money expense})> watchMonthTotals(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    return watchTransactionsBetween(start, end).map((rows) {
      var income = const Money.zero();
      var expense = const Money.zero();
      for (final t in rows) {
        if (t.type == TxType.income) income += t.amount;
        if (t.type == TxType.expense) expense += t.amount;
      }
      return (income: income, expense: expense);
    });
  }

  /// One-shot income/expense/category-breakdown snapshot for an arbitrary
  /// range — the data behind the Income & Expense Report PDF. [watchMonthTotals]
  /// stays calendar-month-only because Dashboard needs exactly that; a report
  /// covers whatever period the Stats screen is showing (month or year).
  Future<({Money income, Money expense, Map<int, Money> expenseByCategory})>
  reportTotals(DateTime start, DateTime end) async {
    final rows = await watchTransactionsBetween(start, end).first;
    var income = const Money.zero();
    var expense = const Money.zero();
    for (final t in rows) {
      if (t.type == TxType.income) income += t.amount;
      if (t.type == TxType.expense) expense += t.amount;
    }
    final expenseByCategory = await watchSpendByCategory(start, end).first;
    return (
      income: income,
      expense: expense,
      expenseByCategory: expenseByCategory,
    );
  }

  /// Spend per category for a period. Transfers excluded; expenses only.
  /// A split expense (see [TransactionSplits]) has no [Transactions.categoryId]
  /// of its own — its amount is attributed per split line instead, so it
  /// still counts correctly toward budgets and every category breakdown.
  Stream<Map<int, Money>> watchSpendByCategory(DateTime start, DateTime end) =>
      watchTransactionsBetween(start, end).asyncMap((rows) async {
        final out = <int, Money>{};
        for (final t in rows) {
          if (t.type == TxType.expense) {
            if (t.categoryId != null) {
              out[t.categoryId!] =
                  (out[t.categoryId!] ?? const Money.zero()) + t.amount;
              continue;
            }
            for (final s in await splitsForTransaction(t.id)) {
              out[s.categoryId] =
                  (out[s.categoryId] ?? const Money.zero()) + s.amount;
            }
            continue;
          }
          // A categorized transfer into/from a goal or loan counts toward
          // that category's budget progress (GitHub #75).
          if (t.type == TxType.transfer && t.categoryId != null) {
            out[t.categoryId!] =
                (out[t.categoryId!] ?? const Money.zero()) + t.amount;
          }
        }
        return out;
      });

  // ── Split expenses ───────────────────────────────────────────────────────

  Future<List<TransactionSplitRow>> splitsForTransaction(int transactionId) =>
      (select(
        transactionSplits,
      )..where((s) => s.transactionId.equals(transactionId))).get();

  Stream<List<TransactionSplitRow>> watchAllTransactionSplits() =>
      select(transactionSplits).watch();

  /// Replaces every split line on [transactionId] with exactly [splits] — the
  /// whole set is rewritten each save, same as [setTransactionTags]. An empty
  /// list just clears the splits (the transaction reverts to a single,
  /// ordinary category chosen elsewhere). A non-empty list must sum to the
  /// transaction's own [Transactions.amount], or the split would silently
  /// invent or lose money in every category breakdown that reads it.
  Future<void> setTransactionSplits(
    int transactionId,
    List<({int categoryId, Money amount})> splits,
  ) {
    return transaction(() async {
      if (splits.isNotEmpty) {
        final tx = await (select(
          transactions,
        )..where((t) => t.id.equals(transactionId))).getSingle();
        final sum = splits.fold(const Money.zero(), (s, e) => s + e.amount);
        if (sum != tx.amount) {
          throw ArgumentError(
            'Split amounts (${sum.paise}) must add up to the transaction '
            'total (${tx.amount.paise}).',
          );
        }
      }
      await (delete(
        transactionSplits,
      )..where((s) => s.transactionId.equals(transactionId))).go();
      for (final s in splits) {
        await into(transactionSplits).insert(
          TransactionSplitsCompanion.insert(
            transactionId: transactionId,
            categoryId: s.categoryId,
            amount: s.amount,
          ),
        );
      }
    });
  }

  Stream<SettingRow> watchSettings() => select(settings).watchSingle();

  Future<void> markOnboarded() async {
    await update(
      settings,
    ).write(const SettingsCompanion(onboarded: Value(true)));
  }

  // ── Accounts CRUD ─────────────────────────────────────────────────────────

  Future<int> addAccount({
    required String name,
    required AccountType type,
    CardKind? cardKind,
    int? linkedAccountId,
    String? bankName,
    String? last4,
    required int colorValue,
    required String iconKey,
    required Money openingBalance,
  }) {
    if (type == AccountType.card && cardKind == null) {
      throw ArgumentError('A card must be credit or debit.');
    }
    if (cardKind == CardKind.debit && linkedAccountId == null) {
      throw ArgumentError(
        'A debit card must be linked to the bank account it draws from.',
      );
    }
    // An instrument (debit card) holds no balance of its own.
    final opening = linkedAccountId == null
        ? openingBalance
        : const Money.zero();

    return into(accounts).insert(
      AccountsCompanion.insert(
        name: name,
        type: type,
        cardKind: Value(cardKind),
        linkedAccountId: Value(linkedAccountId),
        bankName: Value(bankName),
        last4: Value(last4),
        colorValue: colorValue,
        iconKey: iconKey,
        openingBalance: opening,
        currentBalance: opening,
      ),
    );
  }

  /// GitHub #88 — the only account field ever offered for editing after
  /// creation. Trims and rejects blank, same rule [addAccount] leaves to the
  /// UI layer today; enforced here too since this is the only path that
  /// bypasses the add sheet's own validation.
  Future<void> renameAccount(int id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Give the account a name.');
    }
    return (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(name: Value(trimmed)),
    );
  }

  Future<void> archiveAccount(int id) =>
      (update(accounts)..where((a) => a.id.equals(id))).write(
        const AccountsCompanion(isArchived: Value(true)),
      );

  Future<void> unarchiveAccount(int id) =>
      (update(accounts)..where((a) => a.id.equals(id))).write(
        const AccountsCompanion(isArchived: Value(false)),
      );

  Stream<List<AccountRow>> watchArchivedAccounts() =>
      (select(accounts)
            ..where((a) => a.isArchived.equals(true))
            ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
          .watch();

  /// [accountId] as either side of the move — matches every FK reference a
  /// transaction can hold to an account.
  Future<int> countTransactionsForAccount(int accountId) async {
    final rows =
        await (select(transactions)..where(
              (t) =>
                  t.accountId.equals(accountId) |
                  t.toAccountId.equals(accountId),
            ))
            .get();
    return rows.length;
  }

  /// Archive, never delete, an account anything still points at: deleting one
  /// with transaction history would orphan every row that named it, exactly
  /// like [archiveCategory] above. Removal only ever succeeds on an account
  /// nothing has touched yet — no transaction, no debit card drawing from it,
  /// no reminder or merchant rule naming it.
  Future<void> deleteAccount(int id) async {
    final linkedCard = await (select(
      accounts,
    )..where((a) => a.linkedAccountId.equals(id))).getSingleOrNull();
    if (linkedCard != null) {
      throw ArgumentError(
        '"${linkedCard.name}" draws from this account. Remove that card '
        'first.',
      );
    }
    if (await countTransactionsForAccount(id) > 0) {
      throw ArgumentError(
        'This account has transaction history — archive it instead.',
      );
    }
    final reminder = await (select(
      reminders,
    )..where((r) => r.accountId.equals(id))).getSingleOrNull();
    if (reminder != null) {
      throw ArgumentError('A reminder still points at this account.');
    }
    final rule = await (select(
      merchantRules,
    )..where((r) => r.accountId.equals(id))).getSingleOrNull();
    if (rule != null) {
      throw ArgumentError('A merchant rule still points at this account.');
    }
    final recurring = await (select(
      recurringRules,
    )..where((r) => r.accountId.equals(id))).getSingleOrNull();
    if (recurring != null) {
      throw ArgumentError(
        '"${recurring.name}" auto-posts from this account. Delete that rule '
        'first.',
      );
    }
    final settingsRow = await getSettings();
    if (settingsRow.quickAddAccountId == id) {
      throw ArgumentError(
        'The quick-add notification still posts to this account. Change '
        'that in Settings first.',
      );
    }
    await transaction(() async {
      // A goal account's own target/deadline row has no reason to outlive
      // it — nothing else ever references GoalDetails. Same for a credit
      // card's statement-tracking row.
      await (delete(goalDetails)..where((g) => g.accountId.equals(id))).go();
      await (delete(
        creditCardDetails,
      )..where((c) => c.accountId.equals(id))).go();
      await (delete(accounts)..where((a) => a.id.equals(id))).go();
    });
  }

  // ── Persons CRUD ──────────────────────────────────────────────────────────

  Future<int> addPerson(String name, {String? contact, String? note}) =>
      into(persons).insert(
        PersonsCompanion.insert(
          name: name,
          contact: Value(contact),
          note: Value(note),
        ),
      );

  /// Full edit — unlike [addPersonEntry]'s pattern, every field the edit
  /// sheet shows is passed every time, so `null` here means "clear this
  /// field", not "leave unchanged".
  Future<void> updatePerson({
    required int id,
    required String name,
    String? contact,
    String? note,
    String? upiId,
    String? phone,
    String? paypal,
    String? venmo,
    String? cashapp,
    String? revolut,
  }) => (update(persons)..where((p) => p.id.equals(id))).write(
    PersonsCompanion(
      name: Value(name),
      contact: Value(contact),
      note: Value(note),
      upiId: Value(upiId),
      phone: Value(phone),
      paypal: Value(paypal),
      venmo: Value(venmo),
      cashapp: Value(cashapp),
      revolut: Value(revolut),
    ),
  );

  Stream<List<PersonRow>> watchPersons() =>
      (select(persons)..where((p) => p.isArchived.equals(false))).watch();

  Stream<List<PersonRow>> watchArchivedPersons() =>
      (select(persons)..where((p) => p.isArchived.equals(true))).watch();

  Future<void> archivePerson(int id) =>
      (update(persons)..where((p) => p.id.equals(id))).write(
        const PersonsCompanion(isArchived: Value(true)),
      );

  Future<void> unarchivePerson(int id) =>
      (update(persons)..where((p) => p.id.equals(id))).write(
        const PersonsCompanion(isArchived: Value(false)),
      );

  Future<int> countEntriesForPerson(int personId) async {
    final rows = await (select(
      personEntries,
    )..where((e) => e.personId.equals(personId))).get();
    return rows.length;
  }

  /// Mirrors [deleteAccount]: only ever succeeds on a person nothing has
  /// touched yet — no lend/borrow history, no reminder naming them. Anything
  /// used must be archived instead.
  Future<void> deletePerson(int id) async {
    if (await countEntriesForPerson(id) > 0) {
      throw ArgumentError(
        'This person has lend/borrow history — archive them instead.',
      );
    }
    final reminder = await (select(
      reminders,
    )..where((r) => r.personId.equals(id))).getSingleOrNull();
    if (reminder != null) {
      throw ArgumentError('A reminder still points at this person.');
    }
    await (delete(persons)..where((p) => p.id.equals(id))).go();
  }

  Stream<List<PersonEntryRow>> watchAllPersonEntries() =>
      select(personEntries).watch();

  Stream<List<PersonEntryRow>> watchPersonEntries(int personId) =>
      (select(personEntries)
            ..where((e) => e.personId.equals(personId))
            ..orderBy([
              (e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc),
            ]))
          .watch();

  // ── Budgets ───────────────────────────────────────────────────────────────

  /// A subcategory's budget can never exceed its parent's — the parent is
  /// meant to cap the whole subtree, so a child budgeted higher than that cap
  /// would make the cap meaningless. Checked both ways: setting a child's
  /// budget above its (budgeted) parent's is rejected, and so is shrinking a
  /// parent's budget below a child's that's already set.
  Future<void> upsertBudget({
    required int categoryId,
    required Money amount,
    BudgetPeriod period = BudgetPeriod.monthly,
    int alertThresholdPct = 80,
    String? note,
  }) async {
    final category = await categoryById(categoryId);
    if (category == null) {
      throw ArgumentError('That category no longer exists.');
    }
    if (category.parentId != null) {
      final parentBudget =
          await (select(budgets)
                ..where((b) => b.categoryId.equals(category.parentId!)))
              .getSingleOrNull();
      if (parentBudget != null && amount > parentBudget.amount) {
        throw ArgumentError(
          "A subcategory's budget can't be more than its parent's "
          '(${MoneyFormat.symbol(parentBudget.amount)}).',
        );
      }
    } else {
      final children =
          await (select(categories)..where(
                (c) =>
                    c.parentId.equals(categoryId) & c.isArchived.equals(false),
              ))
              .get();
      if (children.isNotEmpty) {
        final childIds = children.map((c) => c.id).toSet();
        final childBudgets = await (select(
          budgets,
        )..where((b) => b.categoryId.isIn(childIds))).get();
        for (final childBudget in childBudgets) {
          if (childBudget.amount > amount) {
            final childCategory = children.firstWhere(
              (c) => c.id == childBudget.categoryId,
            );
            throw ArgumentError(
              '${childCategory.name} is already budgeted '
              '${MoneyFormat.symbol(childBudget.amount)} — lower that first, '
              'or set this to at least that much.',
            );
          }
        }
      }
    }

    final trimmedNote = note?.trim();
    final entry = BudgetsCompanion.insert(
      categoryId: categoryId,
      amount: amount,
      period: period,
      startDate: DateTime(DateTime.now().year, DateTime.now().month),
      alertThresholdPct: Value(alertThresholdPct),
      note: Value(
        trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
      ),
    );
    // `insertOnConflictUpdate` targets only the primary key (`id`) by
    // default, never `categoryId` — but `id` is always fresh here (the
    // companion never carries one), so it never conflicts and the *real*
    // unique constraint (one budget per category) would raise a raw
    // uncaught SqliteException on every edit of an existing budget instead
    // of updating it. Naming the conflict target explicitly is what makes
    // this an actual upsert.
    await into(budgets).insert(
      entry,
      onConflict: DoUpdate((_) => entry, target: [budgets.categoryId]),
    );
  }

  Future<void> deleteBudget(int categoryId) =>
      (delete(budgets)..where((b) => b.categoryId.equals(categoryId))).go();

  Stream<List<BudgetRow>> watchBudgets() =>
      (select(budgets)..where((b) => b.isActive.equals(true))).watch();

  // ── Envelope Mode ─────────────────────────────────────────────────────────
  //
  // `category_balance` and `ready_to_assign` are never stored — always
  // derived fresh from `allocations` + `transactions`, the same way
  // `current_balance` is derived from the ledger rather than trusted as a
  // cache (see `recalculateBalances`). Storing either as a column is exactly
  // how the 1.3.0 parent/child budget double-count bug happened; the
  // provider-layer composition in `data/providers.dart`
  // (`categoryBalanceProvider` / `readyToAssignProvider`) is what actually
  // computes them, from streams this section exposes.

  /// Per-account, not global — every other account keeps working exactly as
  /// it does today. Switching this off never deletes [Allocations] rows (see
  /// [Allocations] doc); they simply stop being read while it's off, and
  /// reappear if it's switched back on.
  Future<void> setEnvelopeMode(int accountId, bool enabled) =>
      (update(accounts)..where((a) => a.id.equals(accountId))).write(
        AccountsCompanion(envelopeMode: Value(enabled)),
      );

  /// Every allocation, across every account — the provider layer sums these
  /// per (account, category) rather than this querying once per pair.
  Stream<List<AllocationRow>> watchAllAllocations() =>
      select(allocations).watch();

  Stream<List<AllocationRow>> watchAllocationsForAccount(int accountId) =>
      (select(allocations)
            ..where((a) => a.accountId.equals(accountId))
            ..orderBy([
              (a) => OrderingTerm(expression: a.date, mode: OrderingMode.desc),
            ]))
          .watch();

  /// Records one movement of money into or out of [categoryId]'s envelope —
  /// see [Allocations.amount] for the sign convention. This is both "assign"
  /// (a positive amount) and "unassign" (a negative one); there is no
  /// separate method for each, the same way [addTransaction] covers
  /// income/expense/transfer with one method rather than three.
  ///
  /// Throws [ArgumentError] if [accountId] isn't in Envelope Mode, or if
  /// [amount] is zero.
  Future<int> addAllocation({
    required int accountId,
    required int categoryId,
    required Money amount,
    DateTime? date,
    String? note,
  }) async {
    if (amount.isZero) {
      throw ArgumentError('Amount must not be zero.');
    }
    final account = await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account == null || !account.envelopeMode) {
      throw ArgumentError('Envelope Mode is off for this account.');
    }
    return into(allocations).insert(
      AllocationsCompanion.insert(
        accountId: accountId,
        categoryId: categoryId,
        amount: amount,
        date: date ?? DateTime.now(),
        note: Value(note),
      ),
    );
  }

  /// Moves money from one category's envelope straight to another within the
  /// same account — a negative row on [fromCategoryId], a positive row on
  /// [toCategoryId], written together so a crash between the two can never
  /// leave the move half-done.
  Future<void> moveAllocation({
    required int accountId,
    required int fromCategoryId,
    required int toCategoryId,
    required Money amount,
    DateTime? date,
    String? note,
  }) async {
    if (!amount.isPositive) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    if (fromCategoryId == toCategoryId) {
      throw ArgumentError('Pick two different categories.');
    }
    final when = date ?? DateTime.now();
    await transaction(() async {
      await addAllocation(
        accountId: accountId,
        categoryId: fromCategoryId,
        amount: -amount,
        date: when,
        note: note,
      );
      await addAllocation(
        accountId: accountId,
        categoryId: toCategoryId,
        amount: amount,
        date: when,
        note: note,
      );
    });
  }

  Future<void> deleteAllocation(int id) =>
      (delete(allocations)..where((a) => a.id.equals(id))).go();

  // ── Groups CRUD ───────────────────────────────────────────────────────────

  Future<int> addGroup(String name, {String? note}) => into(groups).insert(
    GroupsCompanion.insert(name: name, note: Value(note)),
  );

  Future<void> updateGroup({
    required int id,
    required String name,
    String? note,
  }) => (update(groups)..where((g) => g.id.equals(id))).write(
    GroupsCompanion(name: Value(name), note: Value(note)),
  );

  Stream<List<GroupRow>> watchGroups() =>
      (select(groups)..where((g) => g.isArchived.equals(false))).watch();

  Stream<List<GroupRow>> watchArchivedGroups() =>
      (select(groups)..where((g) => g.isArchived.equals(true))).watch();

  Future<void> archiveGroup(int id) =>
      (update(groups)..where((g) => g.id.equals(id))).write(
        const GroupsCompanion(isArchived: Value(true)),
      );

  Future<void> unarchiveGroup(int id) =>
      (update(groups)..where((g) => g.id.equals(id))).write(
        const GroupsCompanion(isArchived: Value(false)),
      );

  Future<int> countExpensesForGroup(int groupId) async {
    final rows = await (select(
      groupExpenses,
    )..where((e) => e.groupId.equals(groupId))).get();
    return rows.length;
  }

  /// Mirrors [deletePerson]: only ever succeeds on a group with no expense
  /// history. Anything used must be archived instead.
  Future<void> deleteGroup(int id) async {
    if (await countExpensesForGroup(id) > 0) {
      throw ArgumentError('This group has expense history — archive it instead.');
    }
    await transaction(() async {
      await (delete(groupMembers)..where((m) => m.groupId.equals(id))).go();
      await (delete(groups)..where((g) => g.id.equals(id))).go();
    });
  }

  /// Replace-all semantics — simplest correct approach at this table's
  /// scale. `GroupMembers.id`/`addedAt` are not stable across an edit;
  /// nothing references `GroupMembers.id` as a foreign key elsewhere, so
  /// that's fine.
  Future<void> setGroupMembers(int groupId, Set<int> personIds) =>
      transaction(() async {
        await (delete(
          groupMembers,
        )..where((m) => m.groupId.equals(groupId))).go();
        for (final personId in personIds) {
          await into(groupMembers).insert(
            GroupMembersCompanion.insert(groupId: groupId, personId: personId),
          );
        }
      });

  /// Ordered by [GroupMembers.id] (insertion order) — the same order
  /// [addGroupExpense] distributes a rounding remainder in, so which member
  /// gets an extra paisa is stable, not arbitrary.
  Stream<List<PersonRow>> watchGroupMembers(int groupId) {
    final query = select(groupMembers).join([
      innerJoin(persons, persons.id.equalsExp(groupMembers.personId)),
    ])
      ..where(groupMembers.groupId.equals(groupId))
      ..orderBy([OrderingTerm.asc(groupMembers.id)]);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(persons)).toList(),
    );
  }

  Stream<List<GroupExpenseRow>> watchGroupExpenses(int groupId) =>
      (select(groupExpenses)
            ..where((e) => e.groupId.equals(groupId))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .watch();

  /// Splits [amount] across [participantIds] (`null` = "me") per
  /// [splitMethod] via [computeGroupShares], then enacts every share
  /// through the *existing* [addTransaction]/[addPersonEntry] — this method
  /// invents no new money-movement logic, only orchestrates.
  ///
  /// This app's ledger can only represent a debt between "me" and one named
  /// Person, never between two other contacts — see the class doc on
  /// [GroupExpenses]. So: when [payerId] is null (I paid), my own share (if
  /// I'm a participant) becomes a real expense transaction, and every other
  /// participant's share becomes a normal "they owe me" entry. When
  /// [payerId] is set, only *my* share (if I have one) is trackable, as a
  /// normal "I owe them" entry — the payer's own share and any third
  /// party's share are recorded in [GroupExpenseShares] with both link
  /// columns null: real, computed amounts, deliberately never turned into
  /// a debt.
  Future<int> addGroupExpense({
    required int groupId,
    required Money amount,
    required GroupSplitMethod splitMethod,
    required DateTime date,
    String? note,
    int? payerId,
    int? accountId,
    int? categoryId,
    required Set<int?> participantIds,
    Map<int?, int>? percentBasisPoints,
    Map<int?, Money>? manualAmounts,
  }) async {
    if (!amount.isPositive) {
      throw ArgumentError('Amount must be greater than zero.');
    }

    final orderedParticipants = participantIds.toList();
    final shares = computeGroupShares(
      amount: amount,
      splitMethod: splitMethod,
      participantIds: orderedParticipants,
      percentBasisPoints: percentBasisPoints,
      manualAmounts: manualAmounts,
    );

    return transaction(() async {
      final expenseId = await into(groupExpenses).insert(
        GroupExpensesCompanion.insert(
          groupId: groupId,
          amount: amount,
          splitMethod: splitMethod,
          date: date,
          note: Value(note),
          payerId: Value(payerId),
          accountId: Value(payerId == null ? accountId : null),
          categoryId: Value(payerId == null ? categoryId : null),
        ),
      );

      for (final memberId in orderedParticipants) {
        final share = shares[memberId]!;
        int? personEntryId;
        int? txId;

        if (payerId == null) {
          if (memberId == null) {
            // My own share: real spending, not a debt.
            if (accountId == null || categoryId == null) {
              throw ArgumentError(
                'Pick an account and category for your own share.',
              );
            }
            txId = await addTransaction(
              type: TxType.expense,
              amount: share,
              accountId: accountId,
              categoryId: categoryId,
              date: date,
              note: note ?? 'Group expense',
            );
          } else {
            // Every other participant owes me.
            personEntryId = await addPersonEntry(
              personId: memberId,
              direction: PersonDirection.theyOwe,
              amount: share,
              date: date,
              accountId: accountId,
              note: note,
            );
          }
        } else if (memberId == null) {
          // My share: I owe the payer, tracking only — no money moved yet.
          personEntryId = await addPersonEntry(
            personId: payerId,
            direction: PersonDirection.iOwe,
            amount: share,
            date: date,
            note: note,
          );
        }
        // else: memberId == payerId (their own share, their money, not
        // tracked) or memberId is a third party (owed to the payer, not to
        // me — unrepresentable). Either way personEntryId/txId stay null;
        // the share row below is still inserted so every participant has
        // exactly one row.

        await into(groupExpenseShares).insert(
          GroupExpenseSharesCompanion.insert(
            groupExpenseId: expenseId,
            personId: Value(memberId),
            amount: share,
            percentBasisPoints: Value(percentBasisPoints?[memberId]),
            personEntryId: Value(personEntryId),
            transactionId: Value(txId),
          ),
        );
      }
      return expenseId;
    });
  }

  /// Reverses every share of a group expense, then removes the expense
  /// itself. Checks each linked row still exists before deleting it — a
  /// share's [PersonEntries]/[Transactions] row may already have been
  /// deleted directly (e.g. from that person's own ledger page), and a
  /// stale foreign key must not abort cleanup of the rest.
  Future<void> deleteGroupExpense(int id) => transaction(() async {
    final shareRows = await (select(
      groupExpenseShares,
    )..where((s) => s.groupExpenseId.equals(id))).get();

    // The share rows themselves foreign-key onto PersonEntries/Transactions
    // — they must go first, or deleting a still-referenced entry/transaction
    // below would fail its own foreign key check.
    await (delete(
      groupExpenseShares,
    )..where((s) => s.groupExpenseId.equals(id))).go();

    for (final share in shareRows) {
      if (share.personEntryId != null) {
        final exists = await (select(
          personEntries,
        )..where((e) => e.id.equals(share.personEntryId!))).getSingleOrNull();
        if (exists != null) await deletePersonEntry(share.personEntryId!);
      } else if (share.transactionId != null) {
        final exists = await (select(
          transactions,
        )..where((t) => t.id.equals(share.transactionId!))).getSingleOrNull();
        if (exists != null) await deleteTransaction(share.transactionId!);
      }
    }

    await (delete(groupExpenses)..where((e) => e.id.equals(id))).go();
  });

  // ── Reminders ─────────────────────────────────────────────────────────────

  Future<int> addReminder({
    required String title,
    Money? amount,
    required ReminderDirection direction,
    required DateTime dueDate,
    int? accountId,
    int? categoryId,
    int? personId,
    ReminderRepeat repeat = ReminderRepeat.none,
    int notifyDaysBefore = 0,
  }) => into(reminders).insert(
    RemindersCompanion.insert(
      title: title,
      amount: Value(amount),
      direction: direction,
      dueDate: dueDate,
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      personId: Value(personId),
      repeat: Value(repeat),
      notifyDaysBefore: Value(notifyDaysBefore),
    ),
  );

  Stream<List<ReminderRow>> watchReminders() => (select(
    reminders,
  )..orderBy([(r) => OrderingTerm(expression: r.dueDate)])).watch();

  Future<void> setReminderStatus(
    int id,
    ReminderStatus status, {
    int? transactionId,
  }) => (update(reminders)..where((r) => r.id.equals(id))).write(
    RemindersCompanion(
      status: Value(status),
      transactionId: Value(transactionId),
    ),
  );

  Future<void> deleteReminder(int id) =>
      (delete(reminders)..where((r) => r.id.equals(id))).go();

  // ── Recurring rules (Auto) ────────────────────────────────────────────────

  void _validateRecurringRule({
    required Money amount,
    required CategoryKind kind,
    required CategoryRow? category,
    required RecurringFrequency frequency,
    int? dayOfMonth,
    Money? promoAmount,
    int? promoOccurrences,
  }) {
    if (!amount.isPositive) {
      throw ArgumentError('Amount must be positive.');
    }
    if (category != null && category.kind != kind) {
      throw ArgumentError(
        'That category is ${category.kind == CategoryKind.income ? 'an income' : 'an expense'} '
        'category — pick one that matches.',
      );
    }
    if (frequency == RecurringFrequency.monthly) {
      if (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31) {
        throw ArgumentError('A monthly rule needs a day of the month (1–31).');
      }
    } else if (dayOfMonth != null) {
      throw ArgumentError('Only a monthly rule pins a day of the month.');
    }
    if (promoAmount != null) {
      // Zero is valid — a free trial period, not just a discount (GitHub
      // #87: e.g. a service free for the first N months).
      if (promoAmount.isNegative) {
        throw ArgumentError('Promo amount cannot be negative.');
      }
      if (promoOccurrences == null || promoOccurrences < 1) {
        throw ArgumentError('A promotion needs at least 1 occurrence.');
      }
    } else if (promoOccurrences != null) {
      throw ArgumentError('A promotion needs a promo amount.');
    }
  }

  /// A G&L rule's [RecurringRules.toAccountId] must be a real goal/loan
  /// account, its [RecurringRules.accountId] must be a real non-goal/loan
  /// (spendable) account, and the two must differ — the same shape
  /// [_validateTx] enforces for a one-off transfer, checked up front here so
  /// a bad rule can never be saved.
  Future<void> _validateGoalOrLoanTarget({
    required int accountId,
    required int toAccountId,
  }) async {
    if (accountId == toAccountId) {
      throw ArgumentError('The source and destination must be different.');
    }
    final to = await (select(
      accounts,
    )..where((a) => a.id.equals(toAccountId))).getSingleOrNull();
    if (to == null ||
        (to.type != AccountType.goal && to.type != AccountType.loan)) {
      throw ArgumentError('Choose a goal or loan to fund.');
    }
    final from = await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (from == null ||
        from.type == AccountType.goal ||
        from.type == AccountType.loan) {
      throw ArgumentError('Choose a spendable account to fund it from.');
    }
  }

  Future<int> addRecurringRule({
    required String name,
    required CategoryKind kind,
    required Money amount,
    required int accountId,
    int? categoryId,
    int? toAccountId,
    String? payee,
    String? note,
    required RecurringFrequency frequency,
    required DateTime startsOn,
    int notifyDaysBefore = 3,
    bool isEstimate = false,
    Money? promoAmount,
    int? promoOccurrences,
    Set<int> tagIds = const {},
  }) async {
    CategoryRow? category;
    if (toAccountId != null) {
      await _validateGoalOrLoanTarget(
        accountId: accountId,
        toAccountId: toAccountId,
      );
    } else {
      if (categoryId == null) {
        throw ArgumentError('Choose a category.');
      }
      category = await categoryById(categoryId);
      if (category == null) {
        throw ArgumentError('That category no longer exists.');
      }
    }
    final dayOfMonth = frequency == RecurringFrequency.monthly
        ? startsOn.day
        : null;
    _validateRecurringRule(
      amount: amount,
      kind: kind,
      category: category,
      frequency: frequency,
      dayOfMonth: dayOfMonth,
      promoAmount: promoAmount,
      promoOccurrences: promoOccurrences,
    );

    return transaction(() async {
      final id = await into(recurringRules).insert(
        RecurringRulesCompanion.insert(
          name: name,
          kind: kind,
          amount: amount,
          accountId: accountId,
          categoryId: Value(categoryId),
          toAccountId: Value(toAccountId),
          payee: Value(payee),
          note: Value(note),
          frequency: frequency,
          dayOfMonth: Value(dayOfMonth),
          nextDueDate: DateTime(startsOn.year, startsOn.month, startsOn.day),
          notifyDaysBefore: Value(notifyDaysBefore),
          isEstimate: Value(isEstimate),
          promoAmount: Value(promoAmount),
          promoOccurrencesLeft: Value(promoOccurrences),
        ),
      );
      await setRecurringRuleTags(id, tagIds);
      return id;
    });
  }

  Future<void> updateRecurringRule({
    required int id,
    required String name,
    required CategoryKind kind,
    required Money amount,
    required int accountId,
    int? categoryId,
    int? toAccountId,
    String? payee,
    String? note,
    required RecurringFrequency frequency,
    required DateTime nextDueDate,
    int notifyDaysBefore = 3,
    bool isEstimate = false,
    Money? promoAmount,
    int? promoOccurrences,
    Set<int> tagIds = const {},
  }) async {
    CategoryRow? category;
    if (toAccountId != null) {
      await _validateGoalOrLoanTarget(
        accountId: accountId,
        toAccountId: toAccountId,
      );
    } else {
      if (categoryId == null) {
        throw ArgumentError('Choose a category.');
      }
      category = await categoryById(categoryId);
      if (category == null) {
        throw ArgumentError('That category no longer exists.');
      }
    }
    final dayOfMonth = frequency == RecurringFrequency.monthly
        ? nextDueDate.day
        : null;
    _validateRecurringRule(
      amount: amount,
      kind: kind,
      category: category,
      frequency: frequency,
      dayOfMonth: dayOfMonth,
      promoAmount: promoAmount,
      promoOccurrences: promoOccurrences,
    );

    await setRecurringRuleTags(id, tagIds);
    await (update(recurringRules)..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(
        name: Value(name),
        kind: Value(kind),
        amount: Value(amount),
        accountId: Value(accountId),
        categoryId: Value(categoryId),
        toAccountId: Value(toAccountId),
        payee: Value(payee),
        note: Value(note),
        frequency: Value(frequency),
        dayOfMonth: Value(dayOfMonth),
        nextDueDate: Value(
          DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day),
        ),
        notifyDaysBefore: Value(notifyDaysBefore),
        isEstimate: Value(isEstimate),
        promoAmount: Value(promoAmount),
        promoOccurrencesLeft: Value(promoOccurrences),
      ),
    );
  }

  Future<void> setRecurringActive(int id, bool active) =>
      (update(recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(isActive: Value(active)),
      );

  /// The rule itself is gone, but a transaction it already posted is a real
  /// ledger row and stays — it just loses the breadcrumb back to its rule,
  /// the same way deleting a transaction clears a reminder's back-reference.
  Future<void> deleteRecurringRule(int id) => transaction(() async {
    await (update(transactions)..where((t) => t.recurringRuleId.equals(id)))
        .write(const TransactionsCompanion(recurringRuleId: Value(null)));
    await (delete(recurringRuleTags)..where((t) => t.ruleId.equals(id))).go();
    await (delete(recurringRules)..where((r) => r.id.equals(id))).go();
  });

  Stream<List<RecurringRuleRow>> watchRecurringRules() => (select(
    recurringRules,
  )..orderBy([(r) => OrderingTerm(expression: r.nextDueDate)])).watch();

  /// Every rule-tag link, across every rule — same shape as
  /// [watchAllTransactionTags], for the same reason.
  Stream<List<RecurringRuleTagRow>> watchAllRecurringRuleTags() =>
      select(recurringRuleTags).watch();

  Future<List<int>> tagIdsForRecurringRule(int ruleId) async {
    final rows = await (select(
      recurringRuleTags,
    )..where((t) => t.ruleId.equals(ruleId))).get();
    return rows.map((r) => r.tagId).toList();
  }

  /// Replaces every tag [ruleId] stamps onto its posted transactions with
  /// exactly [tagIds] — same whole-set-rewrite shape as [setTransactionTags].
  /// Existing transactions the rule already posted keep whatever tags they
  /// have; only future postings pick up the change.
  Future<void> setRecurringRuleTags(int ruleId, Set<int> tagIds) {
    return transaction(() async {
      await (delete(
        recurringRuleTags,
      )..where((t) => t.ruleId.equals(ruleId))).go();
      for (final tagId in tagIds) {
        await into(recurringRuleTags).insert(
          RecurringRuleTagsCompanion.insert(ruleId: ruleId, tagId: tagId),
        );
      }
    });
  }

  /// The occurrence after [from], for a rule whose target day is
  /// [dayOfMonth] (monthly only). Short months snap to their last day, but
  /// the *next* month's occurrence still targets the original [dayOfMonth]
  /// rather than whatever day the snap landed on — so a rule for the 31st
  /// posts on Feb 28 and then still on Mar 31, never drifting to the 28th
  /// forever.
  static DateTime _nextOccurrence(
    RecurringFrequency frequency,
    DateTime from, {
    int? dayOfMonth,
  }) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return DateTime(from.year, from.month, from.day + 1);
      case RecurringFrequency.weekly:
        return DateTime(from.year, from.month, from.day + 7);
      case RecurringFrequency.biweekly:
        return DateTime(from.year, from.month, from.day + 14);
      case RecurringFrequency.monthly:
        var year = from.year;
        var month = from.month + 1;
        if (month > 12) {
          month = 1;
          year++;
        }
        final lastDayOfMonth = DateTime(year, month + 1, 0).day;
        final day = dayOfMonth! > lastDayOfMonth ? lastDayOfMonth : dayOfMonth;
        return DateTime(year, month, day);
    }
  }

  /// Posts one occurrence of [rule] dated [date] — the shared step both
  /// [runDueRecurringRules] (dated the occurrence's own due date, possibly
  /// backfilling several) and [payRecurringRuleNow] (dated today, exactly
  /// one — GitHub #86) build on.
  ///
  /// A free (₹0) promo occurrence still posts a real ₹0 transaction — a
  /// legitimate income/expense (GitHub #87), not nothing, so it stays
  /// visible, taggable and editable in the ledger like any other occurrence.
  /// Returns the promo state after this occurrence. Must run inside
  /// [transaction].
  Future<({Money? promoAmount, int? promoLeft})> _postRecurringOccurrence(
    RecurringRuleRow rule, {
    required DateTime date,
    required Money? promoAmount,
    required int? promoLeft,
    required Set<int> tagIds,
  }) async {
    final onPromo = promoAmount != null && (promoLeft ?? 0) > 0;
    final isGoalOrLoan = rule.toAccountId != null;
    final txId = await addTransaction(
      type: isGoalOrLoan
          ? TxType.transfer
          : (rule.kind == CategoryKind.expense
                ? TxType.expense
                : TxType.income),
      amount: onPromo ? promoAmount : rule.amount,
      accountId: rule.accountId,
      toAccountId: rule.toAccountId,
      categoryId: rule.categoryId,
      date: date,
      payee: isGoalOrLoan ? null : rule.payee,
      recurringRuleId: rule.id,
      needsAmountReview: rule.isEstimate,
    );
    if (tagIds.isNotEmpty) {
      await setTransactionTags(txId, tagIds);
    }
    if (onPromo) {
      promoLeft = promoLeft! - 1;
      if (promoLeft <= 0) {
        promoAmount = null;
        promoLeft = null;
      }
    }
    return (promoAmount: promoAmount, promoLeft: promoLeft);
  }

  /// Posts [ruleId]'s next occurrence right now, dated today, instead of
  /// waiting for [RecurringRuleRow.nextDueDate] to arrive — "Pay early"
  /// (GitHub #86), useful for a bill paid ahead of schedule so the balance
  /// reflects it immediately. Exactly one occurrence, never a backfill —
  /// [nextDueDate] moves to whatever follows the *rule's own* due date, not
  /// today plus its interval, so a monthly rule anchored to the 5th stays
  /// anchored to the 5th even after an early payment.
  ///
  /// [now] exists so tests can pin "today" instead of racing the wall clock
  /// — real callers never pass it.
  Future<void> payRecurringRuleNow(int ruleId, {DateTime? now}) async {
    final ruleTagIds = (await tagIdsForRecurringRule(ruleId)).toSet();
    await transaction(() async {
      final rule = await (select(
        recurringRules,
      )..where((r) => r.id.equals(ruleId))).getSingle();
      final result = await _postRecurringOccurrence(
        rule,
        date: now ?? DateTime.now(),
        promoAmount: rule.promoAmount,
        promoLeft: rule.promoOccurrencesLeft,
        tagIds: ruleTagIds,
      );
      final next = _nextOccurrence(
        rule.frequency,
        rule.nextDueDate,
        dayOfMonth: rule.dayOfMonth,
      );
      await (update(recurringRules)..where((r) => r.id.equals(ruleId))).write(
        RecurringRulesCompanion(
          nextDueDate: Value(next),
          promoAmount: Value(result.promoAmount),
          promoOccurrencesLeft: Value(result.promoLeft),
        ),
      );
    });
  }

  /// Posts every occurrence of every active rule whose [RecurringRuleRow.nextDueDate]
  /// has arrived, backfilling one occurrence at a time — each with its own
  /// correct historical date — until each rule's schedule is caught up to
  /// today. Safe to call on every app open/resume; a rule with nothing due
  /// costs one query and does nothing further.
  ///
  /// Returns how many transactions were posted, so the caller knows whether
  /// to tell the user anything happened.
  ///
  /// [now] exists so tests can pin "today" instead of racing the wall clock —
  /// real callers never pass it.
  Future<int> runDueRecurringRules({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final endOfToday = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final due =
        await (select(recurringRules)..where(
              (r) =>
                  r.isActive.equals(true) &
                  r.nextDueDate.isSmallerOrEqualValue(endOfToday),
            ))
            .get();
    if (due.isEmpty) return 0;

    var posted = 0;
    for (final rule in due) {
      try {
        final ruleTagIds = (await tagIdsForRecurringRule(rule.id)).toSet();
        await transaction(() async {
          var next = rule.nextDueDate;
          // A promo can run out mid-backfill (e.g. two missed months catch up
          // in one run, straddling the last promo occurrence) — tracked
          // locally so the switch back to [rule.amount] takes effect on the
          // very next iteration, not just on the following call.
          var promoAmount = rule.promoAmount;
          var promoLeft = rule.promoOccurrencesLeft;
          while (!next.isAfter(endOfToday)) {
            final result = await _postRecurringOccurrence(
              rule,
              date: next,
              promoAmount: promoAmount,
              promoLeft: promoLeft,
              tagIds: ruleTagIds,
            );
            promoAmount = result.promoAmount;
            promoLeft = result.promoLeft;
            posted++;
            next = _nextOccurrence(
              rule.frequency,
              next,
              dayOfMonth: rule.dayOfMonth,
            );
          }
          await (update(recurringRules)..where((r) => r.id.equals(rule.id)))
              .write(
                RecurringRulesCompanion(
                  nextDueDate: Value(next),
                  promoAmount: Value(promoAmount),
                  promoOccurrencesLeft: Value(promoLeft),
                ),
              );
        });
      } catch (_) {
        // One rule that can no longer post (its account stopped being
        // spendable, etc.) must not block every other rule due today — this
        // runs unguarded on every app open/resume.
      }
    }
    return posted;
  }

  // ── Message auto-capture ──────────────────────────────────────────────────

  /// UPI commonly fires **two** messages for one payment (bank + app). Without
  /// this window every UPI spend would be booked twice.
  static const _nearDuplicateWindow = Duration(minutes: 5);

  /// Identity of the exact same message, so re-scanning the inbox is idempotent.
  static String dedupeKeyFor(RawMessage m) {
    final minute = DateTime(
      m.receivedAt.year,
      m.receivedAt.month,
      m.receivedAt.day,
      m.receivedAt.hour,
      m.receivedAt.minute,
    );
    final body = m.body.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return '${m.sender.toUpperCase()}|${minute.toIso8601String()}|${body.hashCode}';
  }

  /// True whenever a [PersonEntries] row is the one that posted this
  /// transaction — a `personOut`/`personIn` movement always is, and so is a
  /// repayment marked to count as income (see [addPersonEntry]), even though
  /// its own [TransactionRow.type] reads as ordinary [TxType.income]. Editing
  /// either directly here would desync the person's ledger from the money.
  Future<bool> isPersonLinkedTransaction(int transactionId) async {
    final owner = await (select(
      personEntries,
    )..where((e) => e.transactionId.equals(transactionId))).getSingleOrNull();
    return owner != null;
  }

  Future<TransactionRow?> transactionById(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<TransactionRow?> watchTransaction(int id) =>
      (select(transactions)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<AccountRow?> watchAccount(int id) =>
      (select(accounts)..where((a) => a.id.equals(id))).watchSingleOrNull();

  Future<PendingTxnRow?> pendingById(int id) =>
      (select(pendingTxns)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<CategoryRow?> categoryById(int id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<AccountRow?> accountByLast4(String last4) =>
      (select(accounts)
            ..where((a) => a.last4.equals(last4) & a.isArchived.equals(false))
            ..limit(1))
          .getSingleOrNull();

  /// A second message describing the same payment.
  Future<bool> _isNearDuplicate(ParsedMessage p, DateTime at) async {
    final from = at.subtract(_nearDuplicateWindow);
    final to = at.add(_nearDuplicateWindow);

    final rows =
        await (select(pendingTxns)..where(
              (t) =>
                  t.receivedAt.isBetweenValues(from, to) &
                  t.status.equalsValue(PendingStatus.dismissed).not(),
            ))
            .get();

    for (final r in rows) {
      if (r.parsedAmount != p.amount) continue;
      if (r.parsedDirection != p.direction) continue;

      // A matching reference is conclusive.
      if (p.reference != null && r.parsedRef == p.reference) return true;

      // Same amount, same direction, same account, minutes apart.
      if (r.parsedAccountHint == p.accountHint) return true;

      // One payment, two senders: the bank names the account, the UPI wallet
      // (PhonePe/GPay) usually names neither an account nor the same reference.
      // Treat an amount+direction match where either side lacks an account as a
      // suspected duplicate. It is only *flagged*, never dropped — the card
      // still appears in the inbox with a "Not a duplicate" action, and a
      // flagged card can never be auto-approved.
      if (p.accountHint == null || r.parsedAccountHint == null) return true;
    }
    return false;
  }

  /// Store a parsed message as a review card. Returns the row id, or `null`
  /// when the exact message was already ingested (idempotent re-scan).
  ///
  /// [sourceImagePath] is set only for a shared screenshot (see
  /// `MessageSourceKind.screenshot`) — the caller has already copied it into
  /// permanent app storage, so a `null` return here (exact duplicate) means
  /// the caller is responsible for deleting that now-orphaned copy.
  Future<int?> ingestMessage(
    RawMessage msg,
    ParsedMessage parsed, {
    String? sourceImagePath,
  }) {
    return transaction(() async {
      final key = dedupeKeyFor(msg);
      final seen = await (select(
        pendingTxns,
      )..where((t) => t.dedupeKey.equals(key))).getSingleOrNull();
      if (seen != null) return null;

      final matched = parsed.accountHint == null
          ? null
          : await accountByLast4(parsed.accountHint!);

      final duplicate = await _isNearDuplicate(parsed, msg.receivedAt);

      return into(pendingTxns).insert(
        PendingTxnsCompanion.insert(
          source: msg.source,
          rawBody: msg.body,
          sender: msg.sender,
          receivedAt: msg.receivedAt,
          dedupeKey: key,
          parsedAmount: Value(parsed.amount),
          parsedDirection: Value(parsed.direction),
          parsedAccountHint: Value(parsed.accountHint),
          parsedMerchant: Value(parsed.merchant),
          parsedRef: Value(parsed.reference),
          parsedBalance: Value(parsed.availableBalance),
          confidence: Value(parsed.confidence),
          matchedAccountId: Value(matched?.id),
          sourceImagePath: Value(sourceImagePath),
          status: Value(
            duplicate ? PendingStatus.duplicate : PendingStatus.pending,
          ),
        ),
      );
    });
  }

  static TxType txTypeFor(TxDirection d) =>
      d == TxDirection.debit ? TxType.expense : TxType.income;

  /// Post a reviewed card to the ledger.
  ///
  /// [autoFilled] marks it as machine-decided so the card still shows the user
  /// what happened, with an Undo.
  ///
  /// [payee] lets the review sheet post the user's *edited* payee instead of
  /// whatever was auto-extracted — falls back to [PendingTxnRow.parsedMerchant]
  /// when not given (the auto-fill path never overrides it). [learnMerchantRule]
  /// still keys off whichever string actually gets posted, so a corrected OCR
  /// misread is what gets learned, not the misread itself.
  Future<int> approvePending(
    int pendingId, {
    required int categoryId,
    required int accountId,
    bool autoFilled = false,
    int? appliedRuleId,
    bool learnMerchantRule = false,
    String? payee,
  }) {
    return transaction(() async {
      final p = await (select(
        pendingTxns,
      )..where((t) => t.id.equals(pendingId))).getSingle();
      if (p.parsedAmount == null || p.parsedDirection == null) {
        throw ArgumentError('This message has no amount or direction to post.');
      }
      if (p.createdTransactionId != null) {
        throw ArgumentError('This card was already posted.');
      }

      final resolvedPayee = payee ?? p.parsedMerchant;

      final txId = await addTransaction(
        type: txTypeFor(p.parsedDirection!),
        amount: p.parsedAmount!,
        accountId: accountId,
        categoryId: categoryId,
        date: p.receivedAt,
        note: p.parsedMerchant,
        payee: resolvedPayee,
        imagePath: p.sourceImagePath,
      );

      await (update(pendingTxns)..where((t) => t.id.equals(pendingId))).write(
        PendingTxnsCompanion(
          status: Value(
            autoFilled ? PendingStatus.autoFilled : PendingStatus.approved,
          ),
          matchedAccountId: Value(accountId),
          createdTransactionId: Value(txId),
          appliedRuleId: Value(appliedRuleId),
        ),
      );

      if (learnMerchantRule && resolvedPayee != null) {
        await upsertMerchantRule(
          pattern: resolvedPayee,
          categoryId: categoryId,
          accountId: accountId,
        );
      }
      return txId;
    });
  }

  /// Undo must **reverse the posted transaction**, not merely hide the card.
  Future<void> undoPending(int pendingId) {
    return transaction(() async {
      final p = await (select(
        pendingTxns,
      )..where((t) => t.id.equals(pendingId))).getSingle();
      final txId = p.createdTransactionId;

      // `deleteTransaction` clears this reference itself, but drop it here too
      // so the card is back to `pending` even if there was nothing to delete.
      await (update(pendingTxns)..where((t) => t.id.equals(pendingId))).write(
        const PendingTxnsCompanion(
          status: Value(PendingStatus.pending),
          createdTransactionId: Value(null),
          appliedRuleId: Value(null),
        ),
      );

      if (txId != null) await deleteTransaction(txId);
    });
  }

  Future<void> setPendingStatus(int id, PendingStatus status) =>
      (update(pendingTxns)..where((t) => t.id.equals(id))).write(
        PendingTxnsCompanion(status: Value(status)),
      );

  /// Cards the user should see: awaiting a category, or auto-filled for info.
  Stream<List<PendingTxnRow>> watchPendingCards() =>
      (select(pendingTxns)
            ..where(
              (t) =>
                  t.status.equalsValue(PendingStatus.pending) |
                  t.status.equalsValue(PendingStatus.autoFilled),
            )
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.receivedAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Stream<List<PendingTxnRow>> watchAllPendingTxns() =>
      (select(pendingTxns)..orderBy([
            (t) =>
                OrderingTerm(expression: t.receivedAt, mode: OrderingMode.desc),
          ]))
          .watch();

  // ── OCR corrections ────────────────────────────────────────────────────

  Future<int> addOcrCorrection({
    required String appLabel,
    String? country,
    required String rawOcrText,
    required bool wasCorrect,
    String? extractedAmount,
    String? extractedDirection,
    String? extractedPayee,
    String? extractedReference,
    String? correctedAmount,
    String? correctedDirection,
    String? correctedPayee,
    String? correctedReference,
  }) => into(ocrCorrections).insert(
    OcrCorrectionsCompanion.insert(
      appLabel: appLabel,
      country: Value(country),
      rawOcrText: rawOcrText,
      wasCorrect: wasCorrect,
      extractedAmount: Value(extractedAmount),
      extractedDirection: Value(extractedDirection),
      extractedPayee: Value(extractedPayee),
      extractedReference: Value(extractedReference),
      correctedAmount: Value(correctedAmount),
      correctedDirection: Value(correctedDirection),
      correctedPayee: Value(correctedPayee),
      correctedReference: Value(correctedReference),
    ),
  );

  Stream<List<OcrCorrectionRow>> watchPendingOcrCorrections() =>
      (select(ocrCorrections)
            ..where((t) => t.sentAt.isNull())
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Stream<List<OcrCorrectionRow>> watchSentOcrCorrections() =>
      (select(ocrCorrections)
            ..where((t) => t.sentAt.isNotNull())
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<void> markOcrCorrectionsSent(List<int> ids) async {
    if (ids.isEmpty) return;
    await (update(ocrCorrections)..where((t) => t.id.isIn(ids))).write(
      OcrCorrectionsCompanion(sentAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteOcrCorrection(int id) =>
      (delete(ocrCorrections)..where((t) => t.id.equals(id))).go();

  // ── Merchant rules (what Auto-Approve is allowed to fire from) ────────────

  static String _normalizeMerchant(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// The ONLY rule lookup Auto-Approve is allowed to use. **Exact match only.**
  ///
  /// A substring fallback used to live here and it was dangerous: a learned rule
  /// for `OLA` matched `GOLA SNACKS`, so an unrelated purchase was silently
  /// auto-booked under Transport. Auto-Approve promises it never guesses — a
  /// near-miss must fall through to the review inbox, which costs one tap.
  Future<MerchantRuleRow?> findMerchantRule(String? merchant) async {
    if (merchant == null || merchant.trim().isEmpty) return null;
    final needle = _normalizeMerchant(merchant);
    final rows = await select(merchantRules).get();
    for (final r in rows) {
      if (_normalizeMerchant(r.matchPattern) == needle) return r;
    }
    return null;
  }

  /// Fuzzy lookup for *suggesting* a category to the user. Never auto-posts.
  /// Requires a reasonably long pattern so short names can't swallow long ones.
  Future<MerchantRuleRow?> suggestMerchantRule(String? merchant) async {
    final exact = await findMerchantRule(merchant);
    if (exact != null) return exact;
    if (merchant == null) return null;

    final needle = _normalizeMerchant(merchant);
    if (needle.length < 4) return null;

    for (final r in await select(merchantRules).get()) {
      final p = _normalizeMerchant(r.matchPattern);
      if (p.length < 4) continue;
      // Word-boundary containment only: "swiggy" matches "swiggy instamart",
      // but "ola" can never match "gola snacks".
      final boundary = RegExp('\\b${RegExp.escape(p)}\\b');
      if (boundary.hasMatch(needle)) return r;
    }
    return null;
  }

  Future<void> upsertMerchantRule({
    required String pattern,
    required int categoryId,
    int? accountId,
  }) async {
    final existing = await (select(
      merchantRules,
    )..where((r) => r.matchPattern.equals(pattern))).getSingleOrNull();

    if (existing == null) {
      await into(merchantRules).insert(
        MerchantRulesCompanion.insert(
          matchPattern: pattern,
          categoryId: categoryId,
          accountId: Value(accountId),
          hitCount: const Value(1),
        ),
      );
    } else {
      await (update(
        merchantRules,
      )..where((r) => r.id.equals(existing.id))).write(
        MerchantRulesCompanion(
          categoryId: Value(categoryId),
          accountId: Value(accountId),
          hitCount: Value(existing.hitCount + 1),
        ),
      );
    }
  }

  Stream<List<MerchantRuleRow>> watchMerchantRules() =>
      select(merchantRules).watch();

  Future<void> deleteMerchantRule(int id) =>
      (delete(merchantRules)..where((r) => r.id.equals(id))).go();

  Stream<List<SenderRuleRow>> watchSenderRules() => select(senderRules).watch();

  Future<void> setSenderRuleEnabled(int id, bool enabled) =>
      (update(senderRules)..where((r) => r.id.equals(id))).write(
        SenderRulesCompanion(enabled: Value(enabled)),
      );

  // ── Settings for capture ─────────────────────────────────────────────────

  Future<void> setMessageCaptureEnabled(bool enabled) => update(
    settings,
  ).write(SettingsCompanion(messageCaptureEnabled: Value(enabled)));

  Future<void> setAutoApprove(bool enabled) =>
      update(settings).write(SettingsCompanion(autoApprove: Value(enabled)));

  Future<void> setNotificationsEnabled(bool enabled) => update(
    settings,
  ).write(SettingsCompanion(notificationsEnabled: Value(enabled)));

  Future<void> setNotificationQuickAddEnabled(bool enabled) => update(
    settings,
  ).write(SettingsCompanion(notificationQuickAddEnabled: Value(enabled)));

  /// Null clears back to "use the first account" — see
  /// [resolveQuickAddAccountId].
  Future<void> setQuickAddAccount(int? accountId) => update(
    settings,
  ).write(SettingsCompanion(quickAddAccountId: Value(accountId)));

  /// [Settings.quickAddAccountId] if it still names a real, non-archived,
  /// balance-holding account, else the first such account by sort order
  /// (typically Cash, since every fresh install seeds one). Null only when
  /// every account has been archived — nothing left to post to.
  Future<int?> resolveQuickAddAccountId() async {
    final chosen = (await getSettings()).quickAddAccountId;
    final candidates = await watchBalanceHoldingAccounts().first;
    if (chosen != null && candidates.any((a) => a.id == chosen)) {
      return chosen;
    }
    return candidates.isEmpty ? null : candidates.first.id;
  }

  Future<void> setLastMessageScanAt(DateTime at) =>
      update(settings).write(SettingsCompanion(lastMessageScanAt: Value(at)));

  /// [name] must be a `ThemePreset.name`. Unknown values are tolerated on read,
  /// so a bad write degrades to the default rather than bricking the app.
  Future<void> setThemeName(String name) =>
      update(settings).write(SettingsCompanion(themeName: Value(name)));

  /// An ISO 4217 code. An unknown code degrades to the default on read
  /// ([currencyForCode]), so a bad write can never brick the app.
  Future<void> setCurrencyCode(String code) =>
      update(settings).write(SettingsCompanion(currencyCode: Value(code)));

  Future<void> setShowCurrencySymbol(bool show) => update(
    settings,
  ).write(SettingsCompanion(showCurrencySymbol: Value(show)));

  Future<void> setCountRepaymentsAsIncome(bool value) => update(
    settings,
  ).write(SettingsCompanion(countRepaymentsAsIncome: Value(value)));

  Future<void> setMyUpiId(String? value) =>
      update(settings).write(SettingsCompanion(myUpiId: Value(value)));

  Future<void> setMyUpiName(String? value) =>
      update(settings).write(SettingsCompanion(myUpiName: Value(value)));

  Future<void> setMyPaypal(String? value) =>
      update(settings).write(SettingsCompanion(myPaypal: Value(value)));

  Future<void> setMyVenmo(String? value) =>
      update(settings).write(SettingsCompanion(myVenmo: Value(value)));

  Future<void> setMyCashapp(String? value) =>
      update(settings).write(SettingsCompanion(myCashapp: Value(value)));

  Future<void> setMyRevolut(String? value) =>
      update(settings).write(SettingsCompanion(myRevolut: Value(value)));

  Future<void> setUpiEnabled(bool value) =>
      update(settings).write(SettingsCompanion(upiEnabled: Value(value)));

  Future<void> setPaypalEnabled(bool value) =>
      update(settings).write(SettingsCompanion(paypalEnabled: Value(value)));

  Future<void> setVenmoEnabled(bool value) =>
      update(settings).write(SettingsCompanion(venmoEnabled: Value(value)));

  Future<void> setCashappEnabled(bool value) =>
      update(settings).write(SettingsCompanion(cashappEnabled: Value(value)));

  Future<void> setRevolutEnabled(bool value) =>
      update(settings).write(SettingsCompanion(revolutEnabled: Value(value)));

  Future<void> setLockScreenStyle(LockScreenStyle style) => update(
    settings,
  ).write(SettingsCompanion(lockScreenStyle: Value(style)));

  Future<void> setMoreScreenViewMode(MoreScreenViewMode mode) => update(
    settings,
  ).write(SettingsCompanion(moreScreenViewMode: Value(mode)));

  // ── Passcode ──────────────────────────────────────────────────────────────

  /// [pin].length is trusted as-is — the entry screen is what enforces 4-6
  /// digits (see GitHub #18).
  Future<void> setPasscode(String pin) {
    final salt = Passcode.generateSalt();
    return update(settings).write(
      SettingsCompanion(
        passcodeHash: Value(Passcode.hash(pin, salt)),
        passcodeSalt: Value(salt),
        passcodeLength: Value(pin.length),
      ),
    );
  }

  /// Clears the passcode and, since it's meaningless without one, biometric
  /// unlock along with it.
  Future<void> clearPasscode() => update(settings).write(
    const SettingsCompanion(
      passcodeHash: Value(null),
      passcodeSalt: Value(null),
      passcodeLength: Value(null),
      biometricEnabled: Value(false),
    ),
  );

  Future<bool> verifyPasscode(String pin) async {
    final row = await getSettings();
    final hash = row.passcodeHash;
    final salt = row.passcodeSalt;
    if (hash == null || salt == null) return false;
    return Passcode.verify(pin, salt, hash);
  }

  /// A no-op when no passcode is set — see the doc on [Settings.biometricEnabled].
  Future<void> setBiometricEnabled(bool value) async {
    if (value && (await getSettings()).passcodeHash == null) return;
    await update(
      settings,
    ).write(SettingsCompanion(biometricEnabled: Value(value)));
  }

  Future<void> setPreventScreenshots(bool value) => update(
    settings,
  ).write(SettingsCompanion(preventScreenshots: Value(value)));

  Future<void> setScreenshotReminderEnabled(bool value) => update(
    settings,
  ).write(SettingsCompanion(screenshotReminderEnabled: Value(value)));

  /// A no-op when no passcode is set — same guard as [setBiometricEnabled];
  /// a timeout means nothing without a lock to defer.
  Future<void> setPinTimeoutMinutes(int minutes) async {
    if ((await getSettings()).passcodeHash == null) return;
    await update(
      settings,
    ).write(SettingsCompanion(pinTimeoutMinutes: Value(minutes)));
  }

  // ── Master recovery phrase (GitHub #74) ─────────────────────────────────

  /// [words] is trusted as-is — the setup screen is what enforces the word
  /// count and that they came from [RecoveryWords.wordlist].
  Future<void> setMasterPhrase(List<String> words) {
    final salt = Passcode.generateSalt();
    return update(settings).write(
      SettingsCompanion(
        masterPhraseHash: Value(Passcode.hash(words.join(' '), salt)),
        masterPhraseSalt: Value(salt),
      ),
    );
  }

  /// Clears the phrase and resets the attempt counter — otherwise a device
  /// already past the threshold would stay locked out of a PIN with no
  /// phrase left to unlock it with.
  Future<void> clearMasterPhrase() => update(settings).write(
    const SettingsCompanion(
      masterPhraseHash: Value(null),
      masterPhraseSalt: Value(null),
      failedPasscodeAttempts: Value(0),
    ),
  );

  Future<bool> verifyMasterPhrase(List<String> words) async {
    final row = await getSettings();
    final hash = row.masterPhraseHash;
    final salt = row.masterPhraseSalt;
    if (hash == null || salt == null) return false;
    return Passcode.verify(words.join(' '), salt, hash);
  }

  /// A no-op when no master phrase is set — same guard as
  /// [setPinTimeoutMinutes]; a threshold means nothing without a phrase to
  /// fall back to.
  Future<void> setMasterPhraseAttemptThreshold(int attempts) async {
    if ((await getSettings()).masterPhraseHash == null) return;
    await update(settings).write(
      SettingsCompanion(masterPhraseAttemptThreshold: Value(attempts)),
    );
  }

  /// Increments the persisted wrong-PIN counter and returns the new count —
  /// the lock screen compares it against [Settings.masterPhraseAttemptThreshold]
  /// to decide whether to switch out of PIN entry.
  Future<int> recordFailedPasscodeAttempt() async {
    final next = (await getSettings()).failedPasscodeAttempts + 1;
    await update(
      settings,
    ).write(SettingsCompanion(failedPasscodeAttempts: Value(next)));
    return next;
  }

  Future<void> resetFailedPasscodeAttempts() => update(
    settings,
  ).write(const SettingsCompanion(failedPasscodeAttempts: Value(0)));

  Future<void> setHideAmounts(bool value) =>
      update(settings).write(SettingsCompanion(hideAmounts: Value(value)));

  Future<void> setShowCalendarDayTotals(bool value) => update(
    settings,
  ).write(SettingsCompanion(showCalendarDayTotals: Value(value)));

  // ── Font ──────────────────────────────────────────────────────────────────

  /// [percent] is clamped to the range the picker offers (80–150) so a bad
  /// caller can never blow text up or down past readable.
  Future<void> setFontScalePercent(int percent) => update(
    settings,
  ).write(SettingsCompanion(fontScalePercent: Value(percent.clamp(80, 150))));

  /// [delta] is clamped to the range the picker offers (-2–+2).
  Future<void> setFontWeightDelta(int delta) => update(
    settings,
  ).write(SettingsCompanion(fontWeightDelta: Value(delta.clamp(-2, 2))));

  /// [name] must be an `AppFontFamily.name`, or null for "match the theme".
  /// Unknown values are tolerated on read, so a bad write degrades to the
  /// default rather than bricking the app — same convention as
  /// [setThemeName].
  Future<void> setFontFamily(String? name) =>
      update(settings).write(SettingsCompanion(fontFamily: Value(name)));

  /// The 7 destinations a configurable bottom-nav slot can hold — Dashboard
  /// and More are pinned and deliberately excluded (see GitHub #70's design
  /// spec, "Non-goals").
  static const bottomNavCatalogIds = {
    'transactions',
    'persons',
    'calendar',
    'budgets',
    'accounts',
    'stats',
    'payees',
  };

  Future<void> setBottomNavSlots(String left, String right) async {
    if (!bottomNavCatalogIds.contains(left) ||
        !bottomNavCatalogIds.contains(right)) {
      throw ArgumentError('Unknown bottom-nav item.');
    }
    if (left == right) {
      throw ArgumentError('The two bottom-nav slots must be different.');
    }
    await update(
      settings,
    ).write(SettingsCompanion(bottomNavSlots: Value('$left,$right')));
  }

  Future<void> setShowBottomNavLabels(bool value) => update(
    settings,
  ).write(SettingsCompanion(showBottomNavLabels: Value(value)));

  Future<void> setHoldMenuEnabled(bool value) => update(
    settings,
  ).write(SettingsCompanion(holdMenuEnabled: Value(value)));

  Future<void> setHoldMenuSlots(List<String> ids) async {
    if (ids.length != 3 || ids.toSet().length != 3) {
      throw ArgumentError('The hold menu needs exactly 3 distinct items.');
    }
    if (ids.any((id) => !bottomNavCatalogIds.contains(id))) {
      throw ArgumentError('Unknown hold-menu item.');
    }
    await update(
      settings,
    ).write(SettingsCompanion(holdMenuSlots: Value(ids.join(','))));
  }

  /// Clamped to a sane range here, not just in the settings slider — this is
  /// the only path a stray value (a bad restore, a future scripted call)
  /// could take to reach the column.
  Future<void> setExtraBottomInset(int px) => update(settings).write(
    SettingsCompanion(extraBottomInset: Value(px.clamp(0, 40))),
  );

  // ── Expense reminder ─────────────────────────────────────────────────────

  Future<void> setExpenseReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) => update(settings).write(
    SettingsCompanion(
      expenseReminderEnabled: Value(enabled),
      expenseReminderHour: Value(hour),
      expenseReminderMinute: Value(minute),
    ),
  );

  Future<SettingRow> getSettings() => select(settings).getSingle();

  // ── Backups ───────────────────────────────────────────────────────────────

  /// Turns automatic backups on/off and sets their schedule and retention.
  ///
  /// [retentionDays] must be at least as long as the interval implied by
  /// [frequency] (and [customDays]/[customHours] when `frequency` is
  /// [AutoBackupFrequency.custom]) — otherwise cleanup could delete a backup
  /// before the next one exists to replace it, silently leaving zero backups
  /// on disk. `0` means "keep forever" and always satisfies this.
  Future<void> setAutoBackupSettings({
    required bool enabled,
    required AutoBackupFrequency frequency,
    int customDays = 0,
    int customHours = 0,
    required int retentionDays,
  }) async {
    if (frequency == AutoBackupFrequency.custom &&
        customDays <= 0 &&
        customHours <= 0) {
      throw ArgumentError('Set a custom interval of at least 1 hour.');
    }
    if (retentionDays < 0) {
      throw ArgumentError('Retention days cannot be negative.');
    }
    final interval = autoBackupInterval(
      frequency: frequency,
      customDays: customDays,
      customHours: customHours,
    );
    if (retentionDays != 0 && Duration(days: retentionDays) < interval) {
      throw ArgumentError(
        "Keep-backups-for can't be shorter than how often backups run.",
      );
    }
    await update(settings).write(
      SettingsCompanion(
        autoBackupEnabled: Value(enabled),
        autoBackupFrequency: Value(frequency),
        autoBackupCustomDays: Value(customDays),
        autoBackupCustomHours: Value(customHours),
        backupRetentionDays: Value(retentionDays),
      ),
    );
  }

  Future<void> setLastAutoBackupAt(DateTime when) =>
      update(settings).write(SettingsCompanion(lastAutoBackupAt: Value(when)));

  /// Whether an automatic backup should run right now, per the current
  /// schedule — see [isAutoBackupDue] for the actual (pure, testable) rule.
  Future<bool> checkAutoBackupDue() async {
    final s = await getSettings();
    return isAutoBackupDue(s, DateTime.now());
  }

  /// Records a backup [BackupService] just wrote (or updates it, if writing
  /// the same day's file again replaced an existing one) — an upsert on
  /// [fileName], the one thing that's actually unique here.
  ///
  /// `insertOnConflictUpdate` targets only the primary key by default, never
  /// a declared `uniqueKeys` column — the exact bug already found and fixed
  /// in `upsertBudget`. Naming the conflict target explicitly avoids it here
  /// too.
  Future<void> upsertBackupRecord({
    required String fileName,
    required String uri,
    required int sizeBytes,
    required DateTime createdAt,
  }) async {
    final entry = BackupRecordsCompanion.insert(
      fileName: fileName,
      uri: uri,
      sizeBytes: Value(sizeBytes),
      createdAt: createdAt,
    );
    await into(backupRecords).insert(
      entry,
      onConflict: DoUpdate((_) => entry, target: [backupRecords.fileName]),
    );
  }

  Future<void> deleteBackupRecordByName(String fileName) =>
      (delete(backupRecords)..where((b) => b.fileName.equals(fileName))).go();

  Future<BackupRecordRow?> backupRecordByName(String fileName) => (select(
    backupRecords,
  )..where((b) => b.fileName.equals(fileName))).getSingleOrNull();

  Stream<List<BackupRecordRow>> watchBackupRecords() =>
      (select(backupRecords)..orderBy([
            (b) =>
                OrderingTerm(expression: b.createdAt, mode: OrderingMode.desc),
          ]))
          .watch();

  /// Records older than the current retention window — what
  /// `BackupService.cleanupOldBackups` should delete next. Always empty when
  /// retention is `0` ("keep forever").
  Future<List<BackupRecordRow>> staleBackupRecords({DateTime? now}) async {
    final s = await getSettings();
    if (s.backupRetentionDays <= 0) return const [];
    final cutoff = (now ?? DateTime.now()).subtract(
      Duration(days: s.backupRetentionDays),
    );
    return (select(
      backupRecords,
    )..where((b) => b.createdAt.isSmallerThanValue(cutoff))).get();
  }

  // ── Budget alerts (fire once per period) ─────────────────────────────────

  static String periodKeyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// Returns `true` the first time this alert fires in this period, `false`
  /// afterwards. That is what stops the notification spamming every purchase.
  ///
  /// The read and the write live in one transaction. `checkBudgets` is fired,
  /// un-awaited, from a provider listener on every ledger change — two
  /// overlapping calls used to both see "no row yet" and both return `true`,
  /// buzzing the same alert twice. Drift serialises transactions on its single
  /// connection, so the second caller now observes the first caller's row.
  Future<bool> claimBudgetAlert({
    required int categoryId,
    required String periodKey,
    required AlertLevel level,
  }) {
    return transaction(() async {
      final existing =
          await (select(budgetAlerts)..where(
                (a) =>
                    a.categoryId.equals(categoryId) &
                    a.periodKey.equals(periodKey) &
                    a.level.equalsValue(level),
              ))
              .getSingleOrNull();
      if (existing != null) return false;

      // A plain insert, not insertOrIgnore: inside the transaction the unique
      // key cannot already exist, and a silent ignore would let us report a
      // claim we never made.
      await into(budgetAlerts).insert(
        BudgetAlertsCompanion.insert(
          categoryId: categoryId,
          periodKey: periodKey,
          level: level,
        ),
      );
      return true;
    });
  }

  /// Give back a claim whose notification could not be delivered, so the alert
  /// is not silenced for the rest of the period.
  Future<void> releaseBudgetAlert({
    required int categoryId,
    required String periodKey,
    required AlertLevel level,
  }) =>
      (delete(budgetAlerts)..where(
            (a) =>
                a.categoryId.equals(categoryId) &
                a.periodKey.equals(periodKey) &
                a.level.equalsValue(level),
          ))
          .go();

  // ── Categories CRUD ───────────────────────────────────────────────────────

  Stream<List<CategoryRow>> watchAllCategories() =>
      (select(categories)
            ..where((c) => c.isArchived.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();

  Future<int> addCategory({
    required String name,
    required CategoryKind kind,
    required int colorValue,
    required String iconKey,
    int? parentId,
  }) async {
    if (parentId != null) {
      await _assertValidParent(parentId, kind);
    }
    return into(categories).insert(
      CategoriesCompanion.insert(
        name: name,
        kind: kind,
        colorValue: colorValue,
        iconKey: iconKey,
        parentId: Value(parentId),
      ),
    );
  }

  /// [parentId] follows drift's `Value` convention: absent leaves the parent
  /// untouched, `Value(null)` promotes the category to top-level, `Value(x)`
  /// nests it under x. A move is validated exactly like a fresh nesting.
  Future<void> updateCategory({
    required int id,
    String? name,
    int? colorValue,
    String? iconKey,
    Value<int?> parentId = const Value.absent(),
  }) async {
    if (parentId.present && parentId.value != null) {
      final target = parentId.value!;
      if (target == id) {
        throw ArgumentError("A category can't be its own parent.");
      }
      final self = await categoryById(id);
      if (self == null) throw ArgumentError('That category no longer exists.');
      await _assertValidParent(target, self.kind);
      // Two levels only: a category that already has children can't itself
      // become a child, or the tree would grow a third tier.
      if (await countChildCategories(id) > 0) {
        throw ArgumentError(
          'This category has subcategories, so it must stay top-level. '
          'Move or remove its subcategories first.',
        );
      }
    }
    await (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        colorValue: colorValue == null
            ? const Value.absent()
            : Value(colorValue),
        iconKey: iconKey == null ? const Value.absent() : Value(iconKey),
        parentId: parentId,
      ),
    );
  }

  /// A parent must exist, be live, share the child's [kind], and itself be
  /// top-level. Throws [ArgumentError] with a user-facing message otherwise —
  /// the editor sheet surfaces it verbatim.
  Future<void> _assertValidParent(int parentId, CategoryKind kind) async {
    final parent = await categoryById(parentId);
    if (parent == null || parent.isArchived) {
      throw ArgumentError('That parent category is unavailable.');
    }
    if (parent.kind != kind) {
      throw ArgumentError(
        'A subcategory must match its parent — both income or both expense.',
      );
    }
    if (parent.parentId != null) {
      throw ArgumentError(
        "You can't nest under a subcategory. Pick a top-level category.",
      );
    }
  }

  /// How many live subcategories sit under [id].
  Future<int> countChildCategories(int id) async {
    final rows = await (select(
      categories,
    )..where((c) => c.parentId.equals(id) & c.isArchived.equals(false))).get();
    return rows.length;
  }

  /// Archive, never delete: deleting a category orphans every past transaction
  /// that referenced it and silently breaks old reports. Archiving a parent
  /// cascades to its subcategories so none is left stranded under a hidden
  /// parent — done in one transaction so the tree never lands half-archived.
  Future<void> archiveCategory(int id) => transaction(() async {
    await (update(categories)..where((c) => c.id.equals(id))).write(
      const CategoriesCompanion(isArchived: Value(true)),
    );
    await (update(categories)..where((c) => c.parentId.equals(id))).write(
      const CategoriesCompanion(isArchived: Value(true)),
    );
  });

  Future<int> countTransactionsForCategory(int categoryId) async {
    final rows = await (select(
      transactions,
    )..where((t) => t.categoryId.equals(categoryId))).get();
    return rows.length;
  }

  // ── Per-account history ───────────────────────────────────────────────────

  /// Every transaction touching this account, including transfers in *and* out,
  /// and anything paid via a debit card linked to it.
  Stream<List<TransactionRow>> watchTransactionsForAccount(
    int accountId,
  ) async* {
    final instruments = await (select(
      accounts,
    )..where((a) => a.linkedAccountId.equals(accountId))).get();
    final ids = <int>{accountId, ...instruments.map((a) => a.id)};

    yield* (select(transactions)
          ..where((t) => t.accountId.isIn(ids) | t.toAccountId.isIn(ids))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Statement lines for [accountId] between [start] and [end] inclusive
  /// (both calendar days), with [AccountStatement.openingBalance] carried in
  /// from everything that happened before [start] — exactly what a paper
  /// bank statement shows above its first row.
  Future<AccountStatement> accountStatement({
    required int accountId,
    required DateTime start,
    required DateTime end,
  }) async {
    final account = await (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    final allAccounts = await select(accounts).get();
    final accountsById = {for (final a in allAccounts) a.id: a};
    final categoriesById = {
      for (final c in await select(categories).get()) c.id: c,
    };
    final personsById = {for (final p in await select(persons).get()) p.id: p};
    final ownIds = <int>{
      accountId,
      for (final a in allAccounts)
        if (a.linkedAccountId == accountId) a.id,
    };

    final endOfEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    final all =
        await (select(transactions)
              ..where(
                (t) =>
                    (t.accountId.isIn(ownIds) | t.toAccountId.isIn(ownIds)) &
                    t.date.isSmallerOrEqualValue(endOfEnd),
              )
              ..orderBy([
                (t) => OrderingTerm(expression: t.date),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();

    String describe(TransactionRow t) {
      switch (t.type) {
        case TxType.transfer:
          final out = ownIds.contains(t.accountId);
          final otherId = out ? t.toAccountId : t.accountId;
          final other = otherId == null ? null : accountsById[otherId]?.name;
          return out
              ? 'Transfer to ${other ?? '-'}'
              : 'Transfer from ${other ?? '-'}';
        case TxType.personOut:
        case TxType.personIn:
          final person = t.personId == null
              ? null
              : personsById[t.personId]?.name;
          return t.type == TxType.personOut
              ? 'Given to ${person ?? 'person'}'
              : 'Received from ${person ?? 'person'}';
        case TxType.income:
        case TxType.expense:
          final category = t.categoryId == null
              ? null
              : categoriesById[t.categoryId];
          final base = category?.name ?? 'Uncategorised';
          final payee = t.payee?.trim();
          return (payee != null && payee.isNotEmpty) ? '$base - $payee' : base;
      }
    }

    var running = account.openingBalance;
    Money? openingBalance;
    final lines = <StatementLine>[];
    for (final t in all) {
      final movement = accountMovement(t, ownIds);
      running += movement;
      if (t.date.isBefore(start)) continue;
      openingBalance ??= running - movement;
      lines.add((
        transactionId: t.id,
        date: t.date,
        description: describe(t),
        debit: movement.isNegative ? movement.abs : const Money.zero(),
        credit: movement.isPositive ? movement : const Money.zero(),
        balance: running,
      ));
    }
    openingBalance ??= running; // nothing fell inside the range

    return (
      openingBalance: openingBalance,
      lines: lines,
      closingBalance: running,
    );
  }

  /// Planned vs. actual for every budgeted category in [month] — a subcategory
  /// budget rolls up under its own line; a parent's budget rolls its
  /// children's spend into it, exactly like [budgetProgressProvider] shows on
  /// screen (duplicated here rather than shared, since that provider is a
  /// Riverpod composition this data-only layer must not depend on).
  Future<List<BudgetStatementLine>> budgetStatement(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    final budgetRows = await select(budgets).get();
    final categoriesById = {
      for (final c in await select(categories).get()) c.id: c,
    };
    final spend = await watchSpendByCategory(start, end).first;

    final out = <BudgetStatementLine>[];
    for (final b in budgetRows) {
      final category = categoriesById[b.categoryId];
      if (category == null) continue;
      var spent = spend[b.categoryId] ?? const Money.zero();
      for (final c in categoriesById.values) {
        if (c.parentId == b.categoryId) {
          spent += spend[c.id] ?? const Money.zero();
        }
      }
      out.add((category: category, budgeted: b.amount, spent: spent));
    }
    out.sort((a, b) => a.category.name.compareTo(b.category.name));
    return out;
  }

  /// One category's statement for [month] — its budget line plus every
  /// expense in it, a parent rolling up its children's the same way
  /// [budgetStatement] and [categoryTransactionsProvider] both do (duplicated
  /// here rather than shared, since that provider is a Riverpod composition
  /// this data-only layer must not depend on).
  Future<CategoryStatement> categoryStatement({
    required int categoryId,
    required DateTime month,
  }) async {
    final category = await categoryById(categoryId);
    if (category == null) {
      throw ArgumentError('That category no longer exists.');
    }
    final start = DateTime(month.year, month.month);
    final end = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(milliseconds: 1));

    final categoriesById = {
      for (final c in await select(categories).get()) c.id: c,
    };
    final categoryIds = {
      categoryId,
      for (final c in categoriesById.values)
        if (c.parentId == categoryId) c.id,
    };

    final budget = await (select(
      budgets,
    )..where((b) => b.categoryId.equals(categoryId))).getSingleOrNull();

    final allSplits = await select(transactionSplits).get();
    final splitsByTx = <int, List<TransactionSplitRow>>{};
    for (final s in allSplits) {
      (splitsByTx[s.transactionId] ??= []).add(s);
    }

    final txs =
        await (select(transactions)
              ..where(
                (t) =>
                    t.type.equalsValue(TxType.expense) &
                    t.date.isBetweenValues(start, end),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.date)]))
            .get();

    var spent = const Money.zero();
    final lines = <CategoryStatementLine>[];
    for (final t in txs) {
      final payee = t.payee?.trim();
      final note = t.note?.trim();
      if (t.categoryId != null) {
        if (!categoryIds.contains(t.categoryId)) continue;
        spent += t.amount;
        lines.add((
          date: t.date,
          description: (note != null && note.isNotEmpty)
              ? note
              : (payee != null && payee.isNotEmpty ? payee : 'Expense'),
          amount: t.amount,
          isSplit: false,
        ));
        continue;
      }
      for (final s in splitsByTx[t.id] ?? const []) {
        if (!categoryIds.contains(s.categoryId)) continue;
        spent += s.amount;
        lines.add((
          date: t.date,
          description: (note != null && note.isNotEmpty)
              ? note
              : (payee != null && payee.isNotEmpty ? payee : 'Expense'),
          amount: s.amount,
          isSplit: true,
        ));
      }
    }
    lines.sort((a, b) => a.date.compareTo(b.date));

    return (
      category: category,
      budgeted: budget?.amount ?? const Money.zero(),
      spent: spent,
      lines: lines,
    );
  }

  /// Every account's transactions between [start] and [end] inclusive, merged
  /// date-wise rather than grouped by account — a real bank-style combined
  /// statement. Each row is one ledger transaction, named by its own
  /// [Transactions.accountId] (the source, for a transfer or expense; the
  /// destination, for income) — never expanded into two legs, so this list
  /// stays in step with the underlying ledger row-for-row.
  Future<List<CombinedStatementLine>> combinedStatement({
    required DateTime start,
    required DateTime end,
  }) async {
    final endOfEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    final accountsById = {
      for (final a in await select(accounts).get()) a.id: a,
    };
    final categoriesById = {
      for (final c in await select(categories).get()) c.id: c,
    };
    final personsById = {for (final p in await select(persons).get()) p.id: p};

    final txs =
        await (select(transactions)
              ..where((t) => t.date.isBetweenValues(start, endOfEnd))
              ..orderBy([
                (t) => OrderingTerm(expression: t.date),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();

    String typeLabel(TxType type) => switch (type) {
      TxType.income => 'Income',
      TxType.expense => 'Expense',
      TxType.transfer => 'Transfer',
      TxType.personOut => 'Lending out',
      TxType.personIn => 'Lending in',
    };

    String describe(TransactionRow t) {
      switch (t.type) {
        case TxType.transfer:
          final dest = t.toAccountId == null
              ? null
              : accountsById[t.toAccountId]?.name;
          return 'To ${dest ?? '-'}';
        case TxType.personOut:
        case TxType.personIn:
          final person = t.personId == null
              ? null
              : personsById[t.personId]?.name;
          return person ?? 'Person';
        case TxType.income:
        case TxType.expense:
          final category = t.categoryId == null
              ? null
              : categoriesById[t.categoryId]?.name;
          if (category != null) return category;
          final note = t.note?.trim();
          return (note != null && note.isNotEmpty) ? note : 'Uncategorised';
      }
    }

    return [
      for (final t in txs)
        (
          date: t.date,
          accountName: accountsById[t.accountId]?.name ?? 'Unknown',
          type: typeLabel(t.type),
          description: describe(t),
          amount: t.amount,
        ),
    ];
  }

  // ── Export / Import ───────────────────────────────────────────────────────

  static const backupFormatVersion = 1;

  /// Values must survive `jsonEncode`. Drift hands back real `DateTime`s (and
  /// already applies the Money converter, so amounts arrive as integer paise).
  static Object? _jsonSafe(Object? v) =>
      v is DateTime ? v.toIso8601String() : v;

  /// Undo [_jsonSafe], guided by the column's declared type. JSON has no date
  /// type, so an ISO string going into a `dateTime` column becomes a DateTime.
  // `type` is the column's `GeneratedColumn.type` (drift keeps its class
  // internal, so it arrives as Object and is compared by value).
  static Object? _fromJson(Object? value, Object type) {
    if (value == null) return null;
    if (type == DriftSqlType.dateTime) {
      if (value is String) return DateTime.parse(value);
      // Tolerate an older backup that stored raw unix seconds.
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    if (type == DriftSqlType.bool && value is int) return value != 0;
    if (type == DriftSqlType.double && value is int) return value.toDouble();
    return value;
  }

  /// A complete, portable snapshot. Money is exported as **integer paise**, the
  /// same way it is stored — never as a float.
  Future<Map<String, dynamic>> exportAll() async {
    Map<String, dynamic> m(Insertable<dynamic> row) => row
        .toColumns(false)
        .map((k, v) => MapEntry(k, _jsonSafe((v as Variable).value)));

    return {
      'formatVersion': backupFormatVersion,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': (await select(accounts).get()).map(m).toList(),
      'categories': (await select(categories).get()).map(m).toList(),
      'recurringRules': (await select(recurringRules).get()).map(m).toList(),
      'transactions': (await select(transactions).get()).map(m).toList(),
      'budgets': (await select(budgets).get()).map(m).toList(),
      'persons': (await select(persons).get()).map(m).toList(),
      'personEntries': (await select(personEntries).get()).map(m).toList(),
      'reminders': (await select(reminders).get()).map(m).toList(),
      'merchantRules': (await select(merchantRules).get()).map(m).toList(),
      'senderRules': (await select(senderRules).get()).map(m).toList(),
      'tags': (await select(tags).get()).map(m).toList(),
      'transactionTags': (await select(transactionTags).get()).map(m).toList(),
      'recurringRuleTags': (await select(
        recurringRuleTags,
      ).get()).map(m).toList(),
      'tagGroups': (await select(tagGroups).get()).map(m).toList(),
      'tagGroupTags': (await select(tagGroupTags).get()).map(m).toList(),
      'transactionSplits': (await select(
        transactionSplits,
      ).get()).map(m).toList(),
      'transactionLinks': (await select(
        transactionLinks,
      ).get()).map(m).toList(),
      'goalDetails': (await select(goalDetails).get()).map(m).toList(),
      'creditCardDetails': (await select(
        creditCardDetails,
      ).get()).map(m).toList(),
      'allocations': (await select(allocations).get()).map(m).toList(),
      'shoppingLists': (await select(shoppingLists).get()).map(m).toList(),
      'shoppingItems': (await select(shoppingItems).get()).map(m).toList(),
      // `importAll` clears these two, so they MUST be exported. Otherwise
      // restoring the app's own backup silently wipes un-reviewed capture cards
      // and resets the budget-alert dedupe (re-firing alerts already seen).
      'pendingTxns': (await select(pendingTxns).get()).map(m).toList(),
      'budgetAlerts': (await select(budgetAlerts).get()).map(m).toList(),
      'settings': (await select(settings).get()).map(m).toList(),
    };
  }

  /// Replace everything with the contents of a backup.
  ///
  /// Runs in a single transaction: if any row is malformed the whole restore
  /// rolls back and the existing ledger survives untouched. Order matters —
  /// parents before children, or the foreign keys reject the insert.
  Future<void> importAll(Map<String, dynamic> data) async {
    final version = data['formatVersion'];
    if (version is! int || version > backupFormatVersion) {
      throw ArgumentError(
        'This backup was made by a newer version of the app.',
      );
    }
    if (data['accounts'] is! List || data['transactions'] is! List) {
      throw ArgumentError('This file is not an XPENC backup.');
    }

    List<Map<String, Object?>> rows(String key) =>
        ((data[key] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, Object?>())
            .toList();

    // A backup carries a *ledger*, not the look of the phone it was taken on.
    // Restoring your data onto a new device must not repaint that device, so
    // the theme is read before the wipe and put back after the load. The
    // passcode gets the same treatment for a sharper reason: a backup taken
    // before one was ever set would otherwise silently turn the lock off by
    // importing a null hash over it.
    final localSettings = await select(settings).getSingleOrNull();
    final localTheme = localSettings?.themeName;
    final localPasscodeHash = localSettings?.passcodeHash;
    final localPasscodeSalt = localSettings?.passcodeSalt;
    final localBiometricEnabled = localSettings?.biometricEnabled ?? false;
    // Same reasoning as the passcode fields above, plus: the phrase can
    // never be recovered if lost, so importing a backup must never be able
    // to silently swap in a different (or null) one.
    final localMasterPhraseHash = localSettings?.masterPhraseHash;
    final localMasterPhraseSalt = localSettings?.masterPhraseSalt;
    final localMasterPhraseAttemptThreshold =
        localSettings?.masterPhraseAttemptThreshold ?? 5;
    final localFailedPasscodeAttempts =
        localSettings?.failedPasscodeAttempts ?? 0;

    // Foreign keys stay ON throughout (SQLite ignores the `foreign_keys` pragma
    // inside a transaction anyway). That is deliberate: a backup pointing at a
    // missing account must blow up and roll back, not import a broken ledger.
    await transaction(() async {
      // Children first, or the deletes violate the foreign keys.
      // `person_entries` -> `transactions` -> `persons`, so that exact order.
      await delete(budgetAlerts).go();
      await delete(pendingTxns).go();
      await delete(merchantRules).go();
      await delete(reminders).go();
      await delete(personEntries).go();
      await delete(budgets).go();
      // Both reference transactions/categories, so they go before either.
      await delete(transactionSplits).go();
      await delete(transactionTags).go();
      // References two transactions, so it goes before that delete too.
      await delete(transactionLinks).go();
      // References accounts and categories, so it goes before both deletes.
      await delete(allocations).go();
      // References accounts, so it goes before that delete too.
      await delete(goalDetails).go();
      await delete(creditCardDetails).go();
      await delete(transactions).go();
      // References recurringRules and tags, so it goes before both deletes.
      await delete(recurringRuleTags).go();
      // References accounts/categories, and transactions.recurringRuleId
      // references it back — so it goes after that delete, before these.
      await delete(recurringRules).go();
      await delete(persons).go();
      await delete(categories).go();
      await delete(accounts).go();
      await delete(senderRules).go();
      // References tags and tagGroups, so it goes before both deletes.
      await delete(tagGroupTags).go();
      await delete(tagGroups).go();
      await delete(tags).go();
      // Items reference lists, so they go first.
      await delete(shoppingItems).go();
      await delete(shoppingLists).go();
      await delete(settings).go();

      Future<void> load<T extends Table, D>(
        TableInfo<T, D> table,
        String key,
      ) async {
        final columns = table.columnsByName;
        for (final row in rows(key)) {
          final values = <String, Expression<Object>>{};
          for (final entry in row.entries) {
            final column = columns[entry.key];
            // A column this build no longer knows about — skip it rather than
            // fail, so an older backup still restores.
            if (column == null) continue;
            values[entry.key] = Variable(_fromJson(entry.value, column.type));
          }
          await into(table).insert(RawValuesInsertable<D>(values));
        }
      }

      // Parents first, or the inserts violate the foreign keys.
      // `persons` before `transactions` (transactions.person_id), and
      // `transactions` before `person_entries` (person_entries.transaction_id).
      await load(accounts, 'accounts');
      await load(categories, 'categories');
      await load(persons, 'persons');
      await load(tags, 'tags');
      // References tags, already loaded above. An older backup simply has no
      // rows for either, so `rows()` yields nothing.
      await load(tagGroups, 'tagGroups');
      await load(tagGroupTags, 'tagGroupTags');
      // A backup taken before v21 has no `goalDetails` key — its (old-shaped)
      // goals live under `savingsGoals` instead. `accounts` is already
      // loaded above, so the linked account's balance is there to snapshot.
      if (data['goalDetails'] != null) {
        await load(goalDetails, 'goalDetails');
      } else {
        for (final row in rows('savingsGoals')) {
          await _createGoalAccountFromLegacy(
            name: row['name'] as String,
            colorValue: row['color_value'] as int,
            iconKey: row['icon_key'] as String,
            isArchived:
                _fromJson(row['is_archived'], DriftSqlType.bool) as bool? ??
                false,
            createdAt:
                _fromJson(row['created_at'], DriftSqlType.dateTime)
                    as DateTime? ??
                DateTime.now(),
            targetAmount: Money(row['target_amount'] as int),
            targetDate:
                _fromJson(row['target_date'], DriftSqlType.dateTime)
                    as DateTime?,
            linkedAccountId: row['account_id'] as int,
          );
        }
      }
      // References accounts, already loaded above. An older backup simply
      // has no rows for it, so `rows()` yields nothing.
      await load(creditCardDetails, 'creditCardDetails');
      await load(shoppingLists, 'shoppingLists');
      // Before `transactions`, whose `recurringRuleId` references it — and an
      // older backup simply has no rows for it, so `rows()` yields nothing.
      await load(recurringRules, 'recurringRules');
      // References recurringRules and tags, both already loaded above. An
      // older backup simply has no rows for it, so `rows()` yields nothing.
      await load(recurringRuleTags, 'recurringRuleTags');
      await load(transactions, 'transactions');
      await load(budgets, 'budgets');
      // References accounts and categories, both already loaded above. An
      // older backup simply has no rows for it, so `rows()` yields nothing.
      await load(allocations, 'allocations');
      await load(personEntries, 'personEntries');
      await load(reminders, 'reminders');
      await load(merchantRules, 'merchantRules');
      await load(senderRules, 'senderRules');
      // These reference accounts/transactions/categories, so they come last.
      // An older backup simply has no rows for them — `rows()` yields nothing.
      await load(pendingTxns, 'pendingTxns');
      await load(budgetAlerts, 'budgetAlerts');
      // Both reference transactions/categories/tags, so they come after all
      // three are loaded.
      await load(transactionTags, 'transactionTags');
      await load(transactionSplits, 'transactionSplits');
      await load(transactionLinks, 'transactionLinks');
      await load(shoppingItems, 'shoppingItems');
      await load(settings, 'settings');

      if (localTheme != null) {
        await update(settings).write(
          SettingsCompanion(
            themeName: Value(localTheme),
            passcodeHash: Value(localPasscodeHash),
            passcodeSalt: Value(localPasscodeSalt),
            biometricEnabled: Value(localBiometricEnabled),
            masterPhraseHash: Value(localMasterPhraseHash),
            masterPhraseSalt: Value(localMasterPhraseSalt),
            masterPhraseAttemptThreshold: Value(
              localMasterPhraseAttemptThreshold,
            ),
            failedPasscodeAttempts: Value(localFailedPasscodeAttempts),
          ),
        );
      }
    });

    // The cache is only as good as the ledger it was built from.
    await recalculateBalances();

    if ((await select(settings).get()).isEmpty) {
      await into(settings).insert(const SettingsCompanion());
    }
  }

  /// Accountant / Tally friendly. Amounts as plain decimal rupees.
  Future<String> transactionsCsv() async {
    final txs = await (select(
      transactions,
    )..orderBy([(t) => OrderingTerm(expression: t.date)])).get();
    final accs = {for (final a in await select(accounts).get()) a.id: a.name};
    final cats = {for (final c in await select(categories).get()) c.id: c.name};
    final ppl = {for (final p in await select(persons).get()) p.id: p.name};

    String esc(String? s) {
      final v = s ?? '';
      return v.contains(RegExp('[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    }

    final b = StringBuffer(
      'Date,Type,Amount,Account,To Account,Category,Person,Note\n',
    );
    for (final t in txs) {
      final d = t.date;
      final date =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      b
        ..write(date)
        ..write(',')
        ..write(t.type.name)
        ..write(',')
        ..write((t.amount.paise / 100).toStringAsFixed(2))
        ..write(',')
        ..write(esc(accs[t.accountId]))
        ..write(',')
        ..write(esc(t.toAccountId == null ? '' : accs[t.toAccountId]))
        ..write(',')
        ..write(esc(t.categoryId == null ? '' : cats[t.categoryId]))
        ..write(',')
        ..write(esc(t.personId == null ? '' : ppl[t.personId]))
        ..write(',')
        ..write(esc(t.note))
        ..write('\n');
    }
    return b.toString();
  }
}
