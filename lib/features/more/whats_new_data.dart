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
    icon: Icons.percent_rounded,
    title: 'Loan interest tracking',
    location: 'Goals & Loans → a loan',
    description:
        'Give a loan its annual rate, tenure and start date and XPENC '
        'computes the EMI, splits every payment — manual or recurring — '
        'into interest and principal automatically, and shows how much '
        'paying extra actually saves in interest and months.',
  ),
  WhatsNewEntry(
    icon: Icons.event_outlined,
    title: 'Backdate a loan payment, see the extra you paid',
    location: 'Goals & Loans → a loan → Make a payment',
    description:
        'The payment sheet now has its own date/time picker instead of '
        'always posting "now", and breaks out anything paid beyond the '
        'scheduled EMI as a separate "extra" figure.',
  ),
  WhatsNewEntry(
    icon: Icons.menu_book_outlined,
    title: 'Guide',
    location: 'More → Guide',
    description:
        'Every module and feature explained — what it does, how to use '
        'it, where to find it — plus a dedicated breakdown of the '
        'Basic/Medium/Pro app modes and what each tier unlocks.',
  ),
  WhatsNewEntry(
    icon: Icons.event_repeat_rounded,
    title: 'Yearly Auto rules',
    location: 'Auto → add/edit a rule',
    description:
        'A recurring rule can now fire once a year instead of just '
        'daily/weekly/2 weeks/monthly — for annual insurance premiums or '
        'subscriptions. Anchored to both month and day, so Feb 29 behaves '
        'correctly across leap years.',
  ),
  WhatsNewEntry(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Per-account minimum balance',
    location: 'Accounts → an account → menu',
    description:
        'Set an optional floor for an account. Purely informational — '
        'Account Detail flags it when the balance drops below it, and Add '
        'Transaction warns before a transfer/expense would take it there, '
        'but nothing is ever blocked.',
  ),
  WhatsNewEntry(
    icon: Icons.forum_outlined,
    title: 'Community links in About',
    location: 'More → About',
    description:
        'Instagram, WhatsApp Channel, Reddit and the public testimonial/'
        'feedback page are now linked directly from the About screen.',
  ),
];
