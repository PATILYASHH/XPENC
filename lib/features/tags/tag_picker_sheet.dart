import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// Bottom sheet: pick any number of tags as toggleable filter chips. New tags
/// are created from **More → Tags**, not from here — this sheet only selects.
/// Shared by [AddTransactionScreen] and [RecurringRuleSheet] (GitHub #63).
class TagPickerSheet extends ConsumerStatefulWidget {
  const TagPickerSheet({required this.initiallySelected, super.key});

  final Set<int> initiallySelected;

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initiallySelected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagsProvider);
    final groups = ref.watch(tagGroupsProvider).valueOrNull ?? const [];
    final tagsByGroup = ref.watch(tagGroupTagsByGroupProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Tags', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            if (groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final group in groups)
                      _GroupChip(
                        group: group,
                        tags: tagsByGroup[group.id] ?? const [],
                        selected: _selected,
                        onToggle: (ids) => setState(() {
                          if (ids.every(_selected.contains)) {
                            _selected.removeAll(ids);
                          } else {
                            _selected.addAll(ids);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            Flexible(
              child: tagsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load tags.\n$e',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (tags) {
                  if (tags.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No tags yet — add one from More → Tags.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final tag in tags)
                          FilterChip(
                            label: Text(tag.name),
                            selected: _selected.contains(tag.id),
                            selectedColor: Color(
                              tag.colorValue,
                            ).withValues(alpha: 0.22),
                            checkmarkColor: Color(tag.colorValue),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _selected.add(tag.id);
                              } else {
                                _selected.remove(tag.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tag group, offered as a single toggle: applies (or removes) every one
/// of its member tags at once. `selected` shows a filled state once every
/// tag it names is already picked, exactly like a group of individual
/// [FilterChip]s would if tapped together.
class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.group,
    required this.tags,
    required this.selected,
    required this.onToggle,
  });

  final TagGroupRow group;
  final List<TagRow> tags;
  final Set<int> selected;
  final ValueChanged<List<int>> onToggle;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final ids = tags.map((t) => t.id).toList();
    final allSelected = ids.every(selected.contains);
    final color = Color(group.colorValue);

    return FilterChip(
      avatar: Icon(Icons.workspaces_outline, size: 16, color: color),
      label: Text(group.name),
      selected: allSelected,
      selectedColor: color.withValues(alpha: 0.22),
      checkmarkColor: color,
      onSelected: (_) => onToggle(ids),
    );
  }
}
