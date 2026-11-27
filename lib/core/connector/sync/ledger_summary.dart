/// What a backup dump holds, counted. "Use it" shows GitHub's beside this
/// browser's, so a stale or empty backup is seen for what it is before it
/// replaces anything. On 2026-11-27 a reinstalled phone pushed a 5-Aug
/// backup of six entries over three hundred, and nothing on screen said so.
class LedgerSummary {
  const LedgerSummary({
    required this.transactions,
    required this.accounts,
    required this.people,
    this.latestEntry,
  });

  factory LedgerSummary.of(Map<String, dynamic> dump) {
    DateTime? latest;
    for (final t in _rows(dump['transactions'])) {
      final date = switch (t['date']) {
        final String s => DateTime.tryParse(s),
        final int seconds => DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
        ),
        _ => null,
      };
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return LedgerSummary(
      transactions: _rows(dump['transactions']).length,
      accounts: _rows(dump['accounts']).length,
      people: _rows(dump['persons']).length,
      latestEntry: latest,
    );
  }

  final int transactions;
  final int accounts;
  final int people;

  /// The newest transaction's own date, not when it was typed in.
  final DateTime? latestEntry;

  static List<Map<Object?, Object?>> _rows(Object? list) => [
    if (list is List)
      for (final row in list)
        if (row is Map) row,
  ];
}

/// Tables that only ever have rows because the user put something there.
const _userTables = [
  'transactions',
  'personEntries',
  'persons',
  'groups',
  'groupExpenses',
  'recurringRules',
  'budgets',
  'goalDetails',
  'loanDetails',
  'reminders',
  'shoppingLists',
  'transactionTemplates',
];

/// Whether [dump] holds anything the user made. A new or cleared ledger
/// doesn't: it's the seeded Cash account and default categories
/// (`AppDatabase._seedDefaultAccountsAndCategories`) and nothing else.
bool ledgerHasData(Map<String, dynamic> dump) {
  final accounts = dump['accounts'];
  if (accounts is List && accounts.length > 1) return true;
  return _userTables.any((t) {
    final rows = dump[t];
    return rows is List && rows.isNotEmpty;
  });
}
