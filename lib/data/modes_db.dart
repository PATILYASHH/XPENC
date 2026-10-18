import 'package:drift/drift.dart';

import '../core/currency.dart';
import '../core/money.dart';
import 'database.dart';
import 'tables.dart';

/// Modes — a trip or an event the app focuses on while it's ON. See
/// [Modes] and `docs/superpowers/specs/2026-10-17-modes-design.md` (v1) and
/// `…-modes-v2-design.md` (people, allocations, limits, wallet, planned
/// costs).
///
/// Kept apart from [AppDatabase] itself so the ledger file doesn't grow
/// another few hundred lines; everything here only reads and writes the
/// mode tables and the `modeId` pointers.
extension ModesDb on AppDatabase {
  // ── Reads ─────────────────────────────────────────────────────────────────

  /// Newest first — the list screen groups them by status itself.
  Stream<List<ModeRow>> watchModes() =>
      (select(modes)..orderBy([
            (m) =>
                OrderingTerm(expression: m.createdAt, mode: OrderingMode.desc),
            (m) => OrderingTerm(expression: m.id, mode: OrderingMode.desc),
          ]))
          .watch();

  Future<ModeRow?> modeById(int id) =>
      (select(modes)..where((m) => m.id.equals(id))).getSingleOrNull();

  Stream<List<ModeAccountRow>> watchModeAccounts() =>
      select(modeAccounts).watch();
  Stream<List<ModeCategoryRow>> watchModeCategories() =>
      select(modeCategories).watch();
  Stream<List<ModeTagRow>> watchModeTags() => select(modeTags).watch();
  Stream<List<ModeCategoryLimitRow>> watchModeCategoryLimits() =>
      select(modeCategoryLimits).watch();
  Stream<List<ModePlannedCostRow>> watchModePlannedCosts() =>
      (select(modePlannedCosts)..orderBy([
            (c) => OrderingTerm(expression: c.sortOrder),
            (c) => OrderingTerm(expression: c.id),
          ]))
          .watch();

  /// Every person entry made in any mode — a trip balance counts only these.
  Stream<List<PersonEntryRow>> watchModePersonEntries() =>
      (select(personEntries)..where((e) => e.modeId.isNotNull())).watch();

  /// A mode's own templates, newest first — see
  /// [TransactionTemplates.modeId].
  Stream<List<TransactionTemplateRow>> watchModeTemplates(int modeId) =>
      (select(transactionTemplates)
            ..where((t) => t.modeId.equals(modeId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  /// Every transaction in [modeId], newest first.
  Stream<List<TransactionRow>> watchModeTransactions(int modeId) =>
      (select(transactions)
            ..where((t) => t.modeId.equals(modeId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
            ]))
          .watch();

  /// Categories made for a mode (live ones — a deleted mode's become
  /// ordinary archived categories).
  Stream<List<CategoryRow>> watchModeOwnCategories() =>
      (select(categories)
            ..where((c) => c.modeId.isNotNull() & c.isArchived.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();

  /// The tags every new transaction in [modeId] starts with.
  Future<Set<int>> modeTagIds(int modeId) async => {
    for (final l in await (select(
      modeTags,
    )..where((l) => l.modeId.equals(modeId))).get())
      l.tagId,
  };

  /// The accounts [modeId] pays with — empty means any.
  Future<Set<int>> modeAccountIds(int modeId) async => {
    for (final l in await (select(
      modeAccounts,
    )..where((l) => l.modeId.equals(modeId))).get())
      l.accountId,
  };

  /// The people on [modeId] — its group's members.
  Future<Set<int>> modePeopleIds(int modeId) async {
    final groupId = (await modeById(modeId))?.groupId;
    if (groupId == null) return <int>{};
    return {
      for (final m in await (select(
        groupMembers,
      )..where((m) => m.groupId.equals(groupId))).get())
        m.personId,
    };
  }

  /// Adds [modeId]'s auto-tags to a transaction that just joined it outside
  /// the Add screen (quick add, a bank message), keeping the ones it had.
  Future<void> applyModeTags(int txId, int? modeId) async {
    if (modeId == null) return;
    final auto = await modeTagIds(modeId);
    if (auto.isEmpty) return;
    await setTransactionTags(txId, {
      ...await tagIdsForTransaction(txId),
      ...auto,
    });
  }

  /// The mode that's ON, if any.
  Future<int?> activeModeId() async => (await getSettings()).activeModeId;

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<int> addMode({
    required String name,
    required String iconKey,
    required int colorValue,
    DateTime? startDate,
    DateTime? endDate,
    Money? budget,
    String? currencyCode,
    int? groupId,
    String? navSlots,
    String modules = '',
    Set<int> accountIds = const {},
    Set<int> categoryIds = const {},
    Set<int> tagIds = const {},
    Map<int, Money> allocations = const {},
    Map<int, Money> categoryLimits = const {},
    Money? dailyLimit,
    Money? spendLimit,
    int? walletSourceAccountId,
    Money? walletAmount,
    Set<int>? personIds,
  }) async {
    final clean = await _validateMode(
      name: name,
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      currencyCode: currencyCode,
      groupId: groupId,
      allocations: allocations,
      categoryLimits: categoryLimits,
      dailyLimit: dailyLimit,
      spendLimit: spendLimit,
      walletSourceAccountId: walletSourceAccountId,
      walletAmount: walletAmount,
    );
    return transaction(() async {
      final id = await into(modes).insert(
        ModesCompanion.insert(
          name: clean,
          iconKey: iconKey,
          colorValue: colorValue,
          startDate: Value(_day(startDate)),
          endDate: Value(_day(endDate)),
          budget: Value(budget),
          currencyCode: Value(currencyCode),
          groupId: Value(groupId),
          navSlots: Value(navSlots),
          modules: Value(modules),
          dailyLimit: Value(dailyLimit),
          spendLimit: Value(spendLimit),
          walletSourceAccountId: Value(walletSourceAccountId),
          walletAmount: Value(walletAmount),
        ),
      );
      await _writeModeLinks(
        id,
        accountIds,
        categoryIds,
        tagIds,
        allocations,
        categoryLimits,
      );
      if (personIds != null) await _setPeople(id, personIds);
      return id;
    });
  }

  /// Rewrites every field and the link sets — the editor always holds the
  /// whole mode, so there's no partial update to get wrong. [personIds]
  /// null leaves the people as they are.
  Future<void> updateMode(
    int id, {
    required String name,
    required String iconKey,
    required int colorValue,
    DateTime? startDate,
    DateTime? endDate,
    Money? budget,
    String? currencyCode,
    int? groupId,
    String? navSlots,
    String modules = '',
    Set<int> accountIds = const {},
    Set<int> categoryIds = const {},
    Set<int> tagIds = const {},
    Map<int, Money> allocations = const {},
    Map<int, Money> categoryLimits = const {},
    Money? dailyLimit,
    Money? spendLimit,
    int? walletSourceAccountId,
    Money? walletAmount,
    Set<int>? personIds,
  }) async {
    final existing = await modeById(id);
    if (existing == null) {
      throw ArgumentError('That mode no longer exists.');
    }
    final clean = await _validateMode(
      name: name,
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      currencyCode: currencyCode,
      groupId: groupId,
      selfId: id,
      allocations: allocations,
      categoryLimits: categoryLimits,
      dailyLimit: dailyLimit,
      spendLimit: spendLimit,
      walletSourceAccountId: walletSourceAccountId,
      walletAmount: walletAmount,
    );
    await transaction(() async {
      await (update(modes)..where((m) => m.id.equals(id))).write(
        ModesCompanion(
          name: Value(clean),
          iconKey: Value(iconKey),
          colorValue: Value(colorValue),
          startDate: Value(_day(startDate)),
          endDate: Value(_day(endDate)),
          budget: Value(budget),
          currencyCode: Value(currencyCode),
          groupId: Value(groupId),
          navSlots: Value(navSlots),
          modules: Value(modules),
          dailyLimit: Value(dailyLimit),
          spendLimit: Value(spendLimit),
          // Once the wallet exists its setup is history — only a mode that
          // hasn't made one yet can change it.
          walletSourceAccountId: existing.walletAccountId == null
              ? Value(walletSourceAccountId)
              : const Value.absent(),
          walletAmount: existing.walletAccountId == null
              ? Value(walletAmount)
              : const Value.absent(),
        ),
      );
      final accounts = {...accountIds};
      final allocs = {...allocations};
      // The wallet stays one of a limited mode's accounts.
      final wallet = existing.walletAccountId;
      if (wallet != null &&
          await _limitsAccounts(id) &&
          !accounts.contains(wallet)) {
        accounts.add(wallet);
        final row =
            await (select(modeAccounts)..where(
                  (l) => l.modeId.equals(id) & l.accountId.equals(wallet),
                ))
                .getSingleOrNull();
        if (row?.allocation != null) allocs[wallet] = row!.allocation!;
      }
      await _writeModeLinks(
        id,
        accounts,
        categoryIds,
        tagIds,
        allocs,
        categoryLimits,
      );
      if (personIds != null) await _setPeople(id, personIds);
    });
  }

  /// The transaction that is your own share of a group expense you paid —
  /// null when you didn't pay it.
  Future<int?> myGroupShareTransactionId(int groupExpenseId) async =>
      (await (select(groupExpenseShares)..where(
                (s) =>
                    s.groupExpenseId.equals(groupExpenseId) &
                    s.personId.isNull(),
              ))
              .getSingleOrNull())
          ?.transactionId;

  /// Adds [tagIds] to [modeId]'s auto-tags (a tag made for the mode after
  /// it was saved), leaving the rest of the mode alone.
  Future<void> addModeAutoTags(int modeId, Iterable<int> tagIds) async {
    for (final t in tagIds) {
      await into(modeTags).insertOnConflictUpdate(
        ModeTagsCompanion.insert(modeId: modeId, tagId: t),
      );
    }
  }

  /// The people on [modeId]: they become its group's members, making the
  /// group (named after the mode) when it has none.
  Future<void> setModePeople(int modeId, Set<int> personIds) =>
      transaction(() => _setPeople(modeId, personIds));

  Future<void> _setPeople(int modeId, Set<int> personIds) async {
    final mode = await modeById(modeId);
    if (mode == null) throw ArgumentError('That mode no longer exists.');
    var groupId = mode.groupId;
    if (groupId == null) {
      if (personIds.isEmpty) return;
      groupId = await addGroup(mode.name);
      await (update(modes)..where((m) => m.id.equals(modeId))).write(
        ModesCompanion(groupId: Value(groupId)),
      );
    }
    await setGroupMembers(groupId, personIds);
  }

  /// Switches [id] ON. Only one mode is ON at a time, so whichever was ON
  /// before ends first. Starting an ended mode again keeps its first
  /// `startedAt` — the trip began when it began. A mode with a trip wallet
  /// set up makes it now (once).
  Future<void> startMode(int id) => transaction(() async {
    final mode = await modeById(id);
    if (mode == null) throw ArgumentError('That mode no longer exists.');
    final current = await activeModeId();
    if (current != null && current != id) await _end(current);
    await (update(modes)..where((m) => m.id.equals(id))).write(
      ModesCompanion(
        status: const Value(ModeStatus.active),
        startedAt: Value(mode.startedAt ?? DateTime.now()),
        endedAt: const Value(null),
      ),
    );
    await update(settings).write(SettingsCompanion(activeModeId: Value(id)));
    await _makeWallet(mode);
  });

  Future<void> endMode(int id) => transaction(() => _end(id));

  Future<void> _end(int id) async {
    await (update(modes)..where((m) => m.id.equals(id))).write(
      ModesCompanion(
        status: const Value(ModeStatus.ended),
        endedAt: Value(DateTime.now()),
      ),
    );
    if (await activeModeId() == id) {
      await update(
        settings,
      ).write(const SettingsCompanion(activeModeId: Value(null)));
    }
  }

  /// Trip wallet: a cash account for the mode, with [ModeRow.walletAmount]
  /// moved in from [ModeRow.walletSourceAccountId] — inside the mode, so it
  /// shows on its page, but a transfer, so it isn't "spent".
  Future<void> _makeWallet(ModeRow mode) async {
    final amount = mode.walletAmount;
    final source = mode.walletSourceAccountId;
    if (mode.walletAccountId != null || amount == null || source == null) {
      return;
    }
    final from = await (select(
      accounts,
    )..where((a) => a.id.equals(source))).getSingleOrNull();
    if (from == null) return;
    final name = '${mode.name} wallet';
    final wallet = await addAccount(
      name: name.length > 40 ? name.substring(0, 40) : name,
      type: AccountType.cash,
      colorValue: mode.colorValue,
      iconKey: 'wallet',
      openingBalance: const Money.zero(),
      currencyCode: from.currencyCode,
    );
    await addTransaction(
      type: TxType.transfer,
      amount: amount,
      accountId: source,
      toAccountId: wallet,
      date: DateTime.now(),
      note: 'Into the ${mode.name} wallet',
      modeId: mode.id,
    );
    await (update(modes)..where((m) => m.id.equals(mode.id))).write(
      ModesCompanion(walletAccountId: Value(wallet)),
    );
    // A mode that limits its accounts pays from the wallet too.
    if (await _limitsAccounts(mode.id)) {
      await into(modeAccounts).insert(
        ModeAccountsCompanion.insert(
          modeId: mode.id,
          accountId: wallet,
          allocation: Value(amount),
        ),
      );
    }
  }

  /// Moves whatever is left in [modeId]'s trip wallet back to where it came
  /// from, and archives the wallet. Returns the amount moved (zero when
  /// nothing was left).
  Future<Money> returnWalletLeftover(int modeId) => transaction(() async {
    final mode = await modeById(modeId);
    final walletId = mode?.walletAccountId;
    if (mode == null || walletId == null) return const Money.zero();
    final wallet = await (select(
      accounts,
    )..where((a) => a.id.equals(walletId))).getSingleOrNull();
    if (wallet == null) return const Money.zero();
    final left = wallet.currentBalance;
    final back = mode.walletSourceAccountId;
    if (left.isPositive && back != null) {
      await addTransaction(
        type: TxType.transfer,
        amount: left,
        accountId: walletId,
        toAccountId: back,
        date: DateTime.now(),
        note: 'Left over from the ${mode.name} wallet',
        modeId: modeId,
      );
    }
    await archiveAccount(walletId);
    return left.isPositive && back != null ? left : const Money.zero();
  });

  /// Deletes the mode, never its money: its transactions and person entries
  /// simply stop being in a mode, its own categories become ordinary
  /// archived ones (still naming their transactions), its own tags ordinary
  /// tags. Its templates, limits and planned costs go with it.
  Future<void> deleteMode(int id) => transaction(() async {
    await (update(transactions)..where((t) => t.modeId.equals(id))).write(
      const TransactionsCompanion(modeId: Value(null)),
    );
    await (update(personEntries)..where((e) => e.modeId.equals(id))).write(
      const PersonEntriesCompanion(modeId: Value(null)),
    );
    await (update(categories)..where((c) => c.modeId.equals(id))).write(
      const CategoriesCompanion(modeId: Value(null), isArchived: Value(true)),
    );
    await (update(tags)..where((t) => t.modeId.equals(id))).write(
      const TagsCompanion(modeId: Value(null)),
    );
    for (final t in await (select(
      transactionTemplates,
    )..where((t) => t.modeId.equals(id))).get()) {
      await deleteTransactionTemplate(t.id);
    }
    await (delete(modeAccounts)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeCategories)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeTags)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeCategoryLimits)..where((l) => l.modeId.equals(id))).go();
    await (delete(modePlannedCosts)..where((c) => c.modeId.equals(id))).go();
    if (await activeModeId() == id) {
      await update(
        settings,
      ).write(const SettingsCompanion(activeModeId: Value(null)));
    }
    await (delete(modes)..where((m) => m.id.equals(id))).go();
  });

  /// Moves a transaction into [modeId], or out of any mode with null. A
  /// split-across-accounts payment moves as one: every leg goes with it.
  Future<void> setTransactionMode(int txId, int? modeId) async {
    if (modeId != null && await modeById(modeId) == null) {
      throw ArgumentError('That mode no longer exists.');
    }
    final tx = await (select(
      transactions,
    )..where((t) => t.id.equals(txId))).getSingleOrNull();
    if (tx == null) throw ArgumentError('That transaction no longer exists.');
    final group = tx.paymentGroupId;
    await (update(transactions)..where(
          (t) => group == null
              ? t.id.equals(txId)
              : t.paymentGroupId.equals(group),
        ))
        .write(TransactionsCompanion(modeId: Value(modeId)));
  }

  /// Follows the modes' planned dates: an ON mode past its end date ends,
  /// then a planned mode whose start date has come starts — if nothing else
  /// is ON. Run on launch and resume. Returns the ids of the modes that
  /// ended (their summary is worth a notification) and how many changed.
  Future<({int changed, List<int> ended})> syncModeSchedule(DateTime now) =>
      transaction(() async {
        final today = DateTime(now.year, now.month, now.day);
        var changed = 0;
        final ended = <int>[];
        final active = await activeModeId();
        if (active != null) {
          final mode = await modeById(active);
          if (mode == null) {
            // A dangling pointer (the mode went some other way) — drop it.
            await update(
              settings,
            ).write(const SettingsCompanion(activeModeId: Value(null)));
          } else if (mode.endDate != null && mode.endDate!.isBefore(today)) {
            await _end(active);
            ended.add(active);
            changed++;
          }
        }
        if (await activeModeId() != null) {
          return (changed: changed, ended: ended);
        }
        final planned =
            await (select(modes)
                  ..where(
                    (m) =>
                        m.status.equalsValue(ModeStatus.planned) &
                        m.startDate.isSmallerOrEqualValue(today),
                  )
                  ..orderBy([(m) => OrderingTerm(expression: m.startDate)]))
                .get();
        for (final mode in planned) {
          if (mode.endDate != null && mode.endDate!.isBefore(today)) continue;
          await startMode(mode.id);
          return (changed: changed + 1, ended: ended);
        }
        return (changed: changed, ended: ended);
      });

  /// A category made only for [modeId] — offered in that mode's pickers,
  /// never in everyday lists.
  Future<int> addModeCategory({
    required int modeId,
    required String name,
    required CategoryKind kind,
    required int colorValue,
    required String iconKey,
  }) async {
    if (await modeById(modeId) == null) {
      throw ArgumentError('That mode no longer exists.');
    }
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Give the category a name.');
    return into(categories).insert(
      CategoriesCompanion.insert(
        name: clean,
        kind: kind,
        colorValue: colorValue,
        iconKey: iconKey,
        modeId: Value(modeId),
      ),
    );
  }

  /// A tag made only for [modeId]. Tag names are unique across the app, so
  /// one that already exists is refused rather than silently reused.
  Future<int> addModeTag({
    required int modeId,
    required String name,
    required int colorValue,
  }) async {
    if (await modeById(modeId) == null) {
      throw ArgumentError('That mode no longer exists.');
    }
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Give the tag a name.');
    final taken = await (select(
      tags,
    )..where((t) => t.name.lower().equals(clean.toLowerCase()))).get();
    if (taken.isNotEmpty) {
      throw ArgumentError('There is already a tag called "$clean".');
    }
    return into(tags).insert(
      TagsCompanion.insert(
        name: clean,
        colorValue: colorValue,
        modeId: Value(modeId),
      ),
    );
  }

  // ── Planned costs ─────────────────────────────────────────────────────────

  Future<int> addPlannedCost({
    required int modeId,
    required String name,
    required Money amount,
    int? categoryId,
  }) async {
    if (await modeById(modeId) == null) {
      throw ArgumentError('That mode no longer exists.');
    }
    final clean = _plannedName(name, amount);
    final last =
        await (select(modePlannedCosts)
              ..where((c) => c.modeId.equals(modeId))
              ..orderBy([
                (c) => OrderingTerm(
                  expression: c.sortOrder,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return into(modePlannedCosts).insert(
      ModePlannedCostsCompanion.insert(
        modeId: modeId,
        name: clean,
        amount: amount,
        categoryId: Value(categoryId),
        sortOrder: Value((last?.sortOrder ?? -1) + 1),
      ),
    );
  }

  Future<void> updatePlannedCost(
    int id, {
    required String name,
    required Money amount,
    int? categoryId,
  }) {
    final clean = _plannedName(name, amount);
    return (update(modePlannedCosts)..where((c) => c.id.equals(id))).write(
      ModePlannedCostsCompanion(
        name: Value(clean),
        amount: Value(amount),
        categoryId: Value(categoryId),
      ),
    );
  }

  Future<void> deletePlannedCost(int id) =>
      (delete(modePlannedCosts)..where((c) => c.id.equals(id))).go();

  /// Marks a planned cost paid by [transactionId] — or unpaid again with
  /// null.
  Future<void> setPlannedCostPaid(int id, int? transactionId) =>
      (update(modePlannedCosts)..where((c) => c.id.equals(id))).write(
        ModePlannedCostsCompanion(transactionId: Value(transactionId)),
      );

  String _plannedName(String name, Money amount) {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Give the cost a name.');
    if (clean.length > 60) {
      throw ArgumentError('Keep the name to 60 characters.');
    }
    if (!amount.isPositive) {
      throw ArgumentError('A planned cost has to be more than zero.');
    }
    return clean;
  }

  // ── Limits and alerts ─────────────────────────────────────────────────────

  /// What spending [amount] in [categoryId] from [accountId] on [date] would
  /// break in [modeId] — the total budget (counting unpaid planned costs),
  /// the daily limit, the category's limit (or its parent's), the per-spend
  /// cap and the account's allocation. Empty = within every limit. Only
  /// ever warns: saving stays the person's call.
  ///
  /// [excludeTxId] leaves out a transaction being edited; [plannedCostId]
  /// one being paid (it's already counted as planned).
  Future<List<String>> modeLimitWarnings({
    required int modeId,
    required Money amount,
    int? categoryId,
    int? accountId,
    required DateTime date,
    int? excludeTxId,
    int? plannedCostId,
  }) async {
    final mode = await modeById(modeId);
    if (mode == null || !amount.isPositive) return const [];
    final txs = [
      for (final t in await (select(
        transactions,
      )..where((t) => t.modeId.equals(modeId))).get())
        if (t.id != excludeTxId) t,
    ];
    final expenses = [
      for (final t in txs)
        if (t.type == TxType.expense) t,
    ];
    final out = <String>[];
    String m(Money v) => MoneyFormat.symbol(v);

    final links = await (select(
      modeAccounts,
    )..where((l) => l.modeId.equals(modeId))).get();
    final budget = effectiveModeBudget(mode.budget, [
      for (final l in links) l.allocation,
    ]);
    if (budget != null) {
      final planned = [
        for (final c in await (select(
          modePlannedCosts,
        )..where((c) => c.modeId.equals(modeId))).get())
          if (c.transactionId == null && c.id != plannedCostId) c.amount,
      ].fold(const Money.zero(), (a, b) => a + b);
      final spent = expenses.fold(const Money.zero(), (a, t) => a + t.amount);
      final after = spent + planned + amount;
      if (after.paise > budget.paise) {
        out.add('${m(after - budget)} over the ${m(budget)} budget');
      }
    }

    final daily = mode.dailyLimit;
    if (daily != null) {
      final today = [
        for (final t in expenses)
          if (_sameDay(t.date, date)) t.amount,
      ].fold(const Money.zero(), (a, b) => a + b);
      final after = today + amount;
      if (after.paise > daily.paise) {
        out.add("${m(after - daily)} over the day's ${m(daily)} limit");
      }
    }

    if (categoryId != null) {
      final limits = {
        for (final l in await (select(
          modeCategoryLimits,
        )..where((l) => l.modeId.equals(modeId))).get())
          l.categoryId: l.amount,
      };
      if (limits.isNotEmpty) {
        final cats = {for (final c in await select(categories).get()) c.id: c};
        int topOf(int id) => cats[id]?.parentId ?? id;
        for (final limited in {categoryId, topOf(categoryId)}) {
          final cap = limits[limited];
          if (cap == null) continue;
          var spent = const Money.zero();
          for (final t in expenses) {
            if (t.categoryId != null) {
              if (t.categoryId == limited || topOf(t.categoryId!) == limited) {
                spent += t.amount;
              }
              continue;
            }
            for (final s in await splitsForTransaction(t.id)) {
              if (s.categoryId == limited || topOf(s.categoryId) == limited) {
                spent += s.amount;
              }
            }
          }
          final after = spent + amount;
          if (after.paise > cap.paise) {
            final name = cats[limited]?.name ?? 'category';
            out.add('${m(after - cap)} over the $name limit of ${m(cap)}');
          }
        }
      }
    }

    final cap = mode.spendLimit;
    if (cap != null && amount.paise > cap.paise) {
      out.add('More than the ${m(cap)} per-spend limit');
    }

    if (accountId != null) {
      final link = links.where((l) => l.accountId == accountId).firstOrNull;
      final allocation = link?.allocation;
      if (allocation != null) {
        final balance = allocatedBalance(allocation, accountId, txs);
        if (amount.paise > balance.paise) {
          final name = (await (select(
            accounts,
          )..where((a) => a.id.equals(accountId))).getSingleOrNull())?.name;
          out.add(
            '${m(amount - balance)} more than is left of '
            '${name ?? 'this account'} for ${mode.name}',
          );
        }
      }
    }
    return out;
  }

  /// The 80% / 100% alerts [modeId] has reached but not yet sent, as
  /// (key, title, body). Record them with [markModeAlerts] once shown.
  Future<List<({String key, String title, String body})>> dueModeAlerts(
    int modeId,
  ) async {
    final mode = await modeById(modeId);
    if (mode == null) return const [];
    final fired = mode.alerts.split(',').toSet();
    final txs = await (select(
      transactions,
    )..where((t) => t.modeId.equals(modeId))).get();
    final expenses = [
      for (final t in txs)
        if (t.type == TxType.expense) t,
    ];
    final spent = expenses.fold(const Money.zero(), (a, t) => a + t.amount);
    final out = <({String key, String title, String body})>[];

    void check(String key, String what, Money used, Money cap) {
      if (cap.paise <= 0) return;
      final share = used.paise / cap.paise;
      for (final (pct, label) in [(100, 'used up'), (80, '80% used')]) {
        if (share * 100 < pct) continue;
        final k = '$key$pct';
        if (!fired.contains(k)) {
          out.add((
            key: k,
            title: '${mode.name}: $what $label',
            body:
                '${MoneyFormat.symbol(used)} of ${MoneyFormat.symbol(cap)} '
                'spent.',
          ));
        }
        break; // only the highest threshold reached
      }
    }

    final links = await (select(
      modeAccounts,
    )..where((l) => l.modeId.equals(modeId))).get();
    final budget = effectiveModeBudget(mode.budget, [
      for (final l in links) l.allocation,
    ]);
    if (budget != null) check('budget', 'budget', spent, budget);

    final limits = await (select(
      modeCategoryLimits,
    )..where((l) => l.modeId.equals(modeId))).get();
    if (limits.isNotEmpty) {
      final cats = {for (final c in await select(categories).get()) c.id: c};
      int topOf(int id) => cats[id]?.parentId ?? id;
      for (final l in limits) {
        var used = const Money.zero();
        for (final t in expenses) {
          final c = t.categoryId;
          if (c != null && (c == l.categoryId || topOf(c) == l.categoryId)) {
            used += t.amount;
          }
        }
        check(
          'cat${l.categoryId}-',
          cats[l.categoryId]?.name ?? 'category',
          used,
          l.amount,
        );
      }
    }
    return out;
  }

  /// Remembers that [keys] were sent, so each alert fires once per mode.
  Future<void> markModeAlerts(int modeId, Iterable<String> keys) async {
    final mode = await modeById(modeId);
    if (mode == null) return;
    final all = {...mode.alerts.split(',').where((k) => k.isNotEmpty), ...keys};
    await (update(modes)..where((m) => m.id.equals(modeId))).write(
      ModesCompanion(alerts: Value(all.join(','))),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _limitsAccounts(int modeId) async =>
      (await (select(modeAccounts)
                ..where((l) => l.modeId.equals(modeId))
                ..limit(1))
              .get())
          .isNotEmpty;

  Future<String> _validateMode({
    required String name,
    DateTime? startDate,
    DateTime? endDate,
    Money? budget,
    String? currencyCode,
    int? groupId,
    int? selfId,
    Map<int, Money> allocations = const {},
    Map<int, Money> categoryLimits = const {},
    Money? dailyLimit,
    Money? spendLimit,
    int? walletSourceAccountId,
    Money? walletAmount,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Give the mode a name.');
    if (clean.length > 40) {
      throw ArgumentError('Keep the name to 40 characters.');
    }
    if (budget != null && budget.paise <= 0) {
      throw ArgumentError('A budget has to be more than zero.');
    }
    for (final (label, v) in [
      ('daily limit', dailyLimit),
      ('per-spend limit', spendLimit),
      ('wallet amount', walletAmount),
    ]) {
      if (v != null && v.paise <= 0) {
        throw ArgumentError('The $label has to be more than zero.');
      }
    }
    if (allocations.values.any((v) => v.paise <= 0) ||
        categoryLimits.values.any((v) => v.paise <= 0)) {
      throw ArgumentError('Every amount set has to be more than zero.');
    }
    if ((walletSourceAccountId == null) != (walletAmount == null)) {
      throw ArgumentError(
        'A trip wallet needs both an amount and an account to fill it from.',
      );
    }
    if (walletSourceAccountId != null) {
      final from = await (select(
        accounts,
      )..where((a) => a.id.equals(walletSourceAccountId))).getSingleOrNull();
      if (from == null) throw ArgumentError('That account no longer exists.');
      if (from.type == AccountType.goal || from.type == AccountType.loan) {
        throw ArgumentError('Fill the wallet from a spendable account.');
      }
    }
    final start = _day(startDate);
    final end = _day(endDate);
    if (start != null && end != null && end.isBefore(start)) {
      throw ArgumentError("The end date can't be before the start date.");
    }
    if (currencyCode != null &&
        currencyForCode(currencyCode).code != currencyCode) {
      throw ArgumentError('Unknown currency $currencyCode.');
    }
    if (groupId != null) {
      final group = await (select(
        groups,
      )..where((g) => g.id.equals(groupId))).getSingleOrNull();
      if (group == null) throw ArgumentError('That group no longer exists.');
      final other =
          await (select(modes)..where(
                (m) =>
                    m.groupId.equals(groupId) &
                    (selfId == null
                        ? const Constant(true)
                        : m.id.equals(selfId).not()),
              ))
              .get();
      if (other.isNotEmpty) {
        throw ArgumentError(
          '${group.name} is already linked to ${other.first.name}.',
        );
      }
    }
    return clean;
  }

  Future<void> _writeModeLinks(
    int id,
    Set<int> accountIds,
    Set<int> categoryIds,
    Set<int> tagIds,
    Map<int, Money> allocations,
    Map<int, Money> categoryLimits,
  ) async {
    await (delete(modeAccounts)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeCategories)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeTags)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeCategoryLimits)..where((l) => l.modeId.equals(id))).go();
    // An allocation names its account, so it limits the mode to it too.
    for (final a in {...accountIds, ...allocations.keys}) {
      await into(modeAccounts).insert(
        ModeAccountsCompanion.insert(
          modeId: id,
          accountId: a,
          allocation: Value(allocations[a]),
        ),
      );
    }
    for (final c in categoryIds) {
      await into(
        modeCategories,
      ).insert(ModeCategoriesCompanion.insert(modeId: id, categoryId: c));
    }
    for (final t in tagIds) {
      await into(
        modeTags,
      ).insert(ModeTagsCompanion.insert(modeId: id, tagId: t));
    }
    for (final e in categoryLimits.entries) {
      await into(modeCategoryLimits).insert(
        ModeCategoryLimitsCompanion.insert(
          modeId: id,
          categoryId: e.key,
          amount: e.value,
        ),
      );
    }
  }
}

/// A mode's budget: its own, or — when it has none — what its accounts were
/// allocated in total. Null = no budget at all.
Money? effectiveModeBudget(Money? own, Iterable<Money?> allocations) {
  if (own != null) return own;
  final set = [for (final a in allocations) ?a];
  if (set.isEmpty) return null;
  return set.fold<Money>(const Money.zero(), (a, b) => a + b);
}

/// What's left of an account's [allocation] after the mode's own money
/// movements on it ([modeTxs] — every transaction in the mode): money out
/// of [accountId] lowers it, money into it raises it.
Money allocatedBalance(
  Money allocation,
  int accountId,
  Iterable<TransactionRow> modeTxs,
) {
  var left = allocation;
  for (final t in modeTxs) {
    if (t.accountId == accountId) {
      left = switch (t.type) {
        TxType.income ||
        TxType.personIn ||
        TxType.correctionIn => left + t.amount,
        _ => left - t.amount,
      };
    }
    if (t.type == TxType.transfer && t.toAccountId == accountId) {
      left += t.toAmount ?? t.amount;
    }
  }
  return left;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime? _day(DateTime? d) =>
    d == null ? null : DateTime(d.year, d.month, d.day);
