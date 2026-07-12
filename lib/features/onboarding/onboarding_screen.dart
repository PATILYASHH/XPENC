import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/brand_mark.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

const _pageDuration = Duration(milliseconds: 280);

/// First-run wizard. Three buttons-only steps that explain the model, seed the
/// Cash opening balance, and optionally add the user's bank. Nothing is written
/// until the final "Finish" tap, so backing out never leaves a half-set state.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _lastPage = 2;

  final _controller = PageController();
  final _cashCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _last4Ctrl = TextEditingController();
  final _bankBalanceCtrl = TextEditingController();

  int _page = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _cashCtrl.dispose();
    _bankNameCtrl.dispose();
    _last4Ctrl.dispose();
    _bankBalanceCtrl.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_page < _lastPage) {
      _controller.animateToPage(
        _page + 1,
        duration: _pageDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_page > 0) {
      _controller.animateToPage(
        _page - 1,
        duration: _pageDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final bankName = _bankNameCtrl.text.trim();
    final last4 = _last4Ctrl.text.trim();

    // Validate before writing anything so a bad code never half-commits.
    if (bankName.isNotEmpty && last4.isNotEmpty && last4.length != 4) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Last 4 digits must be exactly four digits.'),
          ),
        );
      return;
    }

    setState(() => _submitting = true);
    try {
      final db = ref.read(dbProvider);

      // Step 2 — record cash on hand as an opening-balance income entry into
      // the seeded Cash account. No API updates an account's balance directly.
      final cash = Money.tryParse(_cashCtrl.text);
      if (cash != null && cash.isPositive) {
        final accounts = await ref.read(accountsProvider.future);
        final cashAccounts =
            accounts.where((a) => a.type == AccountType.cash).toList();
        if (cashAccounts.isNotEmpty) {
          final incomeCats =
              await ref.read(categoriesProvider(CategoryKind.income).future);
          CategoryRow? category;
          for (final c in incomeCats) {
            if (c.name == 'Cash') {
              category = c;
              break;
            }
          }
          category ??= incomeCats.isEmpty ? null : incomeCats.first;

          await db.addTransaction(
            type: TxType.income,
            amount: cash,
            accountId: cashAccounts.first.id,
            categoryId: category?.id,
            date: DateTime.now(),
            note: 'Opening balance',
          );
        }
      }

      // Step 3 — optionally add the user's bank.
      if (bankName.isNotEmpty) {
        await db.addAccount(
          name: bankName,
          type: AccountType.bank,
          bankName: bankName,
          last4: last4.isEmpty ? null : last4,
          colorValue: 0xFF2563EB,
          iconKey: 'bank',
          openingBalance:
              Money.tryParse(_bankBalanceCtrl.text) ?? const Money.zero(),
        );
      }

      await db.markOnboarded();
      if (!mounted) return;
      router.go('/dashboard');
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(e.message?.toString() ?? 'Something went wrong.')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomeStep(),
                  _CashStep(controller: _cashCtrl),
                  _BankStep(
                    nameController: _bankNameCtrl,
                    last4Controller: _last4Ctrl,
                    balanceController: _bankBalanceCtrl,
                  ),
                ],
              ),
            ),
            _BottomBar(
              page: _page,
              lastPage: _lastPage,
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

/// Step 1 — plain-language explanation of the model. No inputs.
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
          _feature(
            theme,
            Icons.account_balance_wallet_outlined,
            cs.primary,
            'Accounts are where your money sits: Cash, Bank, Cards.',
          ),
          _feature(
            theme,
            Icons.swap_horiz_rounded,
            AppColors.transfer,
            'A transfer moves money between your own accounts. It is never '
            'income or expense.',
          ),
          _feature(
            theme,
            Icons.lock_outline_rounded,
            cs.primary,
            'Everything stays on this phone.',
          ),
        ],
      ),
    );
  }

  Widget _feature(ThemeData theme, IconData icon, Color color, String text) {
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

/// Step 2 — cash on hand. Optional; 0 is fine. Recorded on Finish as an
/// opening-balance income entry into the Cash account.
class _CashStep extends StatelessWidget {
  const _CashStep({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How much cash do you have right now?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Optional — leave it at 0 if you would rather add it later.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: kTabularFigures,
            ),
            decoration: const InputDecoration(
              labelText: 'Cash on hand',
              prefixText: '₹ ',
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Recorded as opening balance.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 3 — optional bank account. All fields may be left blank. (The last-4
/// digits also feed SMS matching when auto-capture returns.)
class _BankStep extends StatelessWidget {
  const _BankStep({
    required this.nameController,
    required this.last4Controller,
    required this.balanceController,
  });

  final TextEditingController nameController;
  final TextEditingController last4Controller;
  final TextEditingController balanceController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add your bank',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add the account your money actually sits in.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Bank name',
              hintText: 'e.g. India Post Payments Bank',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: last4Controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Last 4 digits',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Opening balance',
              prefixText: '₹ ',
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Leave blank to skip. You can add accounts any time.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page dots + Back / Next(Finish) controls, fixed above the keyboard.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.lastPage,
    required this.submitting,
    required this.onNext,
    required this.onBack,
  });

  final int page;
  final int lastPage;
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
              FilledButton(
                onPressed: submitting ? null : onNext,
                style: FilledButton.styleFrom(
                  // The app theme sets `minimumSize: Size.fromHeight(56)` — an
                  // INFINITE minimum width. A Row hands its non-flex children
                  // unbounded width, so that pairing throws at layout time.
                  // Any FilledButton inside a Row must constrain its width.
                  minimumSize: const Size(96, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Text(isLast ? 'Finish' : 'Next'),
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
