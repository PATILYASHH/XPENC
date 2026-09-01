import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Preset colours for a group. Same palette as a plain tag's — this is
/// decorative only, not a money-direction signal.
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

/// Manage tag groups: named bundles of [Tags] (e.g. "Work trip" = Travel +
/// Meals + Client) picked as one unit from [TagPickerSheet] instead of
/// hunting each tag down individually every time. See GitHub #92.
class TagGroupsScreen extends ConsumerWidget {
  const TagGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(tagGroupsProvider);
    final tagsByGroup = ref.watch(tagGroupTagsByGroupProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tag groups')),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: InlineErrorView(message: "Couldn't load tag groups"),
          ),
        ),
        data: (groups) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            children: [
              if (groups.isEmpty)
                _EmptyGroups(theme: theme)
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < groups.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 60,
                            color: theme.colorScheme.outline,
                          ),
                        _GroupTile(
                          group: groups[i],
                          tags: tagsByGroup[groups[i].id] ?? const [],
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Picking a group from the tag picker selects every tag in it '
                'at once. Deleting a group never touches the tags themselves '
                'or anything already tagged.',
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
        tooltip: 'New group',
        onPressed: () => _openGroupEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.workspaces_outline,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No tag groups yet — tap + to bundle a few tags together.',
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

class _GroupTile extends ConsumerWidget {
  const _GroupTile({required this.group, required this.tags});

  final TagGroupRow group;
  final List<TagRow> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(group.colorValue);
    final subtitle = tags.isEmpty
        ? 'No tags yet'
        : tags.map((t) => t.name).join(', ');

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
        child: Icon(Icons.workspaces_outline, color: color, size: 20),
      ),
      title: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => _openGroupEditor(context, existing: group),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
        tooltip: 'Delete',
        visualDensity: VisualDensity.compact,
        onPressed: () => _confirmDelete(context, ref, group),
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  TagGroupRow group,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete "${group.name}"?'),
      content: const Text(
        'The tags in this group, and anything already tagged with them, '
        'are left exactly as they are.',
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

  await ref.read(dbProvider).deleteTagGroup(group.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Tag group deleted')));
}

Future<void> _openGroupEditor(BuildContext context, {TagGroupRow? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _GroupEditorSheet(existing: existing),
  );
}

class _GroupEditorSheet extends ConsumerStatefulWidget {
  const _GroupEditorSheet({this.existing});

  final TagGroupRow? existing;

  @override
  ConsumerState<_GroupEditorSheet> createState() => _GroupEditorSheetState();
}

class _GroupEditorSheetState extends ConsumerState<_GroupEditorSheet> {
  late final TextEditingController _nameController;
  late int _colorValue;
  final Set<int> _selectedTagIds = {};
  bool _loadingTags = true;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _colorValue = widget.existing?.colorValue ?? _presetColors.first;
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTags());
    } else {
      _loadingTags = false;
    }
  }

  Future<void> _loadTags() async {
    final ids = await ref.read(dbProvider).tagIdsForGroup(widget.existing!.id);
    if (!mounted) return;
    setState(() {
      _selectedTagIds.addAll(ids);
      _loadingTags = false;
    });
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
      _showError('Give the group a name.');
      return;
    }

    setState(() => _submitting = true);
    final db = ref.read(dbProvider);
    try {
      int groupId;
      if (_isEdit) {
        groupId = widget.existing!.id;
        await db.updateTagGroup(
          id: groupId,
          name: name,
          colorValue: _colorValue,
        );
      } else {
        groupId = await db.addTagGroup(name: name, colorValue: _colorValue);
      }
      await db.setTagGroupTags(groupId, _selectedTagIds);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save the group — that name may already be used.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagsProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Padding(
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
                _isEdit ? 'Edit group' : 'New group',
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
              const SizedBox(height: 20),
              Text(
                'TAGS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingTags)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                tagsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text(
                    'Could not load tags.\n$e',
                    style: theme.textTheme.bodyMedium,
                  ),
                  data: (tags) {
                    if (tags.isEmpty) {
                      return Text(
                        'No tags yet — add one from More → Tags first.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final tag in tags)
                          FilterChip(
                            label: Text(tag.name),
                            selected: _selectedTagIds.contains(tag.id),
                            selectedColor: Color(
                              tag.colorValue,
                            ).withValues(alpha: 0.22),
                            checkmarkColor: Color(tag.colorValue),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _selectedTagIds.add(tag.id);
                              } else {
                                _selectedTagIds.remove(tag.id);
                              }
                            }),
                          ),
                      ],
                    );
                  },
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
