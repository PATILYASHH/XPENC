import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/payments/cashapp_launcher.dart';
import '../../core/payments/paypal_launcher.dart';
import '../../core/payments/revolut_launcher.dart';
import '../../core/payments/upi_launcher.dart';
import '../../core/payments/venmo_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/beta_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'edit_person_sheet.dart';
import 'payment_action_row.dart' show PaymentMethodSpec;
import '../../core/l10n/l10n.dart';

/// Whether a person's page offers Pay / Request at all: there's a balance
/// to settle and at least one payment method is switched on (Settings →
/// Persons).
bool personPayAvailable(WidgetRef ref, Money balance) =>
    !balance.isZero &&
    (ref.watch(upiEnabledProvider) ||
        ref.watch(paypalEnabledProvider) ||
        ref.watch(venmoEnabledProvider) ||
        ref.watch(cashappEnabledProvider) ||
        ref.watch(revolutEnabledProvider));

/// The person page's top-bar Pay / Request button — Request when they owe
/// you, Pay when you owe them. Nothing when there's nothing to settle or no
/// payment method is on.
class PersonPayButton extends ConsumerWidget {
  const PersonPayButton({
    required this.person,
    required this.balance,
    super.key,
  });

  final PersonRow person;
  final Money balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!personPayAvailable(ref, balance)) return const SizedBox.shrink();
    return IconButton(
      key: const Key('person-pay'),
      tooltip: balance.isPositive ? tr('Request') : tr('Pay'),
      icon: const AppIcon(Icons.payments_outlined),
      onPressed: () => showPersonPaySheet(context, person, balance),
    );
  }
}

/// UPI, PayPal, Venmo, Cash App, Revolut — whichever are on — for settling
/// [balance] with [person]: requesting it when they owe you, paying it when
/// you owe them. A method that isn't set up yet stays in the list, saying
/// what's missing; tapping it goes to where that's added.
Future<void> showPersonPaySheet(
  BuildContext context,
  PersonRow person,
  Money balance,
) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  // The page's own context goes along: a Glass sheet leaves the tree as it
  // closes, so "add their UPI ID" opens the next sheet from the page.
  builder: (_) =>
      _PaySheet(person: person, balance: balance, pageContext: context),
);

class _PaySheet extends ConsumerWidget {
  const _PaySheet({
    required this.person,
    required this.balance,
    required this.pageContext,
  });

  final PersonRow person;
  final Money balance;
  final BuildContext pageContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final request = balance.isPositive;
    final amount = balance.abs;
    final currencyCode = ref.watch(currencyProvider).code;
    final myUpiName = ref.watch(myUpiNameProvider);
    final myName = (myUpiName?.trim().isNotEmpty ?? false)
        ? myUpiName!.trim()
        : tr('XPENC user');

    // Requests go to *my* ids (they pay me); payments to *theirs*.
    final upi = request ? ref.watch(myUpiIdProvider) : person.upiId;
    final paypal = request ? ref.watch(myPaypalProvider) : person.paypal;
    final venmo = request ? ref.watch(myVenmoProvider) : person.venmo;
    final cashapp = request ? ref.watch(myCashappProvider) : person.cashapp;
    final revolut = request ? ref.watch(myRevolutProvider) : person.revolut;

    final methods = <(IconData, PaymentMethodSpec)>[
      if (ref.watch(upiEnabledProvider))
        (
          Icons.currency_rupee_rounded,
          PaymentMethodSpec(
            buttonLabel: 'UPI',
            missingLabel: tr('UPI ID'),
            id: upi,
            attempt: () => UpiLauncher.launch(
              action: request ? UpiAction.collect : UpiAction.pay,
              payeeUpiId: upi!,
              payeeName: request ? myName : person.name,
              amount: amount,
              note: request ? 'Requested via XPENC' : 'Settlement via XPENC',
            ),
          ),
        ),
      if (ref.watch(paypalEnabledProvider))
        (
          FontAwesomeIcons.paypal.data,
          PaymentMethodSpec(
            buttonLabel: tr('PayPal'),
            missingLabel: tr('PayPal.me ID'),
            id: paypal,
            attempt: () => PaypalLauncher.launch(
              paypalId: paypal!,
              amount: amount,
              currencyCode: currencyCode,
            ),
          ),
        ),
      if (ref.watch(venmoEnabledProvider))
        (
          FontAwesomeIcons.venmo.data,
          PaymentMethodSpec(
            buttonLabel: tr('Venmo'),
            missingLabel: tr('Venmo username'),
            id: venmo,
            attempt: () => VenmoLauncher.launch(
              username: venmo!,
              amount: amount,
              note: request ? 'Requested via XPENC' : 'Settlement via XPENC',
            ),
          ),
        ),
      if (ref.watch(cashappEnabledProvider))
        (
          FontAwesomeIcons.cashApp.data,
          PaymentMethodSpec(
            buttonLabel: tr('Cash App'),
            missingLabel: tr('Cashtag'),
            id: cashapp,
            attempt: () =>
                CashAppLauncher.launch(cashtag: cashapp!, amount: amount),
          ),
        ),
      if (ref.watch(revolutEnabledProvider))
        (
          Icons.account_balance_wallet_outlined,
          PaymentMethodSpec(
            buttonLabel: tr('Revolut'),
            missingLabel: tr('Revolut username'),
            id: revolut,
            attempt: () =>
                RevolutLauncher.launch(username: revolut!, amount: amount),
          ),
        ),
    ];

    final color = request ? AppColors.income : AppColors.expense;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20).plusNavBar(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  request
                      ? tr('Request from {0}', [person.name])
                      : tr('Pay {0}', [person.name]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const BetaBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: MoneyText(
              amount,
              color: color,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            request
                ? tr('{0} owes you this. Pick an app to send them a request.', [
                    person.name,
                  ])
                : tr('You owe {0} this. Pick an app to pay them.', [
                    person.name,
                  ]),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < methods.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 64),
                  _methodTile(context, methods[i].$1, methods[i].$2, request),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              'After paying, record it with Settle up so the balance '
              'here matches.',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile(
    BuildContext context,
    IconData icon,
    PaymentMethodSpec method,
    bool request,
  ) {
    final cs = Theme.of(context).colorScheme;
    final ready = method.ready;
    return AppListTile(
      key: Key('pay-method-${method.buttonLabel}'),
      leading: CircleAvatar(
        backgroundColor: cs.secondary.withValues(alpha: ready ? 0.14 : 0.06),
        foregroundColor: ready ? cs.secondary : cs.onSurfaceVariant,
        child: AppIcon(icon, size: 20),
      ),
      title: Text(method.buttonLabel),
      subtitle: Text(
        ready
            ? method.id!.trim()
            : request
            ? tr('Add your {0} in Settings', [method.missingLabel])
            : tr("Add {0}'s {1}", [person.name, method.missingLabel]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: AppIcon(
        ready ? Icons.open_in_new_rounded : Icons.add_circle_outline_rounded,
        size: 20,
      ),
      onTap: () => ready ? _launch(context, method) : _setUp(context, request),
    );
  }

  Future<void> _launch(BuildContext context, PaymentMethodSpec method) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final opened = await method.attempt();
    if (opened) {
      navigator.pop();
      return;
    }
    // No app took the link: the id on the clipboard is the next best thing.
    await Clipboard.setData(ClipboardData(text: method.id!));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr("Couldn't open {0} — copied {1} instead", [
              method.buttonLabel,
              method.missingLabel,
            ]),
          ),
        ),
      );
  }

  /// Mine are added in Settings; theirs on their own page's edit sheet.
  void _setUp(BuildContext context, bool request) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (request) {
      router.push('/more/settings');
      return;
    }
    if (!pageContext.mounted) return;
    showAppSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => EditPersonSheet(person: person),
    );
  }
}
