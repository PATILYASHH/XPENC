import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import 'contact_import.dart';
import 'person_avatar.dart';

/// Opens the "edit person" bottom sheet.
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

/// Same sheet, in create mode — [showAddPersonDialog] in `persons_screen.dart`
/// opens it with `person: null` so payment IDs can be filled in up front
/// instead of only after the fact via edit.
class EditPersonSheet extends ConsumerStatefulWidget {
  const EditPersonSheet({required this.person, super.key});

  final PersonRow? person;

  @override
  ConsumerState<EditPersonSheet> createState() => _EditPersonSheetState();
}

class _EditPersonSheetState extends ConsumerState<EditPersonSheet> {
  late final _nameController = TextEditingController(
    text: widget.person?.name ?? '',
  );
  late final _contactController = TextEditingController(
    text: widget.person?.contact ?? '',
  );
  late final _noteController = TextEditingController(
    text: widget.person?.note ?? '',
  );
  late final _upiIdController = TextEditingController(
    text: widget.person?.upiId ?? '',
  );
  late final _paypalController = TextEditingController(
    text: widget.person?.paypal ?? '',
  );
  late final _venmoController = TextEditingController(
    text: widget.person?.venmo ?? '',
  );
  late final _cashappController = TextEditingController(
    text: widget.person?.cashapp ?? '',
  );
  late final _revolutController = TextEditingController(
    text: widget.person?.revolut ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.person?.phone ?? '',
  );

  /// Set once a contact photo is picked (or cleared with the "x" on the
  /// preview) — starts at whatever this person already has saved, in edit
  /// mode. `null` on save means "no photo", same convention as every other
  /// field on this sheet.
  late String? _photoPath = widget.person?.photoPath;

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

  /// Fills the sheet from a picked contact — see [pickContact]. Adding a
  /// person takes their name too; editing one ("Link contact") keeps the
  /// name already chosen and only brings in phone and photo.
  Future<void> _pickFromContacts() async {
    try {
      final contact = await pickContact();
      if (contact == null || !mounted) return;
      final name = contact.name;
      if (widget.person == null && name != null) {
        _nameController.text = name;
      }
      if (!contact.detailsAllowed) {
        _showError(
          'Allow contacts access to also import their phone and photo.',
        );
        return;
      }
      if (contact.phone != null) _phoneController.text = contact.phone!;
      if (contact.photoPath != null) {
        setState(() => _photoPath = contact.photoPath);
      }
    } on PlatformException {
      if (!mounted) return;
      _showError("Couldn't open contacts.");
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give them a name.');
      return;
    }

    setState(() => _saving = true);
    final person = widget.person;
    final db = ref.read(dbProvider);
    if (person == null) {
      await db.addPerson(
        name,
        contact: _contactController.text.trim().nullIfEmpty,
        note: _noteController.text.trim().nullIfEmpty,
        upiId: _upiIdController.text.trim().nullIfEmpty,
        phone: _phoneController.text.trim().nullIfEmpty,
        paypal: _paypalController.text.trim().nullIfEmpty,
        venmo: _venmoController.text.trim().nullIfEmpty,
        cashapp: _cashappController.text.trim().nullIfEmpty,
        revolut: _revolutController.text.trim().nullIfEmpty,
        photoPath: _photoPath,
      );
    } else {
      await db.updatePerson(
        id: person.id,
        name: name,
        contact: _contactController.text.trim().nullIfEmpty,
        note: _noteController.text.trim().nullIfEmpty,
        upiId: _upiIdController.text.trim().nullIfEmpty,
        phone: _phoneController.text.trim().nullIfEmpty,
        paypal: _paypalController.text.trim().nullIfEmpty,
        venmo: _venmoController.text.trim().nullIfEmpty,
        cashapp: _cashappController.text.trim().nullIfEmpty,
        revolut: _revolutController.text.trim().nullIfEmpty,
        photoPath: _photoPath,
      );
    }
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
              widget.person == null ? 'Add person' : 'Edit person',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            if (_photoPath != null) ...[
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PersonAvatar(
                      name: _nameController.text,
                      photoPath: _photoPath,
                      radius: 36,
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Tooltip(
                        message: 'Remove photo',
                        child: InkWell(
                          onTap: () => setState(() => _photoPath = null),
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _nameController,
              autofocus: widget.person == null,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Yash',
                suffixIcon: IconButton(
                  tooltip: widget.person == null
                      ? 'Pick from contacts'
                      : 'Link contact (phone & photo)',
                  icon: const Icon(Icons.contacts_outlined),
                  onPressed: _pickFromContacts,
                ),
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
                  : Text(widget.person == null ? 'Add' : 'Save'),
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
