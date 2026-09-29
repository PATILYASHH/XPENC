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
    icon: Icons.radio_button_checked_rounded,
    title: 'Quick actions ring',
    location: 'Hold ➕ · set up in Settings → Quick Actions',
    description:
        'Hold the ➕ and a ring of 8 shortcuts opens mid-screen — slide '
        'toward one to open it, or back to ✕ in the centre to cancel. Any '
        'slot can be a screen, a calculator, Add expense/income or a saved '
        'transaction template. Your old 3 shortcuts carry over.',
  ),
  WhatsNewEntry(
    icon: Icons.task_alt_rounded,
    title: 'Settled, instead of vanishing',
    location: 'Persons → ✓ in the top bar',
    description:
        'When someone\'s balance reaches zero, XPENC now asks: Move to '
        'Settled, Archive, or Keep here — nothing disappears on its own. '
        'Settled people and groups keep their history and move back by '
        'themselves the moment money is owed again.',
  ),
  WhatsNewEntry(
    icon: Icons.delete_outline_rounded,
    title: 'Delete a person or group',
    location: 'Persons → hold a person or group → Delete',
    description:
        'Delete now works even with history: every entry and group expense '
        'goes with it, and the money they moved is put back in your '
        'accounts. The confirm dialog says exactly how much will be removed.',
  ),
  WhatsNewEntry(
    icon: Icons.calculate_outlined,
    title: 'Calculators (Beta)',
    location: 'More → Calculators',
    description:
        'FD & RD, Loan EMI with a year-wise schedule and prepayment savings, '
        'SIP & Lumpsum with yearly step-up, PPF, GST, and Income Tax for '
        'India (new vs old regime), the US, the UK and Germany. Results '
        'update as you type.',
  ),
  WhatsNewEntry(
    icon: Icons.tune_rounded,
    title: 'Correct a balance',
    location: 'Accounts → an account → ✎ next to the balance',
    description:
        'App says ₹100 in cash but your wallet has ₹75? Enter what you '
        'really have and the difference is saved as one "Correction" — no '
        'fake expense, and your history stays as it was. Corrections never '
        'count as income or spending, but they lower the XPENC Score\'s '
        'Tracking habit, so logging as you go still pays off.',
  ),
  WhatsNewEntry(
    icon: Icons.account_balance_outlined,
    title: 'Account Reports, rebuilt',
    location: 'More → Account Reports',
    description:
        'Money in and out for any month or year, plus seven reports: '
        'Balances, Activity per account, Balance history for any account, '
        'Transfers between accounts, Payment methods, Cards & pay later '
        '(spent, repaid, next due) and Account health — accounts below zero, '
        'under their minimum or sitting unused.',
  ),
  WhatsNewEntry(
    icon: Icons.history_rounded,
    title: 'Add loans that started years ago',
    location: 'Goals & Loans → Loans → +',
    description:
        'Dates now go back to 2000, and the first auto-payment can start on '
        'the loan\'s own start date — every past EMI is posted the moment '
        'you save, split into interest and principal. Older dates show '
        'their year, so a 2017 payment never looks like this year\'s.',
  ),
  WhatsNewEntry(
    icon: Icons.account_balance_rounded,
    title: 'Loan payments, clearer',
    location: 'Transactions → an EMI',
    description:
        'An EMI\'s interest always gets a category (the loan\'s, the '
        'rule\'s, or EMI), you can name the lender as payee on a loan\'s '
        'Auto rule, and the payment card now says Interest and Principal. '
        'The loan screen no longer shows a "You\'re saving" amount when '
        'you haven\'t paid extra.',
  ),
  WhatsNewEntry(
    icon: Icons.groups_outlined,
    title: 'Who owes whom in a group',
    location: 'Persons → a group → Who owes whom',
    description:
        'Each member\'s net balance, the fewest payments that settle the '
        'group, and every pairwise debt with the expenses behind it. Group '
        'expenses also carry a tappable group tag.',
  ),
  WhatsNewEntry(
    icon: Icons.fullscreen_exit_rounded,
    title: 'Nothing hidden under the nav bar',
    location: 'Every list',
    description:
        'The last item of every list now scrolls clear of Android\'s '
        'gesture bar or buttons, so you can always reach and tap it.',
  ),
];
