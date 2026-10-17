import 'package:drift/drift.dart';

import '../core/currency.dart';
import '../core/money.dart';
import 'database.dart';
import 'tables.dart';

/// Modes — a trip or an event the app focuses on while it's ON. See
/// [Modes] and `docs/superpowers/specs/2026-10-17-modes-design.md`.
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
  }) async {
    final clean = await _validateMode(
      name: name,
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      currencyCode: currencyCode,
      groupId: groupId,
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
        ),
      );
      await _writeModeLinks(id, accountIds, categoryIds, tagIds);
      return id;
    });
  }

  /// Rewrites every field and the three link sets — the editor always holds
  /// the whole mode, so there's no partial update to get wrong.
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
  }) async {
    if (await modeById(id) == null) {
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
        ),
      );
      await _writeModeLinks(id, accountIds, categoryIds, tagIds);
    });
  }

  /// Switches [id] ON. Only one mode is ON at a time, so whichever was ON
  /// before ends first. Starting an ended mode again keeps its first
  /// `startedAt` — the trip began when it began.
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

  /// Deletes the mode, never its money: its transactions simply stop being
  /// in a mode, and its own categories become ordinary archived ones (still
  /// naming their transactions) — its own tags ordinary tags.
  Future<void> deleteMode(int id) => transaction(() async {
    await (update(transactions)..where((t) => t.modeId.equals(id))).write(
      const TransactionsCompanion(modeId: Value(null)),
    );
    await (update(categories)..where((c) => c.modeId.equals(id))).write(
      const CategoriesCompanion(modeId: Value(null), isArchived: Value(true)),
    );
    await (update(tags)..where((t) => t.modeId.equals(id))).write(
      const TagsCompanion(modeId: Value(null)),
    );
    await (delete(modeAccounts)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeCategories)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeTags)..where((l) => l.modeId.equals(id))).go();
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
  /// is ON. Run on launch and resume. Returns how many modes changed.
  Future<int> syncModeSchedule(DateTime now) => transaction(() async {
    final today = DateTime(now.year, now.month, now.day);
    var changed = 0;
    final active = await activeModeId();
    if (active != null) {
      final mode = await modeById(active);
      if (mode == null) {
        // A dangling pointer (the mode went some other way) — just drop it.
        await update(
          settings,
        ).write(const SettingsCompanion(activeModeId: Value(null)));
      } else if (mode.endDate != null && mode.endDate!.isBefore(today)) {
        await _end(active);
        changed++;
      }
    }
    if (await activeModeId() != null) return changed;
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
      return changed + 1;
    }
    return changed;
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _validateMode({
    required String name,
    DateTime? startDate,
    DateTime? endDate,
    Money? budget,
    String? currencyCode,
    int? groupId,
    int? selfId,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Give the mode a name.');
    if (clean.length > 40) {
      throw ArgumentError('Keep the name to 40 characters.');
    }
    if (budget != null && budget.paise <= 0) {
      throw ArgumentError('A budget has to be more than zero.');
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
  ) async {
    await (delete(modeAccounts)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeCategories)..where((l) => l.modeId.equals(id))).go();
    await (delete(modeTags)..where((l) => l.modeId.equals(id))).go();
    for (final a in accountIds) {
      await into(
        modeAccounts,
      ).insert(ModeAccountsCompanion.insert(modeId: id, accountId: a));
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
  }
}

DateTime? _day(DateTime? d) =>
    d == null ? null : DateTime(d.year, d.month, d.day);
