import 'package:flutter/material.dart';

import '../../core/connector/connector_platform.dart';
import '../../core/platform/platform_features.dart';
import '../../core/routing/quick_actions.dart';
import '../../core/l10n/l10n.dart';
import '../../data/database.dart';

// Global search (GitHub #209): one plain keyword search over the whole app —
// its pages and settings, and every record the user has made. No AI, no
// index: everything searched is already in memory through the providers the
// rest of the app watches, so a lookup is a pass over a few lists.
//
// The matching lives here, apart from the screen, so it can be tested
// without pumping widgets.

/// Splits [query] into lower-case words. Every word has to appear somewhere
/// in a candidate's text for it to match ("swiggy march" finds a Swiggy
/// order with "march" in its note), in any order.
List<String> searchTerms(String query) => query
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// Whether every one of [terms] appears in one of [fields].
bool matchesAll(List<String> terms, Iterable<String?> fields) {
  if (terms.isEmpty) return false;
  final haystack = fields.whereType<String>().join(' ').toLowerCase();
  return terms.every(haystack.contains);
}

/// The query as an amount in paise, if it reads as one: `250`, `250.5`,
/// `1,250.00`, `₹250`. A grouping comma is dropped; a decimal comma isn't
/// guessed at — `2,50` is 250, the same reading the amount field gives it.
int? searchAmountPaise(String query) {
  final cleaned = query.trim().replaceAll(RegExp(r'[^\d.,]'), '');
  if (cleaned.isEmpty || !RegExp(r'\d').hasMatch(cleaned)) return null;
  final value = double.tryParse(cleaned.replaceAll(',', ''));
  if (value == null || value <= 0) return null;
  return (value * 100).round();
}

/// Sorts named records so the ones whose name *starts* with the query come
/// before the ones that merely contain it, then alphabetically.
List<T> rankByName<T>(
  Iterable<T> items,
  String Function(T) nameOf,
  List<String> terms,
) {
  final first = terms.isEmpty ? '' : terms.first;
  int rank(T item) => nameOf(item).toLowerCase().startsWith(first) ? 0 : 1;
  return items.toList()..sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0
        ? r
        : nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase());
  });
}

/// Transactions whose note, payee, category, account or amount matches,
/// newest first. A numeric query also matches the amount exactly — "250"
/// finds every ₹250.00 entry even when no text says 250.
List<TransactionRow> searchTransactions(
  String query,
  List<TransactionRow> txns, {
  required Map<int, CategoryRow> categories,
  required Map<int, AccountRow> accounts,
}) {
  final terms = searchTerms(query);
  if (terms.isEmpty) return const [];
  final paise = searchAmountPaise(query);
  final out = txns.where((t) {
    if (paise != null && t.amount.paise.abs() == paise) return true;
    return matchesAll(terms, [
      t.note,
      t.payee,
      t.categoryId == null ? null : categories[t.categoryId]?.name,
      accounts[t.accountId]?.name,
      t.toAccountId == null ? null : accounts[t.toAccountId]?.name,
    ]);
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// One place in the app the search can take you to — a screen, a settings
/// page or a calculator.
class SearchPage {
  const SearchPage({
    required this.label,
    required this.icon,
    required this.route,
    this.keywords = const [],
  });

  /// English; translated when shown, and matched in both languages.
  final String label;
  final IconData icon;
  final String route;

  /// Extra English words that should find this page — what's on it.
  final List<String> keywords;

  bool matches(List<String> terms) => matchesAll(terms, [
    label,
    tr(label),
    for (final k in keywords) ...[k, tr(k)],
  ]);
}

/// Every page the search knows: the quick-action catalogue (modules and
/// calculators — one list, so a new module shows up in both) plus the
/// settings pages, each with what it holds as keywords. Pages a platform
/// doesn't have are left out, as in Settings — and India-only calculators
/// unless [indiaTools].
List<SearchPage> searchPages({bool indiaTools = true}) => [
  for (final spec in quickActionCatalog)
    if (spec.id != searchQuickActionId && (indiaTools || !spec.indiaOnly))
      SearchPage(
        label: spec.englishLabel,
        icon: spec.icon,
        route: spec.route,
        keywords: [
          spec.englishGroup,
          if (spec.englishGroup == 'Calculations' || spec.id == 'calculations')
            'Calculator',
        ],
      ),
  const SearchPage(
    label: 'Language',
    icon: Icons.translate_rounded,
    route: '/more/settings/language',
  ),
  const SearchPage(
    label: 'General',
    icon: Icons.tune_rounded,
    route: '/more/settings/general',
    keywords: ['Settings', 'Language, currency, theme, font, dashboard layout'],
  ),
  const SearchPage(
    label: 'Level & Budgeting',
    icon: Icons.stairs_rounded,
    route: '/more/settings/mode-budgeting',
    keywords: ['Settings', 'App level, budget cycle, Ready to Assign'],
  ),
  const SearchPage(
    label: 'Security & Privacy',
    icon: Icons.lock_rounded,
    route: '/more/settings/security',
    keywords: ['Settings', 'Passcode'],
  ),
  if (PlatformFeatures.permissionsScreen)
    const SearchPage(
      label: 'Permissions',
      icon: Icons.verified_user_rounded,
      route: '/more/settings/permissions',
      keywords: ['Settings', 'What XPENC can access — turn each on or off'],
    ),
  if (PlatformFeatures.notifications)
    const SearchPage(
      label: 'Notifications',
      icon: Icons.notifications_rounded,
      route: '/more/settings/notifications',
      keywords: ['Settings'],
    ),
  if (PlatformFeatures.smsCapture)
    const SearchPage(
      label: 'Auto money tracking',
      icon: Icons.sms_rounded,
      route: '/more/settings/advanced/sms',
      keywords: [
        'Settings',
        'Advanced Features',
        'Bank SMS, messages, auto capture',
      ],
    ),
  const SearchPage(
    label: 'Quick Actions',
    icon: Icons.touch_app_rounded,
    route: '/more/settings/quick-actions',
    keywords: ['Settings'],
  ),
  const SearchPage(
    label: 'Data',
    icon: Icons.storage_rounded,
    route: '/more/settings/data',
    keywords: ['Settings', 'Recalculate balances, clear all data'],
  ),
  if (connectorPlatform != null)
    const SearchPage(
      label: 'Connector',
      icon: Icons.devices_rounded,
      route: '/more/settings/connector',
      keywords: ['Settings', 'Sync with your phones, Connector friends'],
    ),
  const SearchPage(
    label: 'Currency',
    icon: Icons.currency_exchange_rounded,
    route: '/more/settings/currency',
    keywords: ['Settings'],
  ),
  const SearchPage(
    label: 'Customize bottom nav',
    icon: Icons.dashboard_customize_rounded,
    route: '/more/bottom-nav',
    keywords: ['Settings', 'Choose what goes next to the ➕ button'],
  ),
  const SearchPage(
    label: 'Guide',
    icon: Icons.menu_book_rounded,
    route: '/more/guide',
  ),
  const SearchPage(
    label: "What's new",
    icon: Icons.new_releases_rounded,
    route: '/more/whats-new',
  ),
  const SearchPage(
    label: 'About',
    icon: Icons.info_rounded,
    route: '/more/about',
  ),
];
