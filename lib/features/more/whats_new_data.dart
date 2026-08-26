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
    icon: Icons.groups_outlined,
    title: 'Split group expenses',
    location: 'Persons → Group tab',
    description:
        'Create a group from your people and log a shared expense split '
        'equally, by percentage, or by manual amount. Whoever paid — you or '
        'a group member — the split is computed and recorded automatically, '
        'and each person\'s balance updates right alongside their individual '
        'one.',
  ),
  WhatsNewEntry(
    icon: Icons.currency_rupee_rounded,
    title: 'Pay or Request via UPI (Beta)',
    location: 'Persons → tap a person',
    description:
        'A person\'s page now offers a "Pay" or "Request" button — whichever '
        'way the balance runs — pre-filled with what\'s owed. One tap opens '
        'a UPI intent Android hands to whatever app you have installed. New '
        'edit-person flow too: UPI ID, phone and more, where before there '
        'was only Add, Archive or Remove.',
  ),
  WhatsNewEntry(
    icon: Icons.dashboard_customize_outlined,
    title: 'Customize the bottom nav',
    location: 'Settings → Customize bottom nav',
    description:
        'Pick which two destinations sit next to the ➕ button — '
        'Transactions, Persons, Calendar, Budgets, Accounts, Stats or '
        'Payees. Dashboard and More stay pinned. Labels under each icon can '
        'be turned off too.',
  ),
  WhatsNewEntry(
    icon: Icons.savings_outlined,
    title: 'Goals & Loans hub',
    location: 'More → Goals & Loans',
    description:
        'Savings Goals is now Goals & Loans — the same screen tracks money '
        'you\'ve borrowed as a loan alongside goals you\'re saving toward, '
        'instead of splitting them across two places.',
  ),
  WhatsNewEntry(
    icon: Icons.donut_large_rounded,
    title: 'Interactive dashboard charts',
    location: 'Dashboard → Budgets / Spending',
    description:
        'Tap or hold a wedge to see its name and amount instead of a '
        'permanent legend underneath. A category over its budget now gets a '
        'diagonal hazard-stripe pattern on its wedge, not just a thin ring.',
  ),
  WhatsNewEntry(
    icon: Icons.space_dashboard_outlined,
    title: 'Redesigned dashboard',
    location: 'Dashboard',
    description:
        'The hero card switches between metrics — Total Money, Net Worth — '
        'via tabs, and Budgets/Spending render as pie charts instead of '
        'bars.',
  ),
  WhatsNewEntry(
    icon: Icons.key_outlined,
    title: 'Master recovery phrase',
    location: 'Settings → Security',
    description:
        'Set a 10-word recovery phrase as a backup unlock method, and '
        'choose how many wrong PIN attempts before XPENC asks for it '
        'instead — a real fallback instead of an unlimited-attempts PIN.',
  ),
  WhatsNewEntry(
    icon: Icons.text_fields_rounded,
    title: 'Font settings',
    location: 'Settings → Font',
    description:
        'Adjust text size, boldness and font family app-wide, with a live '
        'preview — for readability, not just as an accessibility '
        'afterthought.',
  ),
  WhatsNewEntry(
    icon: Icons.palette_outlined,
    title: 'Bold theme',
    location: 'Settings → Theme',
    description:
        'A near-black theme with a coral-and-gold accent and Sora/Manrope '
        'typography — bigger, bolder headlines than the other presets.',
  ),
  WhatsNewEntry(
    icon: Icons.link_rounded,
    title: 'Link related transactions',
    location: 'Transactions',
    description:
        'Link two or more transactions together — a refund to its original '
        'purchase, say — and filter the list to only linked transactions '
        'with the new "Linked" chip.',
  ),
  WhatsNewEntry(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Customize Dashboard net worth',
    location: 'Settings → Customize dashboard',
    description:
        'Choose which accounts count toward the Dashboard\'s Net Worth '
        'figure — exclude a loan or goal account you don\'t want pulling '
        'the number around.',
  ),
  WhatsNewEntry(
    icon: Icons.calendar_month_outlined,
    title: 'Calendar day totals',
    location: 'More → Calendar & Reminders',
    description:
        'Selecting a day now shows that day\'s total money in and out — '
        'toggleable in Settings → Calendar.',
  ),
  WhatsNewEntry(
    icon: Icons.call_split_rounded,
    title: 'Split cash change across accounts',
    location: 'Add Transaction',
    description:
        'An expense\'s change can now be split across two accounts instead '
        'of assuming it all went to one — useful when change from a cash '
        'purchase gets split between a wallet and a bank top-up.',
  ),
  WhatsNewEntry(
    icon: Icons.archive_outlined,
    title: 'Archived Auto rules',
    location: 'More → Auto',
    description:
        'A paused recurring rule moves to an Archived list instead of '
        'cluttering the active one — the same pattern Accounts and Persons '
        'already use.',
  ),
  WhatsNewEntry(
    icon: Icons.height_rounded,
    title: 'Bottom spacing setting',
    location: 'Settings → Customize bottom nav → Bottom spacing',
    description:
        'A manual slider that adds clearance above the bottom nav bar and '
        'the PIN lock screen\'s keypad, for phones whose on-screen '
        'navigation buttons don\'t report their own size correctly.',
  ),
];
