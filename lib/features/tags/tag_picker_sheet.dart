import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
