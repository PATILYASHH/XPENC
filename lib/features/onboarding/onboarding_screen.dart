import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/brand_mark.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show AppMode;
import '../data_export/backup_service.dart' show backupAppFolder;

const _pageDuration = Duration(milliseconds: 280);

enum _UserPath { newUser, oldUser }

/// First-run wizard. Welcome, then a fork: new users get a short guided tour
/// (NU1–NU6), returning users get a restore-or-skip screen (OU1–OU2).
/// Purely explanatory — no data is written until the final "Get Started" /
/// "Continue" tap (just [AppDatabase.markOnboarded]), or the explicit
/// restore action on OU1. Currency, opening balances and accounts are all
/// left to their normal in-app flows after onboarding; the app already
/// seeds a ₹0 Cash account and a default currency on a fresh install, so
/// nothing here is required for the app to be usable.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();

  int _page = 0;
  _UserPath? _path;
  bool _submitting = false;
  bool _restoring = false;

  /// The mode chosen on [_EnvelopeModeStep] (new-user path only) — written
  /// via [AppDatabase.setAppMode] in [_finishOnboarding]. Pre-selected to
  /// `medium` so tapping isn't required to proceed, matching
  /// `Settings.appMode`'s schema default.
  AppMode _chosenMode = AppMode.medium;

  /// Only [_Welcome] and [_PathChoice] exist until a path is chosen — after
  /// that the branch's pages are appended. Index 2 is always the first page
  /// of whichever branch is active, and the last index is always that
  /// branch's closing greeting.
  List<Widget> get _pages => [
    _WelcomeStep(),
    _PathChoiceStep(onChoose: _choosePath),
    ...switch (_path) {
      null => const <Widget>[],
      _UserPath.newUser => [
        _EnvelopeModeStep(
          selected: _chosenMode,
          onChoose: _chooseMode,
          onSkip: _skipToEnd,
        ),
        _AccountsStep(onSkip: _skipToEnd),
        _PersonsGroupsStep(onSkip: _skipToEnd),
        _AutoGoalsLoansStep(onSkip: _skipToEnd),
        _PayeesBudgetsSecurityStep(onSkip: _skipToEnd),
        const _StartStep(),
      ],
      _UserPath.oldUser => [
        _RestoreStep(
          onSkip: _skipToEnd,
          onRestore: _restoreFromDevice,
          restoring: _restoring,
        ),
        const _WelcomeBackStep(),
      ],
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _choosePath(_UserPath path) {
    FocusScope.of(context).unfocus();
    setState(() => _path = path);
    _controller.animateToPage(
      2,
      duration: _pageDuration,
      curve: Curves.easeInOut,
    );
  }

  void _chooseMode(AppMode mode) => setState(() => _chosenMode = mode);

  void _next() {
    FocusScope.of(context).unfocus();
    if (_page < _pages.length - 1) {
      _controller.animateToPage(
        _page + 1,
        duration: _pageDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_page == 0) return;
    if (_page == 2) {
      // Leaving the chosen branch back to the fork — reset so the page
      // list collapses back to [Welcome, PathChoice] and indices stay valid.
      setState(() => _path = null);
    }
    _controller.animateToPage(
      _page - 1,
      duration: _pageDuration,
      curve: Curves.easeInOut,
    );
  }

  void _skipToEnd() {
    FocusScope.of(context).unfocus();
    _controller.animateToPage(
      _pages.length - 1,
      duration: _pageDuration,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() => _submitting = true);
    try {
      final db = ref.read(dbProvider);
      await db.markOnboarded();
      // Old-user path already got its tier from the `from < 72` migration
      // backfill (Pro if any account was already in Envelope Mode, else
      // Medium) before onboarding ever ran — only a fresh new-user choice
      // overwrites it here.
      if (_path == _UserPath.newUser) {
        await db.setAppMode(_chosenMode);
      }
      if (!mounted) return;
      router.go('/dashboard');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
    }
  }

  /// Explicit restore, triggered only by the user's tap on [_RestoreStep] —
  /// unlike the old auto-detect dialog, nothing here runs on page load.
  /// [BackupService.resyncFromDevice] is what actually asks for folder
  /// access and rebuilds the local backup index; the newest record (backup
  /// list is newest-first) is then restored.
  Future<void> _restoreFromDevice() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final service = ref.read(backupServiceProvider);
    final db = ref.read(dbProvider);

    setState(() => _restoring = true);
    try {
      final foundCount = await service.resyncFromDevice();
      if (foundCount == null || foundCount == 0) {
        if (!mounted) return;
        setState(() => _restoring = false);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Couldn't find a backup on this phone."),
            ),
          );
        return;
      }
      final records = await service.listBackups();
      if (records.isEmpty) {
        if (!mounted) return;
        setState(() => _restoring = false);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Couldn't find a backup on this phone."),
            ),
          );
        return;
      }
      await service.restoreBackup(records.first);
      // The restored settings row carries its own `onboarded` flag, which is
      // already true on any backup ever taken post-onboarding — set it
      // explicitly anyway so a malformed or pre-onboarding backup can never
      // strand the user back on this screen.
      await db.markOnboarded();
      if (!mounted) return;
      router.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoring = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't restore: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final page = _page.clamp(0, pages.length - 1);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            _BottomBar(
              page: page,
              lastPage: pages.length - 1,
              showNext: page != 1,
              finishLabel: _path == _UserPath.oldUser ? 'Continue' : 'Get Started',
              submitting: _submitting,
              onNext: _next,
              onBack: _back,
            ),
          ],
        ),
      ),
    );
  }
}

/// A reusable icon + short explanation row, used on the Welcome step and
/// every guided-tour step.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared chrome for every guided-tour / OU step: an optional top-right
/// Skip, a headline, a subtitle, a list of [_FeatureRow]s, and an optional
/// trailing call-to-action (used by [_RestoreStep]'s restore button).
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.rows,
    this.onSkip,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<Widget> rows;
  final VoidCallback? onSkip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onSkip != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onSkip, child: const Text('Skip')),
            )
          else
            const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 28),
            child: Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: trailing,
            ),
        ],
      ),
    );
  }
}

/// Page 1 — app/project blurb, no inputs.
class _WelcomeStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 64),
          const SizedBox(height: 22),
          const BrandWordmark(fontSize: 36),
          const SizedBox(height: 10),
          Text(
            'Track where your money is — simply and privately.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),
          _FeatureRow(
            icon: Icons.lock_outline_rounded,
            color: cs.primary,
            text: 'Open-source and private — everything stays on this phone.',
          ),
          _FeatureRow(
            icon: Icons.wifi_off_rounded,
            color: cs.primary,
            text: 'Works fully offline. No account, no server, no ads.',
          ),
          _FeatureRow(
            icon: Icons.code_rounded,
            color: AppColors.transfer,
            text: 'Built and maintained by Yash Patil (PATILYASHH).',
          ),
        ],
      ),
    );
  }
}

/// Page 2 — the fork. Tapping a card both selects the path and advances;
/// there's no separate Next here (the bottom bar hides Next on this page).
class _PathChoiceStep extends StatelessWidget {
  const _PathChoiceStep({required this.onChoose});

  final ValueChanged<_UserPath> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you new to XPENC?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "We'll tailor the next few screens to your answer.",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _ChoiceCard(
            icon: Icons.auto_awesome_outlined,
            title: "I'm new here",
            subtitle: 'Show me a quick tour of how XPENC works.',
            onTap: () => onChoose(_UserPath.newUser),
          ),
          const SizedBox(height: 14),
          _ChoiceCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'I already know XPENC',
            subtitle: 'Skip the tour, and restore a backup if I have one.',
            onTap: () => onChoose(_UserPath.oldUser),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// NU1 — pick a tier (see [AppMode]). Pre-selects Medium so tapping isn't
/// required to proceed; the choice can be changed any time in Settings.
class _EnvelopeModeStep extends StatelessWidget {
  const _EnvelopeModeStep({
    required this.selected,
    required this.onChoose,
    required this.onSkip,
  });

  final AppMode selected;
  final ValueChanged<AppMode> onChoose;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      onSkip: onSkip,
      title: 'How do you want to track money?',
      subtitle: 'You can change this any time in Settings.',
      rows: [
        _ModeCard(
          icon: Icons.receipt_long_outlined,
          title: 'Basic',
          subtitle: 'Just transactions, and people you owe or are owed by.',
          selected: selected == AppMode.basic,
          onTap: () => onChoose(AppMode.basic),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Medium',
          subtitle:
              'Adds accounts, budgets and net worth — the full app, without '
              'envelope budgeting.',
          selected: selected == AppMode.medium,
          onTap: () => onChoose(AppMode.medium),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.mail_outline_rounded,
          title: 'Pro',
          subtitle:
              'Adds Envelope mode — assign money to categories from a '
              'shared "Ready to Assign" pool before you spend it — plus '
              'budget rollover.',
          selected: selected == AppMode.pro,
          onTap: () => onChoose(AppMode.pro),
        ),
      ],
    );
  }
}

/// A tappable tier choice on [_EnvelopeModeStep] — like [_ChoiceCard] but
/// stays on the same page and shows a persistent selected state instead of
/// advancing on tap.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = selected ? cs.onPrimaryContainer : cs.primary;

    return Material(
      color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: fg, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.85)
                            : cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? cs.onPrimaryContainer : cs.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// NU2 — accounts.
class _AccountsStep extends StatelessWidget {
  const _AccountsStep({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _StepScaffold(
      onSkip: onSkip,
      title: 'Accounts hold your money',
      subtitle: 'Cash, bank, cards, loans — each is its own account.',
      rows: [
        _FeatureRow(
          icon: Icons.account_balance_outlined,
          color: cs.primary,
          text:
              'Cash, Bank, Card, Pay Later, Prepaid, Goal and Loan accounts '
              'are all supported.',
        ),
        _FeatureRow(
          icon: Icons.add_circle_outline_rounded,
          color: cs.primary,
          text: 'Add one any time from the Accounts tab — a Cash account is already set up for you.',
        ),
        _FeatureRow(
          icon: Icons.swap_horiz_rounded,
          color: AppColors.transfer,
          text:
              'Balances only change from transactions and transfers — never edited directly.',
        ),
      ],
    );
  }
}

/// NU3 — persons and groups.
class _PersonsGroupsStep extends StatelessWidget {
  const _PersonsGroupsStep({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _StepScaffold(
      onSkip: onSkip,
      title: 'Split money with people',
      subtitle: 'Track what you owe, and what\'s owed to you.',
      rows: [
        _FeatureRow(
          icon: Icons.person_outline_rounded,
          color: cs.primary,
          text: 'Persons track a running balance of who owes whom.',
        ),
        _FeatureRow(
          icon: Icons.group_outlined,
          color: cs.primary,
          text: 'Groups split one expense across several people at once.',
        ),
        _FeatureRow(
          icon: Icons.handshake_outlined,
          color: AppColors.transfer,
          text: 'Settle up with a payment whenever you\'re ready.',
        ),
      ],
    );
  }
}

/// NU4 — auto, goals & loans.
class _AutoGoalsLoansStep extends StatelessWidget {
  const _AutoGoalsLoansStep({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _StepScaffold(
      onSkip: onSkip,
      title: 'Automate the boring parts',
      subtitle: 'Recurring payments, savings targets, and loans.',
      rows: [
        _FeatureRow(
          icon: Icons.autorenew_rounded,
          color: cs.primary,
          text:
              'Auto rules capture recurring transactions and can read '
              'bank SMS/notifications for you.',
        ),
        _FeatureRow(
          icon: Icons.flag_outlined,
          color: cs.primary,
          text: 'Goals are savings targets you fund a little at a time.',
        ),
        _FeatureRow(
          icon: Icons.request_quote_outlined,
          color: AppColors.transfer,
          text:
              'Loans are real liabilities — funded and repaid through '
              'transfers, never counted as income or expense.',
        ),
      ],
    );
  }
}

/// NU5 — payees, budgets & security.
class _PayeesBudgetsSecurityStep extends StatelessWidget {
  const _PayeesBudgetsSecurityStep({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _StepScaffold(
      onSkip: onSkip,
      title: 'Stay organized and safe',
      subtitle: 'Who you pay, how much you plan to spend, and who can get in.',
      rows: [
        _FeatureRow(
          icon: Icons.storefront_outlined,
          color: cs.primary,
          text: 'Payees track where your money goes — useful in reports.',
        ),
        _FeatureRow(
          icon: Icons.pie_chart_outline_rounded,
          color: cs.primary,
          text: 'Budgets set a monthly spending cap per category.',
        ),
        _FeatureRow(
          icon: Icons.lock_outline_rounded,
          color: AppColors.transfer,
          text:
              'A PIN, biometric lock, and master-phrase recovery keep your '
              'data private, even if you lose access.',
        ),
      ],
    );
  }
}

/// NU6 — closing greeting for the new-user path. No Skip (it's the end).
class _StartStep extends StatelessWidget {
  const _StartStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 56),
          const SizedBox(height: 22),
          Text(
            "You're all set",
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add an account from the Accounts tab, or just log your first '
            'transaction — XPENC is ready whenever you are.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// OU1 — explicit restore, replacing the old auto-detect popup. Skip is
/// disabled mid-restore so a tap can't abandon an in-flight restore.
class _RestoreStep extends StatelessWidget {
  const _RestoreStep({
    required this.onSkip,
    required this.onRestore,
    required this.restoring,
  });

  final VoidCallback onSkip;
  final VoidCallback onRestore;
  final bool restoring;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _StepScaffold(
      onSkip: restoring ? null : onSkip,
      title: 'Restore your data?',
      subtitle:
          'If you have an XPENC backup on this phone, restore it now — or '
          'skip and start fresh.',
      rows: [
        _FeatureRow(
          icon: Icons.cloud_download_outlined,
          color: cs.primary,
          text: 'Looks in Download/$backupAppFolder for a backup you made earlier.',
        ),
        _FeatureRow(
          icon: Icons.settings_backup_restore_rounded,
          color: cs.primary,
          text: 'You can always restore later from Settings instead.',
        ),
      ],
      trailing: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: restoring ? null : onRestore,
          icon: restoring
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Icon(Icons.restore_rounded),
          label: Text(restoring ? 'Restoring…' : 'Restore my data'),
        ),
      ),
    );
  }
}

/// OU2 — closing greeting for the returning-user path.
class _WelcomeBackStep extends StatelessWidget {
  const _WelcomeBackStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandMark(size: 56),
          const SizedBox(height: 22),
          Text(
            'Welcome back',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Good to see you again. Let's get you to your dashboard.",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page dots + Back / Next(Get Started) controls, fixed above the keyboard.
/// [showNext] hides the forward button on the fork page, where tapping a
/// choice card advances instead.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.lastPage,
    required this.showNext,
    required this.finishLabel,
    required this.submitting,
    required this.onNext,
    required this.onBack,
  });

  final int page;
  final int lastPage;
  final bool showNext;
  final String finishLabel;
  final bool submitting;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isLast = page == lastPage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dots(count: lastPage + 1, active: page),
          const SizedBox(height: 20),
          Row(
            children: [
              if (page > 0)
                TextButton(
                  onPressed: submitting ? null : onBack,
                  child: const Text('Back'),
                ),
              const Spacer(),
              if (showNext)
                FilledButton(
                  onPressed: submitting ? null : onNext,
                  style: FilledButton.styleFrom(
                    // The app theme sets `minimumSize: Size.fromHeight(56)` — an
                    // INFINITE minimum width. A Row hands its non-flex children
                    // unbounded width, so that pairing throws at layout time.
                    // Any FilledButton inside a Row must constrain its width.
                    minimumSize: const Size(96, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Text(isLast ? finishLabel : 'Next'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small row of page-position dots; the active one is wider and coloured.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: _pageDuration,
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? cs.primary : cs.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
