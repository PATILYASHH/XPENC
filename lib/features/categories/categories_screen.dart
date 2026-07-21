import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Preset colours for a category. Plain ints — this is the category's own
/// decorative colour, not a money-direction signal.
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

/// Manage expense and income categories. Categories are archived, never
/// hard-deleted — every past transaction keeps its category so reports stay
/// intact.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CategoryList(kind: CategoryKind.expense),
          _CategoryList(kind: CategoryKind.income),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New category',
        onPressed: () {
          final kind = _tabController.index == 0
              ? CategoryKind.expense
              : CategoryKind.income;
          _openCategoryEditor(context, kind: kind);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// One tab's worth of categories, grouped in a single Card.
class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider(kind));

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: InlineErrorView(message: "Couldn't load categories"),
        ),
      ),
      data: (categories) {
        final rows = _flatten(categories);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            if (categories.isEmpty)
              _EmptyCategories(kind: kind)
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: rows[i].isChild ? 72 : 60,
                          color: theme.colorScheme.outline,
                        ),
                      _CategoryTile(
                        category: rows[i].category,
                        isChild: rows[i].isChild,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Group related categories under a parent — a subcategory rolls its '
              'spending up into its parent. Categories are archived, never '
              'deleted, so past reports stay intact.',
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

/// A row in the rendered list: a category plus whether it sits under a parent.
typedef _CategoryEntry = ({CategoryRow category, bool isChild});

/// Order a flat category list into `parent, its children…, next parent…`.
/// A child whose parent isn't in the list (an old backup, a mid-archive state)
/// falls back to rendering as top-level rather than vanishing.
List<_CategoryEntry> _flatten(List<CategoryRow> categories) {
  final parents = categories.where((c) => c.parentId == null).toList();
  final parentIds = {for (final p in parents) p.id};
  final childrenByParent = <int, List<CategoryRow>>{};
  final orphans = <CategoryRow>[];
  for (final c in categories) {
    if (c.parentId == null) continue;
    if (parentIds.contains(c.parentId)) {
      (childrenByParent[c.parentId!] ??= []).add(c);
    } else {
      orphans.add(c);
    }
  }

  final out = <_CategoryEntry>[];
  for (final p in parents) {
    out.add((category: p, isChild: false));
    for (final child in childrenByParent[p.id] ?? const []) {
      out.add((category: child, isChild: true));
    }
  }
  for (final o in orphans) {
    out.add((category: o, isChild: false));
  }
  return out;
}

/// A single category row: coloured icon badge, name, and its actions. A parent
/// also offers "add subcategory"; a child is indented and wears a smaller badge
/// so the hierarchy reads at a glance.
class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category, this.isChild = false});

  final CategoryRow category;
  final bool isChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(category.colorValue);
    final badge = isChild ? 30.0 : 40.0;

    return ListTile(
      contentPadding: EdgeInsets.only(left: isChild ? 32 : 16, right: 4),
      leading: Container(
        width: badge,
        height: badge,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          AppIcons.resolve(category.iconKey),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isChild)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add subcategory',
              visualDensity: VisualDensity.compact,
              onPressed: () => _openCategoryEditor(
                context,
                kind: category.kind,
                initialParentId: category.id,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: () => _openCategoryEditor(
              context,
              kind: category.kind,
              existing: category,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmArchive(context, ref, category),
          ),
        ],
      ),
    );
  }
}

/// Empty state for a tab with no categories yet.
class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.kind});

  final CategoryKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = kind == CategoryKind.expense ? 'expense' : 'income';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No $label categories yet — tap + to add one.',
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

/// Opens the create/edit editor sheet. [initialParentId] preselects a parent
/// when adding a subcategory from a parent row.
Future<void> _openCategoryEditor(
  BuildContext context, {
  required CategoryKind kind,
  CategoryRow? existing,
  int? initialParentId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _CategoryEditorSheet(
      kind: kind,
      existing: existing,
      initialParentId: initialParentId,
    ),
  );
}

/// Confirms and archives a category. Archiving only hides it from new entries —
/// past transactions keep it and nothing is deleted.
Future<void> _confirmArchive(
  BuildContext context,
  WidgetRef ref,
  CategoryRow category,
) async {
  final db = ref.read(dbProvider);
  final messenger = ScaffoldMessenger.of(context);

  final count = await db.countTransactionsForCategory(category.id);
  final childCount = await db.countChildCategories(category.id);
  if (!context.mounted) return;

  final usage = count > 0
      ? '$count transactions use this category. They keep it — '
          'archiving only hides the category from new entries. '
          'Nothing is deleted.'
      : "This category isn't used yet. It will be hidden from new "
          'entries.';
  final cascade = childCount > 0
      ? '\n\nIts $childCount ${childCount == 1 ? 'subcategory' : 'subcategories'} '
          'will be archived too.'
      : '';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Archive "${category.name}"?'),
      content: Text('$usage$cascade'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Archive'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await db.archiveCategory(category.id);
  messenger.showSnackBar(
    const SnackBar(content: Text('Category archived')),
  );
}

/// Create or edit a category: name, parent, colour, icon.
class _CategoryEditorSheet extends ConsumerStatefulWidget {
  const _CategoryEditorSheet({
    required this.kind,
    this.existing,
    this.initialParentId,
  });

  final CategoryKind kind;
  final CategoryRow? existing;

  /// Preselected parent when adding a subcategory from a parent row.
  final int? initialParentId;

  @override
  ConsumerState<_CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<_CategoryEditorSheet> {
  late final TextEditingController _nameController;
  late int _colorValue;
  late String _iconKey;
  late int? _parentId;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _colorValue = existing?.colorValue ?? _presetColors.first;
    _iconKey = existing?.iconKey ?? AppIcons.allKeys.first;
    _parentId = existing?.parentId ?? widget.initialParentId;
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
      _showError('Give the category a name.');
      return;
    }

    setState(() => _submitting = true);
    final db = ref.read(dbProvider);
    try {
      if (_isEdit) {
        await db.updateCategory(
          id: widget.existing!.id,
          name: name,
          colorValue: _colorValue,
          iconKey: _iconKey,
          parentId: Value(_parentId),
        );
      } else {
        await db.addCategory(
          name: name,
          kind: widget.kind,
          colorValue: _colorValue,
          iconKey: _iconKey,
          parentId: _parentId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? 'Could not save the category.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save the category.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit category' : 'New category',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Groceries, Salary',
                counterText: '',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            _buildParentField(theme),
            _fieldLabel(theme, 'Colour'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final c in _presetColors) _colorDot(theme, c)],
            ),
            const SizedBox(height: 24),
            _fieldLabel(theme, 'Icon'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final k in AppIcons.allKeys) _iconCircle(theme, k),
              ],
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

  /// A dropdown to nest this category under a top-level one. A category that
  /// already has subcategories can't itself become a child (the tree is only
  /// two deep), so it shows a fixed note instead.
  Widget _buildParentField(ThemeData theme) {
    final all = ref.watch(categoriesProvider(widget.kind)).valueOrNull ?? [];
    final editingId = widget.existing?.id;
    final hasChildren =
        editingId != null && all.any((c) => c.parentId == editingId);

    Widget wrap(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: child,
        );

    if (hasChildren) {
      return wrap(
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Parent category'),
          child: Text(
            'Top-level — it has subcategories',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Candidate parents: every live top-level category of this kind, minus the
    // category being edited (nothing parents itself).
    final parents = all
        .where((c) => c.parentId == null && c.id != editingId)
        .toList();
    final ids = {for (final p in parents) p.id};
    // Guard the dropdown's contract that its value matches one of its items.
    final value = _parentId != null && ids.contains(_parentId) ? _parentId : null;

    return wrap(
      DropdownButtonFormField<int?>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Parent category',
          helperText: 'Optional — nest this under another category',
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('None (top-level)'),
          ),
          for (final p in parents)
            DropdownMenuItem<int?>(
              value: p.id,
              child: Row(
                children: [
                  Icon(
                    AppIcons.resolve(p.iconKey),
                    size: 18,
                    color: Color(p.colorValue),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (v) => setState(() => _parentId = v),
      ),
    );
  }

  Widget _fieldLabel(ThemeData theme, String text) {
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
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

  Widget _iconCircle(ThemeData theme, String key) {
    final selected = _iconKey == key;
    final color = Color(_colorValue);
    return GestureDetector(
      onTap: () => setState(() => _iconKey = key),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : theme.colorScheme.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Icon(
          AppIcons.resolve(key),
          color: selected ? color : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
