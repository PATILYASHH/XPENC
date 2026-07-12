import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/money.dart';
import '../features/message_capture/parser/bank_message.dart';
import '../features/message_capture/parser/message_parser.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    Budgets,
    Persons,
    PersonEntries,
    Reminders,
    Settings,
    PendingTxns,
    MerchantRules,
    SenderRules,
    BudgetAlerts,
  ],
)
class AppDatabase extends _$AppDatabase {
  // The SQLite filename, NOT a brand. It survived the rename to XPENC on
  // purpose: it is a persistence key no user ever sees, and renaming it would
  // point the app at a fresh, empty database — silently losing the ledger of
  // anyone whose data directory carries over.
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'money_manager'));

  @override
  int get schemaVersion => 4;

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
            await m.addColumn(settings, settings.messageCaptureEnabled);
            await m.addColumn(settings, settings.lastMessageScanAt);
            await m.addColumn(settings, settings.notificationsEnabled);
            await _seedSenderRules();
          }
          if (from < 3) {
            await m.addColumn(transactions, transactions.personId);
            await m.addColumn(personEntries, personEntries.transactionId);
            await backfillPersonTransactions();
          }
          if (from < 4) {
            await m.addColumn(settings, settings.themeName);
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
        },
      );

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
    final entries = await (select(personEntries)
          ..where((e) => e.accountId.isNotNull() & e.transactionId.isNull()))
        .get();
    if (entries.isEmpty) return 0;

    for (final e in entries) {
      final person =
          await (select(persons)..where((p) => p.id.equals(e.personId)))
              .getSingleOrNull();

      final txId = await into(transactions).insert(
        TransactionsCompanion.insert(
          type: e.direction == PersonDirection.theyOwe
              ? TxType.personOut
              : TxType.personIn,
          amount: e.amount,
          accountId: e.accountId!,
          personId: Value(e.personId),
          date: e.date,
          note: Value(e.note ??
              (e.direction == PersonDirection.theyOwe
                  ? 'Gave to ${person?.name ?? 'person'}'
                  : 'Received from ${person?.name ?? 'person'}')),
        ),
      );

      await (update(personEntries)..where((x) => x.id.equals(e.id)))
          .write(PersonEntriesCompanion(transactionId: Value(txId)));
    }

    // The cache was built from the old two-ledger maths. Rebuild it from the
    // one ledger that now holds every movement.
    await recalculateBalances();
    return entries.length;
  }

  Future<void> _seedSenderRules() async {
    for (final r in kSeedSenderRules) {
      await into(senderRules).insert(
        SenderRulesCompanion.insert(
          senderPattern: r.pattern,
          bankName: r.bank,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  // ── Seed ──────────────────────────────────────────────────────────────────

  Future<void> _seed() async {
    await into(settings).insert(const SettingsCompanion());

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

  // ── Balance mechanics ─────────────────────────────────────────────────────

  /// Debit cards and UPI instruments hold no balance of their own — they draw
  /// from the bank they are linked to. Resolve to the account that actually
  /// holds the money, so `Bank + Debit Card` can never double-count.
  Future<int> _balanceTarget(int accountId) async {
    final row = await (select(accounts)..where((a) => a.id.equals(accountId)))
        .getSingle();
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

  void _validateTx({
    required TxType type,
    required Money amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    int? personId,
  }) {
    if (!amount.isPositive) {
      throw ArgumentError('Amount must be positive; direction comes from type.');
    }
    if (!type.isPersonMovement && personId != null) {
      throw ArgumentError('Only a person movement names a person.');
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
          throw ArgumentError(
            'Transfers carry no category — they are neither income nor expense.',
          );
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

  Future<int> addTransaction({
    required TxType type,
    required Money amount,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    int? personId,
    required DateTime date,
    String? note,
  }) {
    _validateTx(
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      personId: personId,
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
        ),
      );
      final row = await (select(transactions)..where((t) => t.id.equals(id)))
          .getSingle();
      await _applyTxEffect(row, reverse: false);
      return id;
    });
  }

  Future<void> deleteTransaction(int id) {
    return transaction(() async {
      final row = await (select(transactions)..where((t) => t.id.equals(id)))
          .getSingle();

      // A person movement belongs to that person's ledger. Deleting only the
      // money row would reverse the balance while still claiming the debt was
      // settled. Refuse, and send the user to the person instead.
      // (`deletePersonEntry` removes its entry first, so it never trips this.)
      final owner = await (select(personEntries)
            ..where((e) => e.transactionId.equals(id)))
          .getSingleOrNull();
      if (owner != null) {
        throw ArgumentError(
          'This belongs to a person. Delete it from their page instead.',
        );
      }

      await _applyTxEffect(row, reverse: true);

      // Other rows point at this transaction. Clear those references first or
      // the foreign key constraint fires and the delete throws — leaving the
      // money reversed but the row still there.
      await (update(reminders)..where((r) => r.transactionId.equals(id)))
          .write(const RemindersCompanion(transactionId: Value(null)));
      await (update(pendingTxns)
            ..where((t) => t.createdTransactionId.equals(id)))
          .write(const PendingTxnsCompanion(createdTransactionId: Value(null)));

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
  }) {
    _validateTx(
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      personId: personId,
    );

    return transaction(() async {
      final old = await (select(transactions)..where((t) => t.id.equals(id)))
          .getSingle();
      await _applyTxEffect(old, reverse: true);

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
          updatedAt: Value(DateTime.now()),
        ),
      );

      final fresh = await (select(transactions)..where((t) => t.id.equals(id)))
          .getSingle();
      await _applyTxEffect(fresh, reverse: false);
    });
  }

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
  }) {
    if (!amount.isPositive) {
      throw ArgumentError('Amount must be positive.');
    }
    return transaction(() async {
      int? txId;
      if (accountId != null) {
        final person = await (select(persons)..where((p) => p.id.equals(personId)))
            .getSingleOrNull();
        txId = await addTransaction(
          // theyOwe -> you gave money away.  iOwe -> money came to you.
          type: direction == PersonDirection.theyOwe
              ? TxType.personOut
              : TxType.personIn,
          amount: amount,
          accountId: accountId,
          personId: personId,
          date: date,
          note: note ??
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
        ),
      );
    });
  }

  Future<void> deletePersonEntry(int id) {
    return transaction(() async {
      final row = await (select(personEntries)..where((e) => e.id.equals(id)))
          .getSingle();
      // Drop the entry first: it references the transaction we are about to
      // delete, and the foreign key would reject the delete.
      await (delete(personEntries)..where((e) => e.id.equals(id))).go();
      // Deleting the ledger row reverses the money.
      if (row.transactionId != null) {
        await deleteTransaction(row.transactionId!);
      }
    });
  }

  /// `+` they owe you, `-` you owe them.
  Stream<Money> watchPersonBalance(int personId) {
    return (select(personEntries)..where((e) => e.personId.equals(personId)))
        .watch()
        .map(_netOf);
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
        await (update(accounts)..where((x) => x.id.equals(a.id)))
            .write(AccountsCompanion(currentBalance: Value(value)));
      }
    });
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Stream<List<AccountRow>> watchAccounts() =>
      (select(accounts)..where((a) => a.isArchived.equals(false))
            ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
          .watch();

  /// Accounts that actually hold money. Debit cards / UPI excluded.
  Stream<List<AccountRow>> watchBalanceHoldingAccounts() =>
      (select(accounts)
            ..where((a) =>
                a.isArchived.equals(false) & a.linkedAccountId.isNull())
            ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
          .watch();

  /// Total money = Cash + Bank + Credit Card. Instruments never double-count.
  Stream<Money> watchNetWorth() => watchBalanceHoldingAccounts().map(
        (rows) => rows.fold(
          const Money.zero(),
          (sum, a) => sum + a.currentBalance,
        ),
      );

  Stream<List<CategoryRow>> watchCategories(CategoryKind kind) =>
      (select(categories)
            ..where((c) => c.kind.equalsValue(kind) & c.isArchived.equals(false))
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
    final end = DateTime(month.year, month.month + 1)
        .subtract(const Duration(milliseconds: 1));
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

  /// Spend per category for a period. Transfers excluded; expenses only.
  Stream<Map<int, Money>> watchSpendByCategory(DateTime start, DateTime end) =>
      watchTransactionsBetween(start, end).map((rows) {
        final out = <int, Money>{};
        for (final t in rows) {
          if (t.type != TxType.expense || t.categoryId == null) continue;
          out[t.categoryId!] =
              (out[t.categoryId!] ?? const Money.zero()) + t.amount;
        }
        return out;
      });

  Stream<SettingRow> watchSettings() => select(settings).watchSingle();

  Future<void> markOnboarded() async {
    await update(settings).write(const SettingsCompanion(onboarded: Value(true)));
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
    final opening =
        linkedAccountId == null ? openingBalance : const Money.zero();

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

  Future<void> archiveAccount(int id) =>
      (update(accounts)..where((a) => a.id.equals(id)))
          .write(const AccountsCompanion(isArchived: Value(true)));

  // ── Persons CRUD ──────────────────────────────────────────────────────────

  Future<int> addPerson(String name, {String? contact, String? note}) =>
      into(persons).insert(
        PersonsCompanion.insert(
          name: name,
          contact: Value(contact),
          note: Value(note),
        ),
      );

  Stream<List<PersonRow>> watchPersons() =>
      (select(persons)..where((p) => p.isArchived.equals(false))).watch();

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

  Future<void> upsertBudget({
    required int categoryId,
    required Money amount,
    BudgetPeriod period = BudgetPeriod.monthly,
    int alertThresholdPct = 80,
  }) =>
      into(budgets).insertOnConflictUpdate(
        BudgetsCompanion.insert(
          categoryId: categoryId,
          amount: amount,
          period: period,
          startDate: DateTime(DateTime.now().year, DateTime.now().month),
          alertThresholdPct: Value(alertThresholdPct),
        ),
      );

  Future<void> deleteBudget(int categoryId) =>
      (delete(budgets)..where((b) => b.categoryId.equals(categoryId))).go();

  Stream<List<BudgetRow>> watchBudgets() =>
      (select(budgets)..where((b) => b.isActive.equals(true))).watch();

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
  }) =>
      into(reminders).insert(
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

  Stream<List<ReminderRow>> watchReminders() =>
      (select(reminders)..orderBy([(r) => OrderingTerm(expression: r.dueDate)]))
          .watch();

  Future<void> setReminderStatus(int id, ReminderStatus status,
          {int? transactionId}) =>
      (update(reminders)..where((r) => r.id.equals(id))).write(
        RemindersCompanion(
          status: Value(status),
          transactionId: Value(transactionId),
        ),
      );

  Future<void> deleteReminder(int id) =>
      (delete(reminders)..where((r) => r.id.equals(id))).go();

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

    final rows = await (select(pendingTxns)
          ..where((t) =>
              t.receivedAt.isBetweenValues(from, to) &
              t.status.equalsValue(PendingStatus.dismissed).not()))
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
  Future<int?> ingestMessage(RawMessage msg, ParsedMessage parsed) {
    return transaction(() async {
      final key = dedupeKeyFor(msg);
      final seen = await (select(pendingTxns)
            ..where((t) => t.dedupeKey.equals(key)))
          .getSingleOrNull();
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
  Future<int> approvePending(
    int pendingId, {
    required int categoryId,
    required int accountId,
    bool autoFilled = false,
    int? appliedRuleId,
    bool learnMerchantRule = false,
  }) {
    return transaction(() async {
      final p = await (select(pendingTxns)..where((t) => t.id.equals(pendingId)))
          .getSingle();
      if (p.parsedAmount == null || p.parsedDirection == null) {
        throw ArgumentError('This message has no amount or direction to post.');
      }
      if (p.createdTransactionId != null) {
        throw ArgumentError('This card was already posted.');
      }

      final txId = await addTransaction(
        type: txTypeFor(p.parsedDirection!),
        amount: p.parsedAmount!,
        accountId: accountId,
        categoryId: categoryId,
        date: p.receivedAt,
        note: p.parsedMerchant,
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

      if (learnMerchantRule && p.parsedMerchant != null) {
        await upsertMerchantRule(
          pattern: p.parsedMerchant!,
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
      final p = await (select(pendingTxns)..where((t) => t.id.equals(pendingId)))
          .getSingle();
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
      (update(pendingTxns)..where((t) => t.id.equals(id)))
          .write(PendingTxnsCompanion(status: Value(status)));

  /// Cards the user should see: awaiting a category, or auto-filled for info.
  Stream<List<PendingTxnRow>> watchPendingCards() => (select(pendingTxns)
        ..where((t) =>
            t.status.equalsValue(PendingStatus.pending) |
            t.status.equalsValue(PendingStatus.autoFilled))
        ..orderBy([
          (t) => OrderingTerm(expression: t.receivedAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Stream<List<PendingTxnRow>> watchAllPendingTxns() => (select(pendingTxns)
        ..orderBy([
          (t) => OrderingTerm(expression: t.receivedAt, mode: OrderingMode.desc),
        ]))
      .watch();

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
    final existing = await (select(merchantRules)
          ..where((r) => r.matchPattern.equals(pattern)))
        .getSingleOrNull();

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
      await (update(merchantRules)..where((r) => r.id.equals(existing.id)))
          .write(
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
      (update(senderRules)..where((r) => r.id.equals(id)))
          .write(SenderRulesCompanion(enabled: Value(enabled)));

  // ── Settings for capture ─────────────────────────────────────────────────

  Future<void> setMessageCaptureEnabled(bool enabled) => update(settings)
      .write(SettingsCompanion(messageCaptureEnabled: Value(enabled)));

  Future<void> setAutoApprove(bool enabled) =>
      update(settings).write(SettingsCompanion(autoApprove: Value(enabled)));

  Future<void> setNotificationsEnabled(bool enabled) => update(settings)
      .write(SettingsCompanion(notificationsEnabled: Value(enabled)));

  Future<void> setLastMessageScanAt(DateTime at) =>
      update(settings).write(SettingsCompanion(lastMessageScanAt: Value(at)));

  /// [name] must be a `ThemePreset.name`. Unknown values are tolerated on read,
  /// so a bad write degrades to the default rather than bricking the app.
  Future<void> setThemeName(String name) =>
      update(settings).write(SettingsCompanion(themeName: Value(name)));

  Future<SettingRow> getSettings() => select(settings).getSingle();

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
      final existing = await (select(budgetAlerts)
            ..where((a) =>
                a.categoryId.equals(categoryId) &
                a.periodKey.equals(periodKey) &
                a.level.equalsValue(level)))
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
      (delete(budgetAlerts)
            ..where((a) =>
                a.categoryId.equals(categoryId) &
                a.periodKey.equals(periodKey) &
                a.level.equalsValue(level)))
          .go();

  // ── Categories CRUD ───────────────────────────────────────────────────────

  Stream<List<CategoryRow>> watchAllCategories() => (select(categories)
        ..where((c) => c.isArchived.equals(false))
        ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
      .watch();

  Future<int> addCategory({
    required String name,
    required CategoryKind kind,
    required int colorValue,
    required String iconKey,
  }) =>
      into(categories).insert(
        CategoriesCompanion.insert(
          name: name,
          kind: kind,
          colorValue: colorValue,
          iconKey: iconKey,
        ),
      );

  Future<void> updateCategory({
    required int id,
    String? name,
    int? colorValue,
    String? iconKey,
  }) =>
      (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: name == null ? const Value.absent() : Value(name),
          colorValue:
              colorValue == null ? const Value.absent() : Value(colorValue),
          iconKey: iconKey == null ? const Value.absent() : Value(iconKey),
        ),
      );

  /// Archive, never delete: deleting a category orphans every past transaction
  /// that referenced it and silently breaks old reports.
  Future<void> archiveCategory(int id) =>
      (update(categories)..where((c) => c.id.equals(id)))
          .write(const CategoriesCompanion(isArchived: Value(true)));

  Future<int> countTransactionsForCategory(int categoryId) async {
    final rows = await (select(transactions)
          ..where((t) => t.categoryId.equals(categoryId)))
        .get();
    return rows.length;
  }

  // ── Per-account history ───────────────────────────────────────────────────

  /// Every transaction touching this account, including transfers in *and* out,
  /// and anything paid via a debit card linked to it.
  Stream<List<TransactionRow>> watchTransactionsForAccount(int accountId) async* {
    final instruments = await (select(accounts)
          ..where((a) => a.linkedAccountId.equals(accountId)))
        .get();
    final ids = <int>{accountId, ...instruments.map((a) => a.id)};

    yield* (select(transactions)
          ..where((t) => t.accountId.isIn(ids) | t.toAccountId.isIn(ids))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .watch();
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
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
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
      'transactions': (await select(transactions).get()).map(m).toList(),
      'budgets': (await select(budgets).get()).map(m).toList(),
      'persons': (await select(persons).get()).map(m).toList(),
      'personEntries': (await select(personEntries).get()).map(m).toList(),
      'reminders': (await select(reminders).get()).map(m).toList(),
      'merchantRules': (await select(merchantRules).get()).map(m).toList(),
      'senderRules': (await select(senderRules).get()).map(m).toList(),
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
    // the theme is read before the wipe and put back after the load.
    final localTheme = (await select(settings).getSingleOrNull())?.themeName;

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
      await delete(transactions).go();
      await delete(persons).go();
      await delete(categories).go();
      await delete(accounts).go();
      await delete(senderRules).go();
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
      await load(transactions, 'transactions');
      await load(budgets, 'budgets');
      await load(personEntries, 'personEntries');
      await load(reminders, 'reminders');
      await load(merchantRules, 'merchantRules');
      await load(senderRules, 'senderRules');
      // These reference accounts/transactions/categories, so they come last.
      // An older backup simply has no rows for them — `rows()` yields nothing.
      await load(pendingTxns, 'pendingTxns');
      await load(budgetAlerts, 'budgetAlerts');
      await load(settings, 'settings');

      if (localTheme != null) {
        await update(settings).write(SettingsCompanion(
          themeName: Value(localTheme),
        ));
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
    final txs = await (select(transactions)
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .get();
    final accs = {for (final a in await select(accounts).get()) a.id: a.name};
    final cats = {for (final c in await select(categories).get()) c.id: c.name};
    final ppl = {for (final p in await select(persons).get()) p.id: p.name};

    String esc(String? s) {
      final v = s ?? '';
      return v.contains(RegExp('[",\n]'))
          ? '"${v.replaceAll('"', '""')}"'
          : v;
    }

    final b = StringBuffer(
      'Date,Type,Amount,Account,To Account,Category,Person,Note\n',
    );
    for (final t in txs) {
      final d = t.date;
      final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
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
