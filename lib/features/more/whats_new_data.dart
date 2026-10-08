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
    icon: Icons.ios_share_rounded,
    title: 'Share as a PDF or an image',
    location: 'A transaction, person or group → Share',
    description:
        'Pick PDF for a clean, printable document — a receipt for a '
        'transaction, a statement with a running balance for a person, '
        'every expense and who owes whom for a group. Pick Image for a '
        'styled card, dark or light, ready for any chat.',
  ),
  WhatsNewEntry(
    icon: Icons.visibility_off_outlined,
    title: 'Hide a transaction from screenshots',
    location: 'Add or edit a transaction → Hide from screenshots',
    description:
        'Turn it on and the transaction shows as a frosted “Hidden · hold '
        'to view” row everywhere it’s listed, so a screenshot or screen '
        'recording only catches the frost. Hold the row to see it — '
        'screenshots and recordings are blocked while you do, and while '
        'its own page is open.',
  ),
  WhatsNewEntry(
    icon: Icons.dashboard_customize_outlined,
    title: 'Make the Dashboard yours',
    location: 'Settings → General → Customize dashboard',
    description:
        'Drag widgets into the order you want, take off the ones you '
        'don’t, and add new ones: Cash flow, Savings goals, Loans, '
        'Shortcuts, Groups and Shopping lists.',
  ),
  WhatsNewEntry(
    icon: Icons.history_rounded,
    title: 'Look back at any month',
    location: 'Dashboard → month pill',
    description:
        'Pick a past month and the Dashboard shows it as it closed: its '
        'opening and closing balance, account balances and who owed whom '
        'on its last day, and its own transactions.',
  ),
  WhatsNewEntry(
    icon: Icons.shortcut_rounded,
    title: 'Shortcuts to related pages',
    location: 'Accounts, Budgets, Transactions and more',
    description:
        'Every module now has a row of shortcuts to the pages that go '
        'with it — Currency from Accounts, Categories from Budgets, Tags '
        'and Payees from Transactions, and more. On the Dashboard, tap '
        'Total money to pick which accounts count toward it.',
  ),
  WhatsNewEntry(
    icon: Icons.open_in_full_rounded,
    title: 'Glass grows out of what you tap',
    location: 'Glass theme · top bar, Persons, Transactions',
    description:
        'Switch tabs and the top bar resizes to the new tab’s buttons. '
        'Settled, Archived and Inbox grow down out of the top bar; New '
        'group grows out of its button; pages from More open on a calmer '
        'spring. The Transactions filters sit on frosted glass, and a '
        'person’s photo lights their card with its own colour.',
  ),
  WhatsNewEntry(
    icon: Icons.water_drop_outlined,
    title: 'Glass that moves like liquid',
    location: 'Glass theme',
    description:
        'The tab bar now transforms into whatever you open from it: every '
        'sheet and every page in More grows up out of the bar on a spring '
        'and folds back into it when you close it. A quick action makes '
        'the ➕ itself swell into the page. Search on Transactions turns '
        'the top bar into the search field. And the glass takes the light '
        'of what\'s behind it — scroll something colourful under the tab '
        'bar and its edge glows with that colour.',
  ),
  WhatsNewEntry(
    icon: Icons.bolt_rounded,
    title: 'Glass quick actions, and smoother everything',
    location: 'Glass theme · hold ➕ (turn on in Settings → Quick Actions)',
    description:
        'Hold the ➕ and your quick actions spring out onto two arcs in the '
        'corner — slide your thumb to one and let go, and the ➕ swells '
        'into its page. XPENC also runs at your screen’s full refresh '
        'rate now (90/120 Hz where the phone supports it), with calmer, '
        'smoother motion throughout Glass. The top bar is now a floating '
        'glass capsule too: tabs scroll under it to the top of the screen, '
        'the big title flies into it as you scroll, and the tab bar grows '
        'into the month picker. Person photos now show on their '
        'transactions too, Persons scrolls under the bar and its switch, '
        'and hidden amounts turn to frosted glass.',
  ),
  WhatsNewEntry(
    icon: Icons.blur_on_rounded,
    title: 'New themes: Classic, Noir and Glass',
    location: 'Settings → General → Theme',
    description:
        'Glass is Liquid Glass, like iPhone: frosted cards, a floating tab '
        'bar with a sliding glass droplet, large titles under glass '
        'buttons, floating sheets, iOS icons and switches, swipe-back '
        'pages and bouncy scrolling — on a background you pick: Aurora, '
        'White, Black, Ocean, Sunset or Nebula. Noir (was Bold) is heavier and bolder and now has a '
        'light version too. Light, Dark or System is now its own choice. '
        'Colourful, Midnight and Cove are retired; if you used one, you are '
        'on Classic, with your light or dark choice kept.',
  ),
  WhatsNewEntry(
    icon: Icons.storefront_outlined,
    title: 'People as payees',
    location: 'Add expense/income → Payee',
    description:
        'Pick one of your people as the payee — like money given to a '
        'parent that is not coming back. It shows on their page in a small '
        '"As payee" list but never counts toward owe/due. Add people or '
        'payees straight from contacts; someone already saved is reused, '
        'never duplicated. In Payees, "Connect to person" joins a payee to '
        'someone in People.',
  ),
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
