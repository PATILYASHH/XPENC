import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/smart_tags.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../../core/l10n/l10n.dart';

/// Hold-to-select on a category or tag page: which transactions are picked.
/// Empty means the page isn't selecting.
mixin TxSelection<T extends StatefulWidget> on State<T> {
  final Set<int> selected = {};

  bool get selecting => selected.isNotEmpty;

  /// A long press: starts selecting with [id], or toggles it once started.
  void holdTx(int id) {
    HapticFeedback.selectionClick();
    toggleTx(id);
  }

  void toggleTx(int id) => setState(
    () => selected.contains(id) ? selected.remove(id) : selected.add(id),
  );

  void selectAllTx(Iterable<int> ids) => setState(() => selected.addAll(ids));

  void clearTx() => setState(selected.clear);
}

/// The top bar while selecting: ✕ to stop, the count, Select all and Move.
AppTopBar selectionTopBar({
  required int count,
  required int total,
  required VoidCallback onClose,
  required VoidCallback onSelectAll,
  required VoidCallback onMove,
}) => AppTopBar(
  leading: IconButton(
    icon: const AppIcon(Icons.close_rounded),
    tooltip: tr('Cancel'),
    onPressed: onClose,
  ),
  title: Text(tr('{0} selected', [count])),
  actions: [
    if (count < total)
      IconButton(
        icon: const AppIcon(Icons.select_all_rounded),
        tooltip: tr('Select all'),
        onPressed: onSelectAll,
      ),
    IconButton(
      icon: const AppIcon(Icons.drive_file_move_outline),
      tooltip: tr('Move to…'),
      onPressed: onMove,
    ),
  ],
);

/// The round icon a selected row wears in place of its own.
Widget selectedTxAvatar(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return CircleAvatar(
    backgroundColor: cs.primary,
    child: AppIcon(Icons.check_rounded, color: cs.onPrimary, size: 20),
  );
}

/// Where to move [count] transactions: a live category of [kind], parents
/// with their subcategories under them. [exclude] is left out. Null when
/// dismissed.
Future<int?> pickMoveCategory(
  BuildContext context,
  WidgetRef ref, {
  required CategoryKind kind,
  required int count,
  Set<int> exclude = const {},
}) {
  final all = ref.read(categoriesProvider(kind)).valueOrNull ?? const [];
  final parents = [
    for (final c in all)
      if (c.parentId == null) c,
  ];
  final childrenOf = <int, List<CategoryRow>>{};
  for (final c in all) {
    if (c.parentId != null) (childrenOf[c.parentId!] ??= []).add(c);
  }
  final rows = <(CategoryRow, bool)>[
    for (final p in parents) ...[
      if (!exclude.contains(p.id)) (p, false),
      for (final c in childrenOf[p.id] ?? const <CategoryRow>[])
        if (!exclude.contains(c.id)) (c, true),
    ],
  ];
  return _pickSheet<int>(
    context,
    title: tr('Move {0} to…', [
      plural(count, '1 transaction', '{0} transactions'),
    ]),
    empty: tr('No other category to move to.'),
    children: [
      for (final (c, isChild) in rows)
        AppListTile(
          contentPadding: EdgeInsetsDirectional.only(
            start: isChild ? 48 : 20,
            end: 20,
          ),
          leading: KeyIcon(c.iconKey, color: Color(c.colorValue)),
          title: Text(c.name),
          onTap: () => Navigator.of(context).pop(c.id),
        ),
    ],
  );
}

/// Where to move [count] transactions' tag: any everyday tag but [exclude].
Future<int?> pickMoveTag(
  BuildContext context,
  WidgetRef ref, {
  required int count,
  required int exclude,
}) {
  final tags = [
    for (final t in ref.read(everydayTagsProvider))
      if (t.id != exclude) t,
  ];
  return _pickSheet<int>(
    context,
    title: tr('Move {0} to…', [
      plural(count, '1 transaction', '{0} transactions'),
    ]),
    empty: tr('No other tag to move to.'),
    children: [
      for (final t in tags)
        AppListTile(
          leading: AppIcon(
            SmartTags.isSmart(t.name)
                ? Icons.auto_awesome_outlined
                : Icons.sell_outlined,
            color: Color(t.colorValue),
          ),
          title: Text(t.name),
          onTap: () => Navigator.of(context).pop(t.id),
        ),
    ],
  );
}

Future<T?> _pickSheet<T>(
  BuildContext context, {
  required String title,
  required String empty,
  required List<Widget> children,
}) {
  return showAppSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    empty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Flexible(child: ListView(shrinkWrap: true, children: children)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

/// Asks before permanently deleting [name] (a category or tag that's empty).
Future<bool> confirmPermanentDelete(
  BuildContext context, {
  required String name,
  required String body,
}) async {
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('Delete "{0}"?', [name])),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Tr('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Tr('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}
