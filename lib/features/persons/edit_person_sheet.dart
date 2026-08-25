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
          // Not editable here — stored but not wired to a button yet, so it
          // must pass through unchanged rather than being cleared.
          paypal: widget.person.paypal,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

            TextField(
              controller: _upiIdController,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'e.g. rahul@okhdfcbank',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Lets you pay them directly from their page. Not shared "
              "anywhere — stored only on this phone.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

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
