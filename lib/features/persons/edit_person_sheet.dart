import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/modes_db.dart';
import '../../data/providers.dart';
import 'contact_import.dart';
import 'person_avatar.dart';
import 'person_photo_storage.dart';

/// Opens the "edit person" bottom sheet.
Future<void> showEditPersonSheet(
  BuildContext context,
  WidgetRef ref,
  PersonRow person,
) {
  return showAppSheet<void>(
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

  /// Set once a photo is picked — from a contact or the gallery — or cleared
  /// with the "x" on the preview. Starts at whatever this person already has
  /// saved, in edit mode. `null` on save means "no photo", same convention as
  /// every other field on this sheet.
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
      final contact = await pickContact(ref.read(dbProvider));
      if (contact == null || !mounted) return;
      if (widget.person == null && await _reuseExisting(contact)) return;
      final name = contact.name;
      if (widget.person == null && name != null) {
        _nameController.text = name;
      }
      if (contact.phone != null) _phoneController.text = contact.phone!;
      if (contact.photoPath != null) {
        setState(() => _photoPath = contact.photoPath);
      }
    } on ContactsAccessOff {
      if (!mounted) return;
      _showError(contactsAccessOffMessage);
    } on PlatformException {
      if (!mounted) return;
      _showError("Couldn't open contacts.");
    }
  }

  /// A profile photo from the gallery. Downscaled on pick — an avatar never
  /// draws bigger than a few dozen pixels, so a full-size camera photo would
  /// only cost storage. The system photo picker needs no permission.
  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final path = await PersonPhotoStorage.storePicked(picked);
      if (!mounted) return;
      setState(() => _photoPath = path);
    } on PlatformException {
      if (!mounted) return;
      _showError("Couldn't open your photos.");
    }
  }

  /// Adding someone already in the app (same phone, else same name — active
  /// or archived) from contacts must not create a second copy of them: this
  /// keeps the existing person, fills in a phone/photo they don't have yet,
  /// brings them back from the archive, and closes the sheet. True when it
  /// did.
  Future<bool> _reuseExisting(PickedContact contact) async {
    final everyone = [
      ...?ref.read(personsProvider).valueOrNull,
      ...?ref.read(archivedPersonsProvider).valueOrNull,
    ];
    final existing = matchExistingPerson(contact, everyone);
    if (existing == null) return false;
    final db = ref.read(dbProvider);
    if ((existing.photoPath == null && contact.photoPath != null) ||
        (existing.phone == null && contact.phone != null)) {
      await db.linkPersonContact(
        existing.id,
        phone: existing.phone == null ? contact.phone : null,
        photoPath: existing.photoPath == null ? contact.photoPath : null,
      );
    }
    if (existing.isArchived) await db.unarchivePerson(existing.id);
    if (!mounted) return true;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            existing.isArchived
                ? '${existing.name} was archived — brought them back.'
                : '${existing.name} is already in your people.',
          ),
        ),
      );
    return true;
  }

  /// Added while a mode (a trip) is the focus: they're on the trip too —
  /// otherwise the mode's Persons tab, which lists only its people, would
  /// never show them.
  Future<void> _joinFocusedMode(int personId) async {
    // Read from the database, not a provider that may not have loaded yet.
    final db = ref.read(dbProvider);
    final modeId = await db.activeModeId();
    if (modeId == null || ref.read(modeFullAppProvider)) return;
    await db.setModePeople(modeId, {
      ...await db.modePeopleIds(modeId),
      personId,
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give them a name.');
      return;
    }

    final person = widget.person;
    // A typed name/phone that matches someone already here is most likely
    // them again — ask rather than silently add a duplicate (two different
    // people can share a name, so it's never blocked outright).
    if (person == null) {
      final everyone = [
        ...?ref.read(personsProvider).valueOrNull,
        ...?ref.read(archivedPersonsProvider).valueOrNull,
      ];
      final existing = matchExistingPerson((
        name: name,
        phone: _phoneController.text.trim().nullIfEmpty,
        photoPath: null,
      ), everyone);
      if (existing != null) {
        final addAnyway = await showAppDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Already in your people'),
            content: Text(
              '${existing.name} already exists'
              '${existing.isArchived ? ' (archived)' : ''}. '
              'Keep the existing one, or add a separate person?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Add separate'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep existing'),
              ),
            ],
          ),
        );
        if (addAnyway == null || !mounted) return;
        if (!addAnyway) {
          if (existing.isArchived) {
            await ref.read(dbProvider).unarchivePerson(existing.id);
          }
          await _joinFocusedMode(existing.id);
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
    }

    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    if (person == null) {
      final id = await db.addPerson(
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
      await _joinFocusedMode(id);
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
    // GitHub #167: with contacts access off, there's no way into them.
    final contactsOn = ref.watch(contactsAccessProvider).valueOrNull ?? false;
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

            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Tooltip(
                    message: _photoPath == null ? 'Add photo' : 'Change photo',
                    child: InkWell(
                      onTap: _pickFromGallery,
                      customBorder: const CircleBorder(),
                      child: _photoPath == null
                          ? CircleAvatar(
                              radius: 36,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              child: AppIcon(
                                Icons.add_a_photo_outlined,
                                size: 26,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : PersonAvatar(
                              name: _nameController.text,
                              photoPath: _photoPath,
                              radius: 36,
                            ),
                    ),
                  ),
                  if (_photoPath != null)
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
                            child: AppIcon(
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
            Center(
              child: TextButton(
                onPressed: _pickFromGallery,
                child: Text(_photoPath == null ? 'Add photo' : 'Change photo'),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _nameController,
              autofocus: widget.person == null,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Yash',
                suffixIcon: contactsOn
                    ? IconButton(
                        tooltip: widget.person == null
                            ? 'Pick from contacts'
                            : 'Link contact (phone & photo)',
                        icon: const AppIcon(Icons.contacts_outlined),
                        onPressed: _pickFromContacts,
                      )
                    : null,
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
