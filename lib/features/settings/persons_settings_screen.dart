import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'settings_common.dart';

/// Persons — how repayments post, and the payment methods & personal IDs
/// used to request money from someone who owes you. A method's enable
/// switch sits right above its own ID field so turning one on and filling
/// it in is a single scroll stop, not two separate cards.
class PersonsSettingsScreen extends ConsumerWidget {
  const PersonsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final countRepaymentsAsIncome = ref.watch(countRepaymentsAsIncomeProvider);
    final myUpiId = ref.watch(myUpiIdProvider);
    final myUpiName = ref.watch(myUpiNameProvider);
    final myPaypal = ref.watch(myPaypalProvider);
    final myVenmo = ref.watch(myVenmoProvider);
    final myCashapp = ref.watch(myCashappProvider);
    final myRevolut = ref.watch(myRevolutProvider);
    final upiEnabled = ref.watch(upiEnabledProvider);
    final ussdPayEnabled = ref.watch(ussdPayEnabledProvider);
    final paypalEnabled = ref.watch(paypalEnabledProvider);
    final venmoEnabled = ref.watch(venmoEnabledProvider);
    final cashappEnabled = ref.watch(cashappEnabledProvider);
    final revolutEnabled = ref.watch(revolutEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Persons')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.handshake_outlined),
              title: const Text('Count repayments as income'),
              subtitle: Text(
                'Offers "Mark as repaid" on a person\'s page — a repayment '
                'posts as income under a category you choose, instead of '
                'staying off income/expense like lending normally does.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              value: countRepaymentsAsIncome,
              onChanged: (v) =>
                  ref.read(dbProvider).setCountRepaymentsAsIncome(v),
            ),
          ),

          settingsSectionLabel(context, 'Payment methods'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Turn off any method not used or supported where you are — '
                'it disappears from person pages instead of sitting there '
                'disabled. Turn one on to fill in your own ID for it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('UPI'),
                  subtitle: const Text('India'),
                  value: upiEnabled,
                  onChanged: (v) => ref.read(dbProvider).setUpiEnabled(v),
                ),
                if (upiEnabled) ...[
                  Divider(height: 1, indent: 16, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.qr_code_outlined),
                    title: const Text('My UPI ID'),
                    subtitle: Text(
                      (myUpiId?.isNotEmpty ?? false)
                          ? myUpiId!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyUpiDialog(
                      context,
                      ref,
                      currentId: myUpiId,
                      currentName: myUpiName,
                    ),
                  ),
                  Divider(height: 1, indent: 16, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 16, right: 8),
                    title: const Text('Pay without internet (Beta)'),
                    subtitle: const Text(
                      'Send via *99# USSD when you have no data — tap for '
                      'how it works',
                    ),
                    onTap: () => _showUssdPayInfoSheet(context),
                    trailing: Switch(
                      value: ussdPayEnabled,
                      onChanged: (v) =>
                          ref.read(dbProvider).setUssdPayEnabled(v),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('PayPal'),
                  subtitle: const Text('Worldwide'),
                  value: paypalEnabled,
                  onChanged: (v) => ref.read(dbProvider).setPaypalEnabled(v),
                ),
                if (paypalEnabled) ...[
                  Divider(height: 1, indent: 16, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('My PayPal.me ID'),
                    subtitle: Text(
                      (myPaypal?.isNotEmpty ?? false)
                          ? myPaypal!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyIdDialog(
                      context,
                      ref,
                      title: 'My PayPal.me ID',
                      hintText: 'e.g. yourname',
                      currentId: myPaypal,
                      onSave: (id) => ref.read(dbProvider).setMyPaypal(id),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Venmo'),
                  subtitle: const Text('US'),
                  value: venmoEnabled,
                  onChanged: (v) => ref.read(dbProvider).setVenmoEnabled(v),
                ),
                if (venmoEnabled) ...[
                  Divider(height: 1, indent: 16, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('My Venmo username'),
                    subtitle: Text(
                      (myVenmo?.isNotEmpty ?? false)
                          ? myVenmo!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you (US)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyIdDialog(
                      context,
                      ref,
                      title: 'My Venmo username',
                      hintText: 'e.g. rahul',
                      currentId: myVenmo,
                      onSave: (id) => ref.read(dbProvider).setMyVenmo(id),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Cash App'),
                  subtitle: const Text('US'),
                  value: cashappEnabled,
                  onChanged: (v) => ref.read(dbProvider).setCashappEnabled(v),
                ),
                if (cashappEnabled) ...[
                  Divider(height: 1, indent: 16, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('My Cash App cashtag'),
                    subtitle: Text(
                      (myCashapp?.isNotEmpty ?? false)
                          ? myCashapp!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you (US)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyIdDialog(
                      context,
                      ref,
                      title: 'My Cash App cashtag',
                      hintText: r'e.g. $rahul',
                      currentId: myCashapp,
                      onSave: (id) => ref.read(dbProvider).setMyCashapp(id),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Revolut'),
                  subtitle: const Text('Europe'),
                  value: revolutEnabled,
                  onChanged: (v) => ref.read(dbProvider).setRevolutEnabled(v),
                ),
                if (revolutEnabled) ...[
                  Divider(height: 1, indent: 16, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('My Revolut.me username'),
                    subtitle: Text(
                      (myRevolut?.isNotEmpty ?? false)
                          ? myRevolut!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you (Europe)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyIdDialog(
                      context,
                      ref,
                      title: 'My Revolut.me username',
                      hintText: 'e.g. rahul',
                      currentId: myRevolut,
                      onSave: (id) => ref.read(dbProvider).setMyRevolut(id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Explains *99# before anyone turns the beta on: what it is, what XPENC
  /// can and can't automate, and what actually happens when they use it.
  Future<void> _showUssdPayInfoSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetContext).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pay without internet (Beta)',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '*99# is NPCI\'s USSD banking service — it sends a UPI '
                'payment over your SIM\'s signal alone, no data connection '
                'needed, on almost any phone.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'XPENC can\'t read or answer the *99# menu for you — that '
                'screen belongs to your phone\'s own dialer, not any app. '
                'What this does instead:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '1. You enter who you\'re paying (UPI ID or phone number).\n'
                '2. Tap Dial *99# — XPENC copies it and opens your dialer, '
                'ready to call.\n'
                '3. You go through the menu yourself: Send Money → paste → '
                'amount → UPI PIN.\n'
                '4. Back in XPENC, log it as a normal transaction.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMyUpiDialog(
    BuildContext context,
    WidgetRef ref, {
    required String? currentId,
    required String? currentName,
  }) async {
    final result = await showDialog<({String id, String name})>(
      context: context,
      builder: (_) =>
          _MyUpiDialog(currentId: currentId, currentName: currentName),
    );
    if (result == null) return;

    final db = ref.read(dbProvider);
    await db.setMyUpiId(result.id.trim().isEmpty ? null : result.id.trim());
    await db.setMyUpiName(
      result.name.trim().isEmpty ? null : result.name.trim(),
    );
  }

  /// Shared single-field "my own payment id" dialog, used by every method
  /// after UPI (which also needs a display name, so keeps its own dialog).
  Future<void> _showMyIdDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String hintText,
    required String? currentId,
    required Future<void> Function(String? id) onSave,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _MyIdDialog(title: title, hintText: hintText, currentId: currentId),
    );
    if (result == null) return;

    final id = result.trim();
    await onSave(id.isEmpty ? null : id);
  }
}

/// A `StatefulWidget`, not bare controllers disposed right after
/// `showDialog` resolves — that races the dialog's own closing animation:
/// the route pops (resolving the `Future`) before the still-visible
/// `TextField`s finish their exit transition, so controllers disposed
/// immediately can be torn down while still attached to them. Owning them
/// in `State.dispose()` ties their lifetime to the framework's own unmount
/// timing instead, which is always correct.
class _MyUpiDialog extends StatefulWidget {
  const _MyUpiDialog({required this.currentId, required this.currentName});

  final String? currentId;
  final String? currentName;

  @override
  State<_MyUpiDialog> createState() => _MyUpiDialogState();
}

class _MyUpiDialogState extends State<_MyUpiDialog> {
  late final _idController = TextEditingController(
    text: widget.currentId ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.currentName ?? '',
  );

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('My UPI ID'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _idController,
            autofocus: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              hintText: 'e.g. you@okhdfcbank',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              hintText: 'Shown to whoever pays your request',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop((id: _idController.text, name: _nameController.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Same disposal-timing fix as [_MyUpiDialog], for the shared single-field
/// "my own payment id" dialog every method after UPI uses.
class _MyIdDialog extends StatefulWidget {
  const _MyIdDialog({
    required this.title,
    required this.hintText,
    required this.currentId,
  });

  final String title;
  final String hintText;
  final String? currentId;

  @override
  State<_MyIdDialog> createState() => _MyIdDialogState();
}

class _MyIdDialogState extends State<_MyIdDialog> {
  late final _controller = TextEditingController(text: widget.currentId ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: widget.title,
          hintText: widget.hintText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
