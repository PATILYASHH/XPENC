import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/voice/voice_parser.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// What a typed or spoken entry can be filed under, kept live — the
/// categories, the keywords people gave them and the accounts (GitHub #213).
/// "Type it" and voice add read the same three.

/// Live, everyday categories — a mode's own ones stay inside that mode.
final entryCategoriesProvider = Provider<List<VoiceCategory>>((ref) => [
  for (final c in ref.watch(categoryMapProvider).values)
    if (!c.isArchived && c.modeId == null)
      (id: c.id, name: c.name, income: c.kind == CategoryKind.income),
]);

/// Every category keyword. One for an archived or gone category is simply
/// never matched — the parser only files under [entryCategoriesProvider].
final entryKeywordsProvider = Provider<List<EntryKeyword>>((ref) => [
  for (final r in ref.watch(merchantRulesProvider).valueOrNull ?? const [])
    (word: r.matchPattern, categoryId: r.categoryId),
]);

/// Accounts money in or out can use — not a goal or a loan, which only
/// take transfers.
final entryAccountRowsProvider = Provider<List<AccountRow>>((ref) => [
  for (final a in ref.watch(accountsProvider).valueOrNull ?? const [])
    if (a.type != AccountType.goal && a.type != AccountType.loan) a,
]);

final entryAccountsProvider = Provider<List<EntryAccount>>((ref) => [
  for (final a in ref.watch(entryAccountRowsProvider)) (id: a.id, name: a.name),
]);

/// Reads [text] off a keyboard with everything above. [listen] is for a
/// build (it rebuilds as keywords change); a tap's callback passes false.
VoiceDraft parseTypedEntry(
  WidgetRef ref,
  String text, {
  DateTime? now,
  bool listen = true,
}) {
  T get<T>(ProviderListenable<T> p) => listen ? ref.watch(p) : ref.read(p);
  return parseVoiceEntry(
    text,
    categories: get(entryCategoriesProvider),
    keywords: get(entryKeywordsProvider),
    accounts: get(entryAccountsProvider),
    now: now ?? DateTime.now(),
    typed: true,
  );
}
