import 'package:flutter/material.dart';

/// One feature explained: what it does, how to use it, and where to find
/// it. Hand-maintained alongside the actual features — there's no
/// automated link to the code, so a renamed screen or moved menu item
/// needs its entry updated here too.
class GuideEntry {
  const GuideEntry({
    required this.icon,
    required this.title,
    required this.whatItDoes,
    required this.howToUse,
    required this.location,
  });

  final IconData icon;
  final String title;
  final String whatItDoes;
  final String howToUse;

  /// Where to find it, e.g. "More → Accounts → +".
  final String location;
}

class GuideSection {
  const GuideSection(this.title, this.entries);

  final String title;
  final List<GuideEntry> entries;
}

/// Basic/Medium/Pro isn't a per-feature toggle — it's a single tier that
/// changes what the rest of the app even shows. Kept separate from
/// [guideSections] so [GuideScreen] can give it a dedicated explanation up
/// top instead of burying it as one more expandable row.
const appModeGuide = <({
  IconData icon,
  String title,
  String description,
})>[
  (
    icon: Icons.receipt_long_outlined,
    title: 'Basic',
    description:
        'Just transactions, and people you owe or are owed by. No '
        'accounts, no balances, no budgets, no net worth — for tracking '
        'spending without setting up a full ledger.',
  ),
  (
    icon: Icons.account_balance_wallet_outlined,
    title: 'Medium (default)',
    description:
        'Everything in Basic, plus accounts (cash, bank, cards, loans, '
        'goals), account balances, net worth, and category budgets. The '
        'full app, minus envelope-style budgeting.',
  ),
  (
    icon: Icons.mail_outline_rounded,
    title: 'Pro',
    description:
        'Everything in Medium, plus Ready to Assign — every account\'s '
        'money pools into one figure you assign to categories before '
        'spending it, classic envelope budgeting — and budget Rollover '
        '(carry unspent budget forward) and Overflow (redirect one '
        'category\'s overspend to another).',
  ),
];

const guideSections = <GuideSection>[
  GuideSection('Money', [
    GuideEntry(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Accounts',
      whatItDoes:
          'Every place your money actually lives: cash, bank accounts, '
          'debit/credit cards, prepaid balances, and multi-currency '
          'accounts. Each can carry an optional minimum-balance floor '
          'that flags — never blocks — a transaction that would take it '
          'below that line.',
      howToUse:
          'Add one from the + button on the Accounts screen. Pick a type, '
          'a colour/icon, an opening balance, and (for a non-home '
          "currency) which currency it's in — that's locked in once the "
          'first transaction posts.',
      location: 'More → Accounts → +',
    ),
    GuideEntry(
      icon: Icons.receipt_long_outlined,
      title: 'Transactions',
      whatItDoes:
          'Every income, expense, transfer and lending movement you\'ve '
          'logged, searchable and filterable by date, ISO week, account, '
          'or "linked" status.',
      howToUse:
          'Log one from the ➕ on any main screen. Long-press an existing '
          'one for Duplicate / Edit / Delete, or open it and tap the '
          'refresh icon to turn it into a recurring Auto rule pre-filled '
          'with its details.',
      location: 'More → Transactions',
    ),
    GuideEntry(
      icon: Icons.people_alt_outlined,
      title: 'Persons',
      whatItDoes:
          'Tracks who owes you and who you owe, kept separate from your '
          'own accounts — lending someone money isn\'t an expense, and '
          'being repaid isn\'t income.',
      howToUse:
          'Open a person to log a lend/borrow entry or a repayment, and '
          'share their whole ledger as a PDF. Settings → Payment Support '
          'can turn on paying a person offline through the *99# USSD menu '
          'when there\'s no data signal.',
      location: 'More → Persons',
    ),
    GuideEntry(
      icon: Icons.donut_large_rounded,
      title: 'Budgets',
      whatItDoes:
          'A spending limit per category, tracked against what\'s '
          'actually been spent this period — Medium and Pro only, Basic '
          'has no concept of a budget at all.',
      howToUse:
          'Set one from a category\'s budget field. Pro adds Rollover '
          '(carry unspent budget into the next period) and Overflow '
          '(redirect one category\'s overspend into another) as optional '
          'per-budget settings.',
      location: 'More → Budgets',
    ),
    GuideEntry(
      icon: Icons.savings_outlined,
      title: 'Ready to Assign',
      whatItDoes:
          'Pro-only envelope budgeting: instead of a limit sitting on '
          'each category independently, every on-budget account\'s money '
          'pools into one "Ready to Assign" figure that you distribute '
          'across categories before it\'s spent.',
      howToUse:
          'Turn it on in Settings → Budgeting once you\'re on Pro. The '
          'More hub then shows a Ready to Assign tile with how much is '
          'still unassigned.',
      location: 'Settings → Budgeting (Pro only)',
    ),
    GuideEntry(
      icon: Icons.autorenew_rounded,
      title: 'Auto (recurring rules)',
      whatItDoes:
          'Rules that post themselves on schedule instead of you logging '
          'them by hand: a fixed expense or income, a transfer into a '
          'savings goal, or an EMI into a loan.',
      howToUse:
          'Add one with a frequency (daily/weekly/biweekly/monthly/'
          'yearly), an optional promo price for the first few '
          'occurrences, and reminders before it\'s due. "Pay early" posts '
          'it today instead of waiting for the due date.',
      location: 'More → Auto → +',
    ),
    GuideEntry(
      icon: Icons.storefront_outlined,
      title: 'Payees',
      whatItDoes:
          'Every name typed into a transaction\'s payee field, grouped '
          'automatically — there\'s no separate payee list to maintain.',
      howToUse:
          'Type a payee while logging an expense/income and it shows up '
          'here on its own, with its net flow (paid vs. received) and a '
          'link back to its full transaction history.',
      location: 'More → Payees',
    ),
    GuideEntry(
      icon: Icons.savings_outlined,
      title: 'Goals & Loans',
      whatItDoes:
          'Savings goals track progress toward a target amount, '
          'optionally auto-funded from an account. Loans track what you '
          'owe — and, once you tell it the interest rate, tenure and '
          'start date, XPENC computes the EMI itself, splits every '
          'payment into interest vs. principal automatically (a plain '
          'payment or a recurring EMI, either way), and shows how much '
          'paying extra actually saves you in interest.',
      howToUse:
          'Add a goal or loan from the + on the Goals & Loans tab. For a '
          'loan, fill in the rate/tenure/start date to unlock the full '
          'tracking — leave them blank for a plain balance-only loan. '
          '"Make a payment" lets you backdate the date/time and shows the '
          'interest/principal/extra breakdown as you type.',
      location: 'More → Goals & Loans',
    ),
    GuideEntry(
      icon: Icons.checklist_outlined,
      title: 'Shopping List',
      whatItDoes:
          'Plan purchases before you make them — named lists (e.g. '
          '"Groceries") with items you check off, kept separate from your '
          'actual transactions until you decide to log them.',
      howToUse: 'Create a list, add items, tick them off as you shop.',
      location: 'More → Shopping List',
    ),
  ]),
  GuideSection('Insights', [
    GuideEntry(
      icon: Icons.calendar_month_outlined,
      title: 'Calendar & Reminders',
      whatItDoes:
          'A day-by-day view of what came in and went out, plus upcoming '
          'recurring payments so nothing catches you off guard.',
      howToUse: 'Tap any day to see that day\'s transactions.',
      location: 'More → Calendar & Reminders',
    ),
    GuideEntry(
      icon: Icons.insights_outlined,
      title: 'Stats',
      whatItDoes:
          'Trends over time, spending-by-category charts, and Standings — '
          'a ranked top-transactions/top-categories list for the period.',
      howToUse:
          'Switch periods from the top of the screen; tap any category '
          'slice or Standings row to jump into its own detail.',
      location: 'More → Stats',
    ),
    GuideEntry(
      icon: Icons.account_balance_outlined,
      title: 'Account Reports',
      whatItDoes:
          'A money-first view across every account: total net worth, how '
          'it\'s split across accounts (as a pie chart), and a tappable '
          'list to drill into any one.',
      howToUse: 'Tap an account\'s slice or row to open its own statement.',
      location: 'More → Account Reports',
    ),
  ]),
  GuideSection('Data', [
    GuideEntry(
      icon: Icons.download_outlined,
      title: 'Download Data',
      whatItDoes:
          'Exports your whole ledger to CSV or JSON — for a spreadsheet, '
          'a backup you keep yourself, or moving your data elsewhere.',
      howToUse: 'Pick a format and share/save the resulting file.',
      location: 'More → Download Data',
    ),
    GuideEntry(
      icon: Icons.backup_outlined,
      title: 'Backup & Restore',
      whatItDoes:
          'Manual backups plus scheduled auto-backups, with a choice of '
          'retention rule (keep the last N, or a time window). Restoring '
          'replaces the current ledger with a backup\'s contents — the '
          'safety net for switching phones or undoing a mistake.',
      howToUse:
          'Back up any time from this screen; auto-backups run on their '
          'own schedule once turned on. Long-press to batch-select '
          'several backups to delete at once.',
      location: 'More → Backup & Restore',
    ),
  ]),
  GuideSection('Setup', [
    GuideEntry(
      icon: Icons.category_outlined,
      title: 'Categories',
      whatItDoes:
          'Income and expense categories, each with its own icon and '
          'colour, picked from a searchable icon sheet.',
      howToUse:
          'Save your whole category structure as a named template and '
          'switch between saved templates any time — switching never '
          'touches a transaction.',
      location: 'More → Categories',
    ),
    GuideEntry(
      icon: Icons.sell_outlined,
      title: 'Tags',
      whatItDoes:
          'Labels that cut across categories — a tag isn\'t tied to '
          'income or expense, so it can mark anything that shares a '
          'context (e.g. "Trip to Goa").',
      howToUse:
          'Tag groups bundle tags that always go together (e.g. "Work '
          'trip" = Travel + Meals) so you pick the whole set at once from '
          'the tag picker.',
      location: 'More → Tags',
    ),
    GuideEntry(
      icon: Icons.settings_outlined,
      title: 'Settings',
      whatItDoes:
          'Currency, theme, security (PIN, master password, and/or an '
          'authenticator app — any combination you turn on unlocks the '
          'app), notifications, the app mode (Basic/Medium/Pro), budget '
          'cycle start day, and which tabs show in the bottom nav.',
      howToUse: 'Everything here takes effect immediately, no save button.',
      location: 'More → Settings',
    ),
  ]),
];
