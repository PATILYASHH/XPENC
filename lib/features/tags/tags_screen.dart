import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/smart_tags.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/module_shortcuts.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';

/// Preset colours for a tag. Plain ints — this is the tag's own decorative
/// colour, not a money-direction signal.
const _presetColors = <int>[
  0xFF16A34A,
  0xFF2563EB,
  0xFFDC2626,
  0xFFA855F7,
  0xFFF97316,
  0xFF0EA5E9,
  0xFF78716C,
  0xFFEC4899,
];

/// Manage tags: short labels that can be pinned to any number of
/// transactions, cutting across category and account. Unlike a category, a
/// tag is a hard delete — dropping it just untags whatever carried it.
///
/// The Tags tab of Categories & Tags (`CategoriesScreen`), which also gives
/// it the top bar's Tag groups button and the ＋ ([openTagEditor]).
class TagsList extends ConsumerWidget {
  const TagsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // A mode's own tags are managed in that mode's editor.
    final tagsAsync = ref
        .watch(tagsProvider)
        .whenData((_) => ref.watch(everydayTagsProvider));

    return tagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: InlineErrorView(message: tr("Couldn't load tags")),
        ),
      ),
      data: (tags) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96).plusNavBar(context),
          children: [
            ModuleShortcuts([
              ModuleShortcut(
                Icons.receipt_long_outlined,
                tr('Transactions'),
                '/more/transactions',
              ),
            ], padding: EdgeInsets.fromLTRB(0, 0, 0, 12)),
            if (tags.isEmpty)
              _EmptyTags(theme: theme)
            else
              AppCard(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < tags.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 60,
                        ),
                      _TagTile(tag: tags[i]),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Tr(
              'A transaction can carry any number of tags. Tap a tag to see '
              'its transactions — hold one there to move a bunch to another '
              'tag. Deleting a tag just removes it from whatever it was on.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyTags extends StatelessWidget {
  const _EmptyTags({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          AppIcon(
            Icons.sell_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Tr(
            'No tags yet — tap + to add one.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagTile extends ConsumerWidget {
  const _TagTile({required this.tag});

  final TagRow tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(tag.colorValue);
    final smart = SmartTags.isSmart(tag.name);

    return AppListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      onTap: () => context.push('/more/tags/${tag.id}'),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: IconWell(
          smart ? Icons.auto_awesome_outlined : Icons.sell_outlined,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        tag.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: smart
          ? Text(
              tr('Smart · today "{0}"', [
                SmartTags.resolve(tag.name, DateTime.now()),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const AppIcon(Icons.edit_outlined),
            tooltip: tr('Edit'),
            visualDensity: VisualDensity.compact,
            onPressed: () => openTagEditor(context, existing: tag),
          ),
          IconButton(
            icon: AppIcon(Icons.delete_outline, color: theme.colorScheme.error),
            tooltip: tr('Delete'),
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDelete(context, ref, tag),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  TagRow tag,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('Delete "{0}"?', [tag.name])),
      content: const Tr(
        "This removes the tag from every transaction that carries it. "
        "The transactions themselves aren't touched.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Tr('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: const Tr('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(dbProvider).deleteTag(tag.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Tr('Tag deleted')));
}

/// A new tag, or [existing] to edit. Completes with the saved tag's id, or
/// null if the sheet was closed without saving — the tag picker selects a
/// tag made on the spot (GitHub #212).
Future<int?> openTagEditor(BuildContext context, {TagRow? existing}) {
  return showAppSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _TagEditorSheet(existing: existing),
  );
}

class _TagEditorSheet extends ConsumerStatefulWidget {
  const _TagEditorSheet({this.existing});

  final TagRow? existing;

  @override
  ConsumerState<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends ConsumerState<_TagEditorSheet> {
  late final TextEditingController _nameController;
  late int _colorValue;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '')
      ..addListener(() => setState(() {}));
    _colorValue = widget.existing?.colorValue ?? _presetColors.first;
  }

  /// Drops `{part}` in at the cursor (or over the selection), as long as the
  /// name still fits.
  void _insertPart(String part) {
    final token = '{$part}';
    final value = _nameController.value;
    final text = value.text;
    final sel = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: text.length);
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    final pad = before.isEmpty || before.endsWith(' ') ? '' : ' ';
    final next = '$before$pad$token$after';
    if (next.length > SmartTags.maxLength) return;
    _nameController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: before.length + pad.length + token.length,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      _showError(tr('Give the tag a name.'));
      return;
    }

    setState(() => _submitting = true);
    final db = ref.read(dbProvider);
    try {
      final int id;
      if (_isEdit) {
        id = widget.existing!.id;
        await db.updateTag(id: id, name: name, colorValue: _colorValue);
      } else {
        id = await db.addTag(name: name, colorValue: _colorValue);
      }
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(tr('Could not save the tag — that name may already be used.'));
    }
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
              _isEdit ? tr('Edit tag') : tr('New tag'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: tr('Name'),
                hintText: tr('e.g. Work trip, Tax deductible'),
                counterText: '',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 4),
            _smartParts(theme),
            const SizedBox(height: 20),
            Text(
              'COLOUR',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final c in _presetColors) _colorDot(theme, c)],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Tr('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Date parts that make this a smart tag (GitHub #189), and what the name
  /// reads as today once it holds one.
  Widget _smartParts(ThemeData theme) {
    final cs = theme.colorScheme;
    final name = _nameController.text.trim();
    final smart = SmartTags.isSmart(name);
    final labels = {
      'month': tr('Month'),
      'mon': tr('Short month'),
      'year': tr('Year'),
      'quarter': tr('Quarter'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final part in SmartTags.parts)
              ActionChip(
                avatar: AppIcon(Icons.add_rounded, size: 16, color: cs.primary),
                label: Text(labels[part]!),
                onPressed: () => _insertPart(part),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: smart ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                smart
                    ? tr(
                        'Smart tag — today it reads "{0}". Each transaction '
                        'gets the tag for its own date, so templates and '
                        'Auto rules stay current.',
                        [SmartTags.resolve(name, DateTime.now())],
                      )
                    : tr(
                        'Add a date part to make a smart tag that fills in '
                        "from each transaction's date.",
                      ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _colorDot(ThemeData theme, int value) {
    final selected = _colorValue == value;
    return GestureDetector(
      onTap: () => setState(() => _colorValue = value),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
              : null,
        ),
        child: selected
            ? const AppIcon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
