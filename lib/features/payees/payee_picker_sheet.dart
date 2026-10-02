import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../persons/contact_import.dart';
import '../persons/person_avatar.dart';

/// What the payee picker hands back. [personId] is set when the payee is one
/// of the user's people — the transaction then shows on their page, but
/// never counts toward owe/due. [notice] is a one-line heads-up for the
/// caller to show once the sheet is gone (e.g. "already in your people").
typedef PayeeChoice = ({String name, int? personId, String? notice});

/// Full-height payee picker for the add/edit screen: search, people, past
/// payees and a contacts section. Sized to the space above the keyboard so
/// nothing ends up hidden behind it.
Future<PayeeChoice?> showPayeePickerSheet(
  BuildContext context, {
  required bool isIncome,
  String? selectedName,
  int? selectedPersonId,
}) {
  return showAppSheet<PayeeChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => PayeePickerSheet(
      isIncome: isIncome,
      selectedName: selectedName,
      selectedPersonId: selectedPersonId,
    ),
  );
}

class PayeePickerSheet extends ConsumerStatefulWidget {
  const PayeePickerSheet({
    required this.isIncome,
    this.selectedName,
    this.selectedPersonId,
    super.key,
  });

  final bool isIncome;
  final String? selectedName;
  final int? selectedPersonId;

  @override
  ConsumerState<PayeePickerSheet> createState() => _PayeePickerSheetState();
}

class _PayeePickerSheetState extends ConsumerState<PayeePickerSheet> {
  final _search = TextEditingController();
  String _query = '';
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pop(String name, int? personId, {String? notice}) => Navigator.of(
    context,
  ).pop<PayeeChoice>((name: name, personId: personId, notice: notice));

  List<PersonRow> _everyone() => [
    ...?ref.read(personsProvider).valueOrNull,
    ...?ref.read(archivedPersonsProvider).valueOrNull,
  ];

  /// Reuses [existing] for a picked contact instead of creating a duplicate:
  /// fills in a phone/photo they don't have yet (never overwrites) and
  /// brings them back from the archive.
  Future<void> _reuse(PersonRow existing, PickedContact contact) async {
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
  }

  Future<PickedContact?> _pickContact() async {
    try {
      final contact = await pickContact();
      if (contact == null || !mounted) return null;
      if (contact.name == null) {
        setState(() => _notice = 'That contact has no name to use.');
        return null;
      }
      return contact;
    } on PlatformException {
      if (mounted) setState(() => _notice = "Couldn't open contacts.");
      return null;
    }
  }

  /// "Person from contacts": the existing person if this contact is already
  /// one (same phone, else same name), otherwise a new person.
  Future<void> _personFromContacts() async {
    final contact = await _pickContact();
    if (contact == null) return;
    setState(() => _busy = true);
    final existing = matchExistingPerson(contact, _everyone());
    if (existing != null) {
      await _reuse(existing, contact);
      if (!mounted) return;
      _pop(
        existing.name,
        existing.id,
        notice: '${existing.name} is already in your people — used them.',
      );
      return;
    }
    final id = await ref
        .read(dbProvider)
        .addPerson(
          contact.name!,
          phone: contact.phone,
          photoPath: contact.photoPath,
        );
    if (!mounted) return;
    _pop(contact.name!, id, notice: 'Added ${contact.name} to your people.');
  }

  /// "Payee from contacts": a plain payee named after the contact — unless
  /// they're already one of the user's people, then it's that person.
  Future<void> _payeeFromContacts() async {
    final contact = await _pickContact();
    if (contact == null) return;
    final existing = matchExistingPerson(contact, _everyone());
    if (existing != null) {
      setState(() => _busy = true);
      await _reuse(existing, contact);
      if (!mounted) return;
      _pop(
        existing.name,
        existing.id,
        notice: '${existing.name} is already in your people — used them.',
      );
      return;
    }
    _pop(contact.name!, null);
  }

  Future<void> _addTypedAsPerson(String name) async {
    setState(() => _busy = true);
    final existing = _everyone().where(
      (p) => p.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      final person = existing.first;
      if (person.isArchived) {
        await ref.read(dbProvider).unarchivePerson(person.id);
      }
      if (!mounted) return;
      _pop(person.name, person.id);
      return;
    }
    final id = await ref.read(dbProvider).addPerson(name);
    if (!mounted) return;
    _pop(name, id, notice: 'Added $name to your people.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final q = _query.trim().toLowerCase();

    final people = [...?ref.watch(personsProvider).valueOrNull]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final payees = ref.watch(plainPayeeNamesProvider);
    final personNames = {for (final p in people) p.name.toLowerCase()};

    final matchedPeople = [
      for (final p in people)
        if (q.isEmpty || p.name.toLowerCase().contains(q)) p,
    ];
    // A payee whose name is also a person reads as that person here — the
    // "connect to person" button on the payee's page merges the history.
    final matchedPayees = [
      for (final p in payees)
        if ((q.isEmpty || p.toLowerCase().contains(q)) &&
            !personNames.contains(p.toLowerCase()))
          p,
    ];
    final typed = _query.trim();
    final exact =
        typed.isNotEmpty &&
        (personNames.contains(q) || payees.any((p) => p.toLowerCase() == q));

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );

    // Everything above the keyboard: the sheet is this tall and the list
    // below the search box takes whatever's left, so no row is ever covered.
    return SizedBox(
      height: media.size.height * 0.92,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isIncome ? 'Who paid you?' : 'Who did you pay?',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.selectedName != null)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop<PayeeChoice>((
                        name: '',
                        personId: null,
                        notice: null,
                      )),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                controller: _search,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) {
                  final name = v.trim();
                  if (name.isEmpty) return;
                  final person = people.where(
                    (p) => p.name.toLowerCase() == name.toLowerCase(),
                  );
                  if (person.isNotEmpty) {
                    _pop(person.first.name, person.first.id);
                  } else {
                    _pop(name, null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search or type a new payee',
                  prefixIcon: const AppIcon(Icons.search_rounded),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  _notice!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: 24 + media.viewPadding.bottom),
                children: [
                  if (typed.isNotEmpty && !exact) ...[
                    const SizedBox(height: 8),
                    _OptionTile(
                      icon: Icons.storefront_outlined,
                      title: 'Use “$typed” as payee',
                      subtitle: 'A shop, company or anyone',
                      onTap: _busy ? null : () => _pop(typed, null),
                    ),
                    _OptionTile(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'Add “$typed” as a person',
                      subtitle: 'Shows on their page, not in owe/due',
                      onTap: _busy ? null : () => _addTypedAsPerson(typed),
                    ),
                  ],
                  section('FROM CONTACTS'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ContactButton(
                            icon: Icons.person_add_alt_1_outlined,
                            label: 'New person',
                            onTap: _busy ? null : _personFromContacts,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ContactButton(
                            icon: Icons.contacts_outlined,
                            label: 'New payee',
                            onTap: _busy ? null : _payeeFromContacts,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (matchedPeople.isNotEmpty) ...[
                    section('PEOPLE'),
                    for (final p in matchedPeople)
                      _ChoiceTile(
                        leading: PersonAvatar(
                          name: p.name,
                          photoPath: p.photoPath,
                        ),
                        title: p.name,
                        subtitle: 'Person',
                        selected: widget.selectedPersonId == p.id,
                        onTap: _busy ? null : () => _pop(p.name, p.id),
                      ),
                  ],
                  if (matchedPayees.isNotEmpty) ...[
                    section('PAYEES'),
                    for (final p in matchedPayees)
                      _ChoiceTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          child: const AppIcon(
                            Icons.storefront_outlined,
                            size: 20,
                          ),
                        ),
                        title: p,
                        selected:
                            widget.selectedPersonId == null &&
                            widget.selectedName == p,
                        onTap: _busy ? null : () => _pop(p, null),
                      ),
                  ],
                  if (matchedPeople.isEmpty &&
                      matchedPayees.isEmpty &&
                      typed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                      child: Text(
                        'No payees yet — type a name above, or pick one '
                        'from your contacts.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: AppIcon(icon, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: leading,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: selected
          ? AppIcon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: AppIcon(icon, size: 20),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
