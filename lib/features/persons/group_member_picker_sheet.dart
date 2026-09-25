import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import 'contact_import.dart';
import 'person_avatar.dart';

/// Bottom sheet: pick a group's members — used both when creating a group
/// and when editing an existing one's membership. Returns the chosen person
/// ids (`Set<int>`, same contract as `TagPickerSheet`), or null if dismissed.
///
/// Three sources: active people, archived people, and the phone's contacts.
/// Choosing someone archived is enough — `AppDatabase.setGroupMembers`
/// brings a newly added member back to the Individual list. A contact
/// becomes a new person only when Done is tapped, so backing out creates
/// nobody; a contact who's already in the app (same phone, else same name)
/// is matched to that person instead of being duplicated.
class GroupMemberPickerSheet extends ConsumerStatefulWidget {
  const GroupMemberPickerSheet({required this.initiallySelected, super.key});

  final Set<int> initiallySelected;

  @override
  ConsumerState<GroupMemberPickerSheet> createState() =>
      _GroupMemberPickerSheetState();
}

class _GroupMemberPickerSheetState
    extends ConsumerState<GroupMemberPickerSheet> {
  final Set<int> _selected = {};

  /// Contacts picked this session who aren't in the app yet — created on
  /// Done. Removing the chip drops them without creating anything.
  final List<PickedContact> _newFromContacts = [];

  String? _notice;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initiallySelected);
  }

  void _toggle(int id, bool on) =>
      setState(() => on ? _selected.add(id) : _selected.remove(id));

  Future<void> _addFromContacts(List<PersonRow> everyone) async {
    final PickedContact? contact;
    try {
      contact = await pickContact();
    } on PlatformException {
      setState(() => _notice = "Couldn't open contacts.");
      return;
    }
    if (contact == null || !mounted) return;
    if (contact.name == null) {
      setState(() => _notice = 'That contact has no name to use.');
      return;
    }

    final existing = matchExistingPerson(contact, everyone);
    if (existing != null) {
      // Already in the app — select them, and fill in a photo/phone they
      // don't have yet. Never overwrites anything already set.
      if ((existing.photoPath == null && contact.photoPath != null) ||
          (existing.phone == null && contact.phone != null)) {
        await ref
            .read(dbProvider)
            .linkPersonContact(
              existing.id,
              phone: existing.phone == null ? contact.phone : null,
              photoPath: existing.photoPath == null ? contact.photoPath : null,
            );
      }
      if (!mounted) return;
      setState(() {
        _selected.add(existing.id);
        _notice = existing.isArchived
            ? '${existing.name} is archived; adding them brings them back.'
            : '${existing.name} is already in your people; selected.';
      });
      return;
    }
    final picked = contact;
    final alreadyPending = _newFromContacts.any(
      (c) => c.name!.toLowerCase() == picked.name!.toLowerCase(),
    );
    setState(() {
      if (!alreadyPending) _newFromContacts.add(picked);
      _notice = picked.detailsAllowed
          ? null
          : 'Allow contacts access to also import their photo and phone.';
    });
  }

  Future<void> _done() async {
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final ids = {..._selected};
    for (final c in _newFromContacts) {
      ids.add(
        await db.addPerson(c.name!, phone: c.phone, photoPath: c.photoPath),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(ids);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final active = ref.watch(personsProvider).valueOrNull;
    final archived = ref.watch(archivedPersonsProvider).valueOrNull ?? const [];
    final everyone = [...?active, ...archived];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Members', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _done,
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: active == null
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _addFromContacts(everyone),
                            icon: const Icon(Icons.contacts_outlined),
                            label: const Text('Add from contacts'),
                          ),
                          if (_notice != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _notice!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (_newFromContacts.isNotEmpty) ...[
                            _label(theme, 'New from contacts'),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final c in _newFromContacts)
                                  InputChip(
                                    avatar: PersonAvatar(
                                      name: c.name!,
                                      photoPath: c.photoPath,
                                      radius: 12,
                                    ),
                                    label: Text(c.name!),
                                    selected: true,
                                    onDeleted: () => setState(
                                      () => _newFromContacts.remove(c),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          _label(theme, 'People'),
                          if (active.isEmpty)
                            Text(
                              'No people yet: add someone from your contacts '
                              'above.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            )
                          else
                            _chips(active),
                          if (archived.isNotEmpty) ...[
                            _label(theme, 'Archived'),
                            Text(
                              'Adding someone archived moves them back to '
                              'your Individual list.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _chips(archived),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
    child: Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _chips(List<PersonRow> people) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final person in people)
        FilterChip(
          avatar: _selected.contains(person.id)
              ? null
              : PersonAvatar(
                  name: person.name,
                  photoPath: person.photoPath,
                  radius: 12,
                ),
          label: Text(person.name),
          selected: _selected.contains(person.id),
          onSelected: (v) => _toggle(person.id, v),
        ),
    ],
  );
}
