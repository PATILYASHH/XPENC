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
];
