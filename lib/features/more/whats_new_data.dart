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
    icon: Icons.speed_rounded,
    title: 'XPENC Score',
    location: 'Stats → XPENC Score card',
    description:
        'A 0–100 score for how well you manage money, built from seven '
        'rules: savings rate, living within your means, debt load, repaying '
        'loans and people on time, emergency fund, budgets and how regularly '
        'you track. Tap it for what each rule earned and the top tips to '
        'raise it. Rules for things you do not use, like loans or budgets, '
        'are left out instead of counting against you.',
  ),
  WhatsNewEntry(
    icon: Icons.dashboard_customize_outlined,
    title: 'Stats, organised by topic',
    location: 'Stats',
    description:
        'Stats is now a hub with nine sections, each with its headline '
        'number on the tile: Cash flow, Spending, Income, Net worth, Loans & '
        'debt, People, Savings & goals, Budgets and Recurring. See your '
        'savings rate, income sources, debt-to-income, who owes you, goal '
        'progress, emergency runway and what recurring bills commit each '
        'month.',
  ),
  WhatsNewEntry(
    icon: Icons.contacts_outlined,
    title: 'Add people from your contacts',
    location: 'Persons → Add person, or a group → Add members',
    description:
        'Pick someone from your phone\'s contacts instead of typing them in. '
        'With contacts access allowed, their number and photo come along '
        'too; without it you still get the name.',
  ),
  WhatsNewEntry(
    icon: Icons.verified_user_outlined,
    title: 'See and manage permissions',
    location: 'Settings → Permissions',
    description:
        'Every permission XPENC can use — notifications, camera, contacts — '
        'with what it is for and a switch for each. It also lists what '
        'XPENC never asks for: no internet, no SMS, no location.',
  ),
  WhatsNewEntry(
    icon: Icons.shop_rounded,
    title: 'XPENC is on Google Play',
    location: 'Settings → About',
    description:
        'Open XPENC\'s Play Store page, share it with friends from any app, '
        'or get the latest version from Google Play or F-Droid.',
  ),
  WhatsNewEntry(
    icon: Icons.autorenew_rounded,
    title: 'Auto-pay your EMI when you add a loan',
    location: 'Goals & Loans → Loans → +',
    description:
        'Enter the monthly EMI (or a rate and tenure) and switch on '
        'Auto-pay EMI: pick the account it comes from and the first payment '
        'date, and the EMI shows up in Auto and posts itself every month. '
        'It stops on its own once the loan is paid off — the last payment '
        'is trimmed to exactly what is left.',
  ),
  WhatsNewEntry(
    icon: Icons.insights_rounded,
    title: 'Loan insights',
    location: 'Goals & Loans → a loan → Insights',
    description:
        'See what a loan really costs: how much interest adds on top of '
        'what you borrowed, the balance month by month or the '
        'principal-vs-interest split year by year, and a "What if I pay '
        'extra?" slider showing the new debt-free date, interest saved and '
        'months saved.',
  ),
  WhatsNewEntry(
    icon: Icons.link_rounded,
    title: 'Goals, Loans and Auto, connected',
    location: 'Goals & Loans → a goal or loan',
    description:
        'Each goal and loan now shows the Auto rules paying into it, and '
        'you can set one up right there — pre-filled with the EMI, or with '
        'the monthly amount that reaches a goal by its target date. From an '
        'Auto rule, tap its goal or loan to jump straight to it.',
  ),
  WhatsNewEntry(
    icon: Icons.calendar_month_rounded,
    title: 'Pick a month from the Dashboard top bar',
    location: 'Dashboard → month button in the top bar',
    description:
        'Tap the month in the top bar to jump to any earlier month from a '
        'themed month grid, or straight back to this month. It replaces the '
        '‹ › arrows that used to sit on the income/expense card.',
  ),
  WhatsNewEntry(
    icon: Icons.account_balance_outlined,
    title: 'Loan tab shows everything you owe',
    location: 'Dashboard → net worth card → Loan',
    description:
        'The Loan tab now adds up your loans from the Loans module, pay-later '
        'accounts and what you owe people, with a breakdown under the total. '
        'It used to count pay-later accounts only.',
  ),
  WhatsNewEntry(
    icon: Icons.groups_outlined,
    title: 'Groups show their own split',
    location: 'Persons → Group → a group',
    description:
        'A group now shows only what its own expenses created — a friend who '
        'already owed you individually no longer inflates the hotel bill. '
        'The Individual tab still shows their full total, and a repayment '
        'made on the person settles their group share first.',
  ),
  WhatsNewEntry(
    icon: Icons.no_photography_outlined,
    title: 'Screenshot blocking from the lock screen',
    location: 'Settings → Quick Actions → Lock screen shortcuts',
    description:
        'Turn it on to get a screenshot-blocking button on the lock screen. '
        'Blocking turns on the moment you tap — before you type your PIN — '
        'while turning it off only takes effect after you unlock.',
  ),
  WhatsNewEntry(
    icon: Icons.build_outlined,
    title: 'Fixes',
    location: 'Settings, Transactions',
    description:
        'Settings pages and transaction details now scroll all the way to '
        'the bottom instead of hiding the last items under the navigation '
        'bar, and a long category name in a split transaction wraps inside '
        'its card.',
  ),
];
