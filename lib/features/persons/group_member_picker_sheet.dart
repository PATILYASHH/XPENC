import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Bottom sheet: pick any number of Persons as a group's members. Same
/// `Set<int>` in/out contract as `TagPickerSheet` — used both when creating
/// a group and when editing an existing one's membership. New Persons are
/// created from the Individual tab, not from here — this sheet only
/// selects, and only from people who aren't archived.
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

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initiallySelected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final personsAsync = ref.watch(personsProvider);

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
                    child: Text('Members', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: personsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load people.\n$e',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (persons) {
                  if (persons.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No people yet — add someone from the Individual tab '
                        'first.',
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
                        for (final person in persons)
                          FilterChip(
                            avatar: _selected.contains(person.id)
                                ? null
                                : CircleAvatar(
                                    backgroundColor:
                                        theme.colorScheme.surfaceContainerHighest,
                                    child: Text(
                                      person.name.isEmpty
                                          ? '?'
                                          : person.name[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                            label: Text(person.name),
                            selected: _selected.contains(person.id),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _selected.add(person.id);
                              } else {
                                _selected.remove(person.id);
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
