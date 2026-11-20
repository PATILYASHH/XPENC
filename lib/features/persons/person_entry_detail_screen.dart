import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/group_tag.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../share/share_flows.dart';
import '../share/share_models.dart' show PersonEntryShare;
import 'person_avatar.dart';
import 'person_detail_screen.dart'
    show PersonTagChips, deletePersonEntry, showPersonEntrySheet;
import 'shared_entries.dart' show sharedLabel;
import '../../core/l10n/l10n.dart';

/// One entry in a person's history, on a page of its own — the way a
/// transaction opens: the amount and what happened up top, every detail
/// below, and Share (a receipt of just this entry), Edit and Delete in the
/// top bar.
class PersonEntryDetailScreen extends ConsumerWidget {
  const PersonEntryDetailScreen({
    required this.personId,
    required this.entryId,
    super.key,
  });

  final int personId;
  final int entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(allPersonsByIdProvider)[personId];
    final entriesAsync = ref.watch(personEntriesProvider(personId));
    final entries = entriesAsync.valueOrNull ?? const <PersonEntryRow>[];
    PersonEntryRow? entry;
    for (final e in entries) {
      if (e.id == entryId) entry = e;
    }
    final found = entry;

    return Scaffold(
      appBar: AppTopBar(
        title: const Tr('Entry'),
        actions: [
          if (person != null && found != null) ...[
            IconButton(
              key: const Key('entry-share'),
              icon: const AppIcon(Icons.ios_share_rounded),
              tooltip: tr('Share'),
              onPressed: () => sharePersonEntry(context, person, found),
            ),
            IconButton(
              icon: const AppIcon(Icons.edit_outlined),
              tooltip: tr('Edit'),
              onPressed: () => showPersonEntrySheet(
                context,
                personId,
                found.direction,
                isRepayment: found.categoryId != null,
                existing: found,
              ),
            ),
            IconButton(
              icon: const AppIcon(Icons.delete_outline),
              tooltip: tr('Delete'),
              onPressed: () => _confirmDelete(context, ref, person, found),
            ),
          ],
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          title: tr('Something went wrong'),
          message: tr("Couldn't load this entry."),
          detail: '$e',
        ),
        data: (_) => person == null || found == null
            ? ErrorView(
                title: tr('Entry not found'),
                message: tr('It may have been deleted.'),
              )
            : _EntryView(person: person, entry: found, entries: entries),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PersonRow person,
    PersonEntryRow entry,
  ) async {
    final navigator = Navigator.of(context);
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tr('Delete this entry?'),
        content: Text(
          tr("It comes off {0}'s balance. This can't be undone.", [
            person.name,
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Tr('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await deletePersonEntry(context, ref, entry, person.remoteUsername)) {
      navigator.pop();
    }
  }
}

class _EntryView extends ConsumerWidget {
  const _EntryView({
    required this.person,
    required this.entry,
    required this.entries,
  });

  final PersonRow person;
  final PersonEntryRow entry;
  final List<PersonEntryRow> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gave = entry.direction == PersonDirection.theyOwe;
    final isRepayment = entry.categoryId != null;
    final color = gave && !isRepayment ? AppColors.expense : AppColors.income;
    final (String label, IconData icon) = isRepayment
        ? (tr('{0} repaid', [person.name]), Icons.paid_outlined)
        : gave
        ? (tr('You gave {0}', [person.name]), Icons.arrow_upward_rounded)
        : (tr('{0} gave you', [person.name]), Icons.arrow_downward_rounded);

    final account = entry.accountId == null
        ? null
        : ref.watch(accountMapProvider)[entry.accountId]?.name;
    final category = isRepayment
        ? ref.watch(categoryMapProvider)[entry.categoryId]?.name
        : null;
    final groupId = ref
        .watch(personEntryGroupIdsProvider)
        .valueOrNull?[entry.id];
    final group = groupId == null
        ? null
        : ref.watch(allGroupsMapProvider)[groupId];
    final tags =
        ref.watch(personEntryTagsByEntryProvider)[entry.id] ?? const [];
    final mode = entry.modeId == null
        ? null
        : ref.watch(modeMapProvider)[entry.modeId];
    final shared = sharedLabel(entry, person.remoteUsername);
    final note = entry.note?.trim();
    final after = PersonEntryShare.runningAfter(entries, entry);
    final afterLine = after.isPositive
        ? tr('{0} owes you', [person.name])
        : after.isNegative
        ? tr('You owe {0}', [person.name])
        : tr('All settled');

    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
    Widget text(String t) => Text(
      t,
      textAlign: TextAlign.right,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    );
    final divider = Divider(height: 1, color: cs.outline);

    final details = <Widget>[
      row(
        tr('Person'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonAvatar(
              name: person.name,
              photoPath: person.photoPath,
              radius: 12,
              glow: false,
            ),
            const SizedBox(width: 8),
            Flexible(child: text(person.name)),
          ],
        ),
      ),
      row(tr('Date'), text(DateFormat('EEEE, d MMM yyyy').format(entry.date))),
      if (entry.dueDate != null)
        row(tr('Due'), text(DateFormat('d MMM yyyy').format(entry.dueDate!))),
      row(
        tr('Account'),
        text(account ?? tr('None — no money moved through an account')),
      ),
      if (category != null) row(tr('Counted as'), text(category)),
      if (group != null) row(tr('Group'), GroupTag(group: group)),
      if (tags.isNotEmpty) row(tr('Tags'), PersonTagChips(tags)),
      if (mode != null) row(tr('Mode'), text(mode.name)),
      if (shared != null) row(tr('Shared'), text(shared)),
      row(tr('Note'), text(note == null || note.isEmpty ? '—' : note)),
      row(
        tr('After this'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            text(afterLine),
            if (!after.isZero)
              MoneyText(
                after.abs,
                color: after.isPositive ? AppColors.income : AppColors.expense,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    ];

    return ListView(
      // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        32 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppIcon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: MoneyText(
              entry.amount,
              color: color,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Chip(
            label: Text(label),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: color.withValues(alpha: 0.12),
            side: BorderSide.none,
          ),
        ),
        const SizedBox(height: 24),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < details.length; i++) ...[
                  if (i > 0) divider,
                  details[i],
                ],
              ],
            ),
          ),
        ),
        if (entry.transactionId != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () =>
                pushZoom(context, '/transaction/${entry.transactionId}'),
            icon: const AppIcon(Icons.receipt_long_outlined, size: 18),
            label: const Tr('Open the account transaction'),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          tr(
            'Share sends {0} a receipt of just this entry. Edit and Delete '
            'are up top too.',
            [person.name],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
