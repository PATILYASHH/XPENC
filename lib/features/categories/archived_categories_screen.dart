import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../../core/l10n/l10n.dart';

/// Categories hidden via **Archive** on the Categories screen (GitHub #162).
/// Restore brings one back to the pickers; Delete removes one for good, but
/// only one nothing has ever used — see [AppDatabase.deleteCategory].
class ArchivedCategoriesScreen extends ConsumerWidget {
  const ArchivedCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final archivedAsync = ref.watch(archivedCategoriesProvider);
    final active = ref.watch(categoryMapProvider);

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Archived categories')),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Tr(
            "Couldn't load archived categories.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        data: (archived) {
          if (archived.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
              child: Column(
                children: [
                  AppIcon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Tr(
                    'No archived categories.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          // A subcategory's parent may be archived alongside it or still live.
          final byId = {...active, for (final c in archived) c.id: c};
          return ListView(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
            ).plusNavBar(context),
            children: [
              for (final kind in CategoryKind.values)
                ..._section(
                  theme,
                  kind,
                  archived.where((c) => c.kind == kind).toList(),
                  byId,
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _section(
    ThemeData theme,
    CategoryKind kind,
    List<CategoryRow> archived,
    Map<int, CategoryRow> byId,
  ) {
    if (archived.isEmpty) return const [];
    final archivedIds = {for (final c in archived) c.id};
    // Parent, then its archived subcategories; a subcategory whose parent is
    // still live stands on its own.
    final ordered = <({CategoryRow category, bool isChild})>[];
    for (final c in archived) {
      if (c.parentId != null && archivedIds.contains(c.parentId)) continue;
      ordered.add((category: c, isChild: false));
      for (final child in archived) {
        if (child.parentId == c.id) {
          ordered.add((category: child, isChild: true));
        }
      }
    }

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(
          (kind == CategoryKind.expense ? tr('Money out') : tr('Money in'))
              .toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
      for (final entry in ordered)
        _ArchivedCategoryTile(
          category: entry.category,
          isChild: entry.isChild,
          parent: entry.category.parentId == null
              ? null
              : byId[entry.category.parentId],
          archivedChildren: archived
              .where((c) => c.parentId == entry.category.id)
              .length,
        ),
    ];
  }
}

class _ArchivedCategoryTile extends ConsumerWidget {
  const _ArchivedCategoryTile({
    required this.category,
    required this.isChild,
    required this.parent,
    required this.archivedChildren,
  });

  final CategoryRow category;
  final bool isChild;
  final CategoryRow? parent;
  final int archivedChildren;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(category.colorValue);
    final badge = isChild ? 30.0 : 40.0;

    final String subtitle;
    if (archivedChildren > 0) {
      subtitle = plural(
        archivedChildren,
        '1 subcategory',
        '{0} subcategories',
      );
    } else if (parent != null && !isChild) {
      subtitle = 'Under ${parent!.name}';
    } else {
      subtitle = isChild ? 'Subcategory' : 'Archived';
    }

    return AppListTile(
      contentPadding: EdgeInsets.only(left: isChild ? 32 : 16, right: 4),
      leading: Container(
        width: badge,
        height: badge,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: IconWell.forKey(
          category.iconKey,
          color: color,
          size: isChild ? 17 : 22,
        ),
      ),
      title: Text(
        category.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            icon: const AppIcon(Icons.unarchive_outlined, size: 18),
            label: const Tr('Restore'),
            onPressed: () => _restore(context, ref),
          ),
          IconButton(
            icon: AppIcon(Icons.delete_outline, color: theme.colorScheme.error),
            tooltip: tr('Delete'),
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(dbProvider).unarchiveCategory(category.id);
    final String message;
    if (archivedChildren > 0) {
      message = tr('"{0}" and its subcategories restored', [category.name]);
    } else if (parent != null && parent!.isArchived) {
      message = tr('"{0}" restored, with "{1}"', [category.name, parent!.name]);
    } else {
      message = '"${category.name}" restored';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Unlike archiving, this can't be undone — [AppDatabase.deleteCategory]
  /// refuses (with a clear reason) whenever anything still uses the
  /// category, so this only ever succeeds on one that was never used.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete "{0}"?', [category.name])),
        content: const Tr(
          "This permanently deletes the category — it can't be undone. It "
          'only works if nothing has ever used it; otherwise it stays '
          'archived.',
        ),
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
    if (confirmed != true) return;

    String message;
    try {
      await ref.read(dbProvider).deleteCategory(category.id);
      message = '"${category.name}" deleted';
    } on ArgumentError catch (e) {
      message = e.message?.toString() ?? tr("Can't delete this category");
    } catch (_) {
      message = tr("Can't delete this category — something still uses it.");
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
