import 'package:flutter/material.dart';

/// One line item on the What's New screen — what shipped, where to find it,
/// and what it actually does. Updated by hand alongside CHANGELOG.md each
/// release; there's no automated link between the two (see CHANGELOG.md for
/// the full, dated history — this is just the current version's highlights,
/// written for someone opening the app, not reading a changelog).
class WhatsNewEntry {
  const WhatsNewEntry({
    required this.icon,
    required this.title,
    required this.location,
    required this.description,
  });

  final IconData icon;
  final String title;

  /// Where to find it, e.g. "Persons → tap a person".
  final String location;
  final String description;
}

const whatsNewEntries = <WhatsNewEntry>[
  WhatsNewEntry(
    icon: Icons.currency_exchange_rounded,
    title: 'Multi-currency accounts',
    location: 'Accounts → Add Account',
    description:
        'Open an account in any supported currency. Balances, statements '
        'and PDFs render in its own currency, transfers between different '
        'currencies show a live conversion preview, and Net Worth converts '
        'everything into your home currency automatically.',
  ),
  WhatsNewEntry(
    icon: Icons.pie_chart_outline_rounded,
    title: 'Ready to Assign replaces Budgets vs. Envelope',
    location: 'Settings → Budgeting',
    description:
        'Budget limits are always on now, and Ready to Assign is a single '
        'toggle on top — turn it on to pool every account into one shared '
        '"assign before you spend" figure, instead of choosing one system '
        'or the other.',
  ),
  WhatsNewEntry(
    icon: Icons.lock_outline_rounded,
    title: 'Independent unlock method toggles',
    location: 'Settings → Security',
    description:
        'Turn on PIN, master password and/or an authenticator app in any '
        'combination — any one of them unlocks the app — instead of '
        'picking exactly one.',
  ),
  WhatsNewEntry(
    icon: Icons.leaderboard_outlined,
    title: 'Standings in Stats',
    location: 'Stats → Standings',
    description:
        'A ranked, high-to-low list of top transactions or top categories '
        'for the period. Every category view now also shows its share of '
        'total spend and links straight into that category\'s detail.',
  ),
  WhatsNewEntry(
    icon: Icons.folder_copy_outlined,
    title: 'Category templates',
    location: 'Categories → templates icon',
    description:
        'Save your current category structure as a named template and '
        'switch between saved templates any time — switching never '
        'touches a transaction.',
  ),
  WhatsNewEntry(
    icon: Icons.category_outlined,
    title: 'Bigger, searchable icon picker',
    location: 'Categories / Add Account',
    description:
        'Category and account icons grow from 28 to 76, picked from a '
        'searchable sheet with a "Frequently used" row instead of an '
        'inline grid.',
  ),
  WhatsNewEntry(
    icon: Icons.autorenew_rounded,
    title: 'Auto rules: Goals & Loans',
    location: 'Auto → add/edit a rule',
    description:
        'A recurring rule can now post a transfer into a goal or a loan '
        'payment on schedule, alongside the existing Expense/Income kinds.',
  ),
  WhatsNewEntry(
    icon: Icons.sell_outlined,
    title: 'Tag groups',
    location: 'Tags → group icon',
    description:
        'Bundle tags that always go together (e.g. "Work trip" = Travel + '
        'Meals) and pick the whole group at once from the tag picker.',
  ),
  WhatsNewEntry(
    icon: Icons.copy_all_outlined,
    title: 'Duplicate a transaction',
    location: 'Transactions → long-press',
    description:
        'Long-press a transaction for Duplicate / Edit / Delete. Duplicate '
        'prefills a new entry from the source but resets the date to today.',
  ),
  WhatsNewEntry(
    icon: Icons.bookmark_add_outlined,
    title: 'Transaction templates',
    location: 'Add transaction → ➕',
    description:
        '"Create template from this transaction" snapshots its details for '
        'reuse — the ➕ button offers a template once you\'ve saved one.',
  ),
  WhatsNewEntry(
    icon: Icons.event_repeat_rounded,
    title: 'Turn a transaction into a recurring payment',
    location: 'Transaction detail',
    description:
        '"Make recurring" opens the auto rule sheet pre-filled with that '
        'transaction\'s amount, account, category, payee, note and tags.',
  ),
  WhatsNewEntry(
    icon: Icons.event_available_outlined,
    title: 'Custom budget cycle start day',
    location: 'Settings → Budgeting',
    description:
        'Treat any day 1–28 as the start of a "month," so a payday-anchored '
        'cycle doesn\'t reset mid-paycheck. Defaults to the 1st.',
  ),
  WhatsNewEntry(
    icon: Icons.view_week_outlined,
    title: 'Filter transactions by ISO week',
    location: 'Transactions → filter',
    description:
        'A "Week" toggle steps through standard Monday–Sunday weeks '
        'instead of requiring a manual date range.',
  ),
  WhatsNewEntry(
    icon: Icons.picture_as_pdf_outlined,
    title: 'Share a person or group ledger as a PDF',
    location: 'Person / Group detail',
    description:
        'The same statement flow accounts already had — a lend/borrow '
        'ledger for a person, a shared-expense history for a group.',
  ),
  WhatsNewEntry(
    icon: Icons.wifi_off_rounded,
    title: 'Pay without internet — *99# (Beta)',
    location: 'Persons → Individual tab',
    description:
        'Turn on Settings → Payment Support → UPI\'s new sub-toggle to pay '
        'a person via the offline USSD *99# menu when there\'s no data '
        'signal.',
  ),
  WhatsNewEntry(
    icon: Icons.auto_delete_outlined,
    title: 'Keep-last-X backup retention & batch delete',
    location: 'Settings → Backups',
    description:
        'An alternative, count-based auto-backup retention mode, plus '
        'long-press batch-select to delete several backups from the list '
        'at once.',
  ),
];
