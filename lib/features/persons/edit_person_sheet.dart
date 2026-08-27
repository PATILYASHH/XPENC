import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// Opens the "edit person" bottom sheet. There is no add-time equivalent for
/// these fields (`showAddPersonDialog` only collects a name) — this is the
/// only place UPI ID/phone/contact/note ever get set.
Future<void> showEditPersonSheet(
  BuildContext context,
  WidgetRef ref,
  PersonRow person,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => EditPersonSheet(person: person),
  );
}

class EditPersonSheet extends ConsumerStatefulWidget {
  const EditPersonSheet({required this.person, super.key});

  final PersonRow person;

  @override
  ConsumerState<EditPersonSheet> createState() => _EditPersonSheetState();
}

class _EditPersonSheetState extends ConsumerState<EditPersonSheet> {
  late final _nameController = TextEditingController(text: widget.person.name);
  late final _contactController = TextEditingController(
    text: widget.person.contact ?? '',
  );
  late final _noteController = TextEditingController(
    text: widget.person.note ?? '',
  );
  late final _upiIdController = TextEditingController(
    text: widget.person.upiId ?? '',
  );
  late final _paypalController = TextEditingController(
    text: widget.person.paypal ?? '',
  );
  late final _venmoController = TextEditingController(
    text: widget.person.venmo ?? '',
  );
  late final _cashappController = TextEditingController(
    text: widget.person.cashapp ?? '',
  );
  late final _revolutController = TextEditingController(
    text: widget.person.revolut ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.person.phone ?? '',
  );

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _noteController.dispose();
    _upiIdController.dispose();
    _paypalController.dispose();
    _venmoController.dispose();
    _cashappController.dispose();
    _revolutController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give them a name.');
      return;
    }

    setState(() => _saving = true);
    await ref
        .read(dbProvider)
        .updatePerson(
          id: widget.person.id,
          name: name,
          contact: _contactController.text.trim().nullIfEmpty,
          note: _noteController.text.trim().nullIfEmpty,
          upiId: _upiIdController.text.trim().nullIfEmpty,
          phone: _phoneController.text.trim().nullIfEmpty,
          paypal: _paypalController.text.trim().nullIfEmpty,
          venmo: _venmoController.text.trim().nullIfEmpty,
          cashapp: _cashappController.text.trim().nullIfEmpty,
          revolut: _revolutController.text.trim().nullIfEmpty,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upiEnabled = ref.watch(upiEnabledProvider);
    final paypalEnabled = ref.watch(paypalEnabledProvider);
    final venmoEnabled = ref.watch(venmoEnabledProvider);
    final cashappEnabled = ref.watch(cashappEnabledProvider);
    final revolutEnabled = ref.watch(revolutEnabledProvider);
    final anyPaymentMethodEnabled =
        upiEnabled ||
        paypalEnabled ||
        venmoEnabled ||
        cashappEnabled ||
        revolutEnabled;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom:
            MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit person',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Rahul',
              ),
            ),
            const SizedBox(height: 16),

            if (anyPaymentMethodEnabled) ...[
              Text(
                'Payment IDs',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Lets you pay them directly from their page. Not shared "
                "anywhere — stored only on this phone. Turn a method off in "
                "Settings → Payment Support if it doesn't apply here.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              if (upiEnabled) ...[
                TextField(
                  controller: _upiIdController,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID',
                    hintText: 'e.g. rahul@okhdfcbank',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (paypalEnabled) ...[
                TextField(
                  controller: _paypalController,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'PayPal.me ID',
                    hintText: 'e.g. rahul',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (venmoEnabled) ...[
                TextField(
                  controller: _venmoController,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Venmo username',
                    hintText: 'e.g. rahul (US)',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (cashappEnabled) ...[
                TextField(
                  controller: _cashappController,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Cash App cashtag',
                    hintText: r'e.g. $rahul (US)',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (revolutEnabled) ...[
                TextField(
                  controller: _revolutController,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Revolut.me username',
                    hintText: 'e.g. rahul (Europe)',
                  ),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _contactController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Contact',
                hintText: 'Any other way to reach them — optional',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _noteController,
              textInputAction: TextInputAction.done,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
