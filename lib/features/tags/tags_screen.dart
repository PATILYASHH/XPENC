import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

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
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: InlineErrorView(message: "Couldn't load tags"),
          ),
        ),
        data: (tags) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            children: [
              if (tags.isEmpty)
                _EmptyTags(theme: theme)
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < tags.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 60,
                            color: theme.colorScheme.outline,
                          ),
                        _TagTile(tag: tags[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'A transaction can carry any number of tags. Deleting a tag '
                "just removes it from whatever it was on — nothing else changes.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New tag',
        onPressed: () => _openTagEditor(context),
        child: const Icon(Icons.add),
      ),
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
          Icon(
            Icons.sell_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
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

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.sell_outlined, color: color, size: 20),
      ),
      title: Text(
        tag.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: () => _openTagEditor(context, existing: tag),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            tooltip: 'Delete',
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete "${tag.name}"?'),
      content: const Text(
        "This removes the tag from every transaction that carries it. "
        "The transactions themselves aren't touched.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(dbProvider).deleteTag(tag.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Tag deleted')));
}

Future<void> _openTagEditor(BuildContext context, {TagRow? existing}) {
  return showModalBottomSheet<void>(
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
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _colorValue = widget.existing?.colorValue ?? _presetColors.first;
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
      _showError('Give the tag a name.');
      return;
    }

    setState(() => _submitting = true);
    final db = ref.read(dbProvider);
    try {
      if (_isEdit) {
        await db.updateTag(
          id: widget.existing!.id,
          name: name,
          colorValue: _colorValue,
        );
      } else {
        await db.addTag(name: name, colorValue: _colorValue);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save the tag — that name may already be used.');
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
              _isEdit ? 'Edit tag' : 'New tag',
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
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Work trip, Tax deductible',
                counterText: '',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
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
                  : const Text('Save'),
            ),
          ],
        ),
      ),
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
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
