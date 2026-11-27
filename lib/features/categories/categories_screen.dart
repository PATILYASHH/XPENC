import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/module_shortcuts.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/icon_picker_sheet.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';
import '../tags/tags_screen.dart';

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

/// Categories & Tags: money-out and money-in categories, and tags, as one
/// page's three tabs — both are how a transaction gets sorted.
///
/// Categories are archived rather than deleted — every past transaction
/// keeps its category so reports stay intact. Archived ones live behind the
/// top bar's archive button, where they can be restored (or, if never used,
/// deleted). Tags ([TagsList]) have Tag groups there instead.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({this.initialTab = CategoriesTab.moneyOut, super.key});

  /// The tab it opens on — `/more/tags` opens on [CategoriesTab.tags].
  final CategoriesTab initialTab;

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

/// The tabs of [CategoriesScreen], in order.
enum CategoriesTab { moneyOut, moneyIn, tags }

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  CategoriesTab get _tab => CategoriesTab.values[_tabController.index];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: CategoriesTab.values.length,
      initialIndex: widget.initialTab.index,
      vsync: this,
    );
    // The top bar's buttons and the ＋ follow the tab.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: const Tr('Categories & Tags'),
        actions: _tab == CategoriesTab.tags
            ? [
                IconButton(
                  icon: const AppIcon(Icons.workspaces_outline),
                  tooltip: tr('Tag groups'),
                  onPressed: () => context.push('/more/tags/groups'),
                ),
              ]
            : [
                IconButton(
                  icon: const AppIcon(Icons.inventory_2_outlined),
                  tooltip: tr('Archived categories'),
                  onPressed: () => context.push('/more/categories/archived'),
                ),
                IconButton(
                  icon: const AppIcon(Icons.dashboard_customize_outlined),
                  tooltip: tr('Templates'),
                  onPressed: () => context.push('/more/categories/templates'),
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tr('Money out')),
            Tab(text: tr('Money in')),
            Tab(text: tr('Tags')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CategoryList(kind: CategoryKind.expense),
          _CategoryList(kind: CategoryKind.income),
          TagsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: _tab == CategoriesTab.tags
            ? tr('New tag')
            : tr('New category'),
        onPressed: () => switch (_tab) {
          CategoriesTab.moneyOut => openCategoryEditor(
            context,
            kind: CategoryKind.expense,
          ),
          CategoriesTab.moneyIn => openCategoryEditor(
            context,
            kind: CategoryKind.income,
          ),
          CategoriesTab.tags => openTagEditor(context),
        },
        child: const AppIcon(Icons.add),
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
      error: (_, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: InlineErrorView(message: tr("Couldn't load categories")),
        ),
      ),
      data: (categories) {
        final rows = _flatten(categories);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96).plusNavBar(context),
          children: [
            ModuleShortcuts([
              // Basic mode has no budgets.
              if (ref.watch(appModeProvider) != AppMode.basic)
                ModuleShortcut(
                  Icons.donut_large_outlined,
                  tr('Budgets'),
                  '/more/budgets',
                ),
              ModuleShortcut(
                Icons.receipt_long_outlined,
                tr('Transactions'),
                '/more/transactions',
              ),
            ], padding: const EdgeInsets.fromLTRB(0, 0, 0, 12)),
            if (categories.isEmpty)
              _EmptyCategories(kind: kind)
            else
              AppCard(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: rows[i].isChild ? 72 : 60,
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
            Tr(
              'Group related categories under a parent — a subcategory rolls its '
              'spending up into its parent. Categories are archived, not '
              'deleted, so past reports stay intact — restore them from the '
              'archive button above.',
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

    return AppListTile(
      contentPadding: EdgeInsets.only(left: isChild ? 32 : 16, right: 4),
      // Its own page: totals and every transaction (GitHub #169).
      onTap: () => context.push('/more/categories/${category.id}'),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isChild)
            IconButton(
              icon: const AppIcon(Icons.add),
              tooltip: tr('Add subcategory'),
              visualDensity: VisualDensity.compact,
              onPressed: () => openCategoryEditor(
                context,
                kind: category.kind,
                initialParentId: category.id,
              ),
            ),
          IconButton(
            icon: const AppIcon(Icons.edit_outlined),
            tooltip: tr('Edit'),
            visualDensity: VisualDensity.compact,
            onPressed: () => openCategoryEditor(
              context,
              kind: category.kind,
              existing: category,
            ),
          ),
          IconButton(
            icon: const AppIcon(Icons.archive_outlined),
            tooltip: tr('Archive'),
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
    final label = kind == CategoryKind.expense ? 'money-out' : 'money-in';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          AppIcon(
            Icons.category_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            tr('No {0} categories yet — tap + to add one.', [label]),
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
/// when adding a subcategory from a parent row. Completes with the saved
/// category's id, or null if the sheet was closed without saving — the add
/// page's picker uses it to pick a category made on the spot (GitHub #212).
Future<int?> openCategoryEditor(
  BuildContext context, {
  required CategoryKind kind,
  CategoryRow? existing,
  int? initialParentId,
}) {
  return showAppSheet<int>(
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
/// past transactions keep it and nothing is deleted. An empty category (see
/// [AppDatabase.categoryDeleteBlocker]) can be deleted for good from here
/// instead.
Future<void> _confirmArchive(
  BuildContext context,
  WidgetRef ref,
  CategoryRow category,
) async {
  final db = ref.read(dbProvider);
  final messenger = ScaffoldMessenger.of(context);

  final count = await db.countTransactionsForCategory(category.id);
  final childCount = await db.countChildCategories(category.id);
  // Empty — no subcategories, nothing using it — so it can go for good.
  final deletable = await db.categoryDeleteBlocker(category.id) == null;
  if (!context.mounted) return;

  final usage = count > 0
      ? tr('{0} transactions use this category. They keep it — '
            'archiving only hides the category from new entries. '
            'Nothing is deleted.', [count])
      : tr("This category isn't used yet. It will be hidden from new "
            'entries.');
  final cascade = childCount > 0
      ? tr('\n\nIts {0} will be archived too.', [
          plural(childCount, '1 subcategory', '{0} subcategories'),
        ])
      : '';

  final choice = await showAppDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('Archive "{0}"?', [category.name])),
      content: Text(
        deletable
            ? tr("Nothing uses this category — archive it to hide it, or "
                  "delete it for good. Deleting can't be undone.")
            : '$usage$cascade',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Tr('Cancel'),
        ),
        if (deletable)
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('delete'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Tr('Delete'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop('archive'),
          child: const Tr('Archive'),
        ),
      ],
    ),
  );

  if (choice == null) return;
  if (choice == 'delete') {
    try {
      await db.deleteCategory(category.id);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('"{0}" deleted', [category.name]))),
      );
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? '')),
      );
    }
    return;
  }

  await db.archiveCategory(category.id);
  messenger.showSnackBar(
    SnackBar(
      content: const Tr('Category archived'),
      action: SnackBarAction(
        label: tr('Undo'),
        onPressed: () => db.unarchiveCategory(category.id),
      ),
    ),
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

  /// Words that file a typed entry here — "supermarket" (GitHub #213).
  final _keywordController = TextEditingController();
  final List<String> _keywords = [];

  /// False until an edited category's keywords have loaded — saving before
  /// then must leave them alone rather than wipe them.
  late bool _keywordsReady = widget.existing == null;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _colorValue = existing?.colorValue ?? _presetColors.first;
    _iconKey = existing?.iconKey ?? AppIcons.allKeys.first;
    _parentId = existing?.parentId ?? widget.initialParentId;
    if (existing != null) {
      ref.read(dbProvider).categoryKeywords(existing.id).then((words) {
        if (!mounted) return;
        setState(() {
          for (final w in words) {
            final k = AppDatabase.normalizeCategoryKeyword(w);
            if (k.isNotEmpty && !_keywords.contains(k)) _keywords.add(k);
          }
          _keywordsReady = true;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  /// Adds each comma-separated word in [raw] that isn't there yet.
  void _addKeywords(String raw) {
    setState(() {
      for (final part in raw.split(',')) {
        final k = AppDatabase.normalizeCategoryKeyword(part);
        if (k.isNotEmpty && !_keywords.contains(k)) _keywords.add(k);
      }
    });
  }

  /// A comma ends a keyword as it's typed; the rest stays in the field.
  void _onKeywordTyped(String text) {
    final cut = text.lastIndexOf(',');
    if (cut < 0) return;
    _addKeywords(text.substring(0, cut));
    _keywordController.text = text.substring(cut + 1);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError(tr('Give the category a name.'));
      return;
    }

    setState(() => _submitting = true);
    final db = ref.read(dbProvider);
    try {
      final int id;
      if (_isEdit) {
        id = widget.existing!.id;
        await db.updateCategory(
          id: id,
          name: name,
          colorValue: _colorValue,
          iconKey: _iconKey,
          parentId: Value(_parentId),
        );
      } else {
        id = await db.addCategory(
          name: name,
          kind: widget.kind,
          colorValue: _colorValue,
          iconKey: _iconKey,
          parentId: _parentId,
        );
      }
      if (_keywordsReady) {
        // A word still in the field counts — Save shouldn't drop it.
        await db.setCategoryKeywords(id, [
          ..._keywords,
          ..._keywordController.text.split(','),
        ]);
      }
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? tr('Could not save the category.'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(tr('Could not save the category.'));
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
              _isEdit ? tr('Edit category') : tr('New category'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: tr('Name'),
                hintText: tr('e.g. Groceries, Salary'),
                counterText: '',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            _buildParentField(theme),
            _fieldLabel(theme, tr('Keywords')),
            const SizedBox(height: 8),
            _keywordsField(theme),
            const SizedBox(height: 24),
            _fieldLabel(theme, tr('Colour')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final c in _presetColors) _colorDot(theme, c)],
            ),
            const SizedBox(height: 24),
            _fieldLabel(theme, tr('Icon')),
            const SizedBox(height: 12),
            _iconField(theme),
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

  /// A dropdown to nest this category under a top-level one. A category that
  /// already has subcategories can't itself become a child (the tree is only
  /// two deep), so it shows a fixed note instead.
  Widget _buildParentField(ThemeData theme) {
    final all = ref.watch(categoriesProvider(widget.kind)).valueOrNull ?? [];
    final editingId = widget.existing?.id;
    final hasChildren =
        editingId != null && all.any((c) => c.parentId == editingId);

    Widget wrap(Widget child) =>
        Padding(padding: const EdgeInsets.only(bottom: 20), child: child);

    if (hasChildren) {
      return wrap(
        InputDecorator(
          decoration: InputDecoration(labelText: tr('Parent category')),
          child: Tr(
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
    final value = _parentId != null && ids.contains(_parentId)
        ? _parentId
        : null;

    return wrap(
      DropdownButtonFormField<int?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: tr('Parent category'),
          helperText: tr('Optional — nest this under another category'),
        ),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Tr('None (top-level)'),
          ),
          for (final p in parents)
            DropdownMenuItem<int?>(
              value: p.id,
              child: Row(
                children: [
                  KeyIcon(p.iconKey, size: 18, color: Color(p.colorValue)),
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

  /// The category's keywords as chips, and a field to add more. A word
  /// another category has is moved here on Save — the note says from where.
  Widget _keywordsField(ThemeData theme) {
    final cs = theme.colorScheme;
    final rules = ref.watch(merchantRulesProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoryMapProvider);
    final selfId = widget.existing?.id;
    final moves = <String>[
      for (final k in _keywords)
        for (final r in rules)
          if (r.categoryId != selfId &&
              AppDatabase.normalizeCategoryKeyword(r.matchPattern) == k &&
              categories[r.categoryId] != null)
            tr('"{0}" moves here from {1}.', [k, categories[r.categoryId]!.name]),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_keywords.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in _keywords)
                InputChip(
                  key: ValueKey('category-keyword-$k'),
                  label: Text(k),
                  onDeleted: () => setState(() => _keywords.remove(k)),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          key: const Key('category-keyword-field'),
          controller: _keywordController,
          enabled: _keywordsReady,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: tr('e.g. supermarket, market'),
            helperText: tr(
              'Type "34 supermarket" in Type it and it files here.',
            ),
            helperMaxLines: 2,
            suffixIcon: IconButton(
              icon: const AppIcon(Icons.add_rounded),
              tooltip: tr('Add keyword'),
              onPressed: () {
                _addKeywords(_keywordController.text);
                _keywordController.clear();
              },
            ),
          ),
          onChanged: _onKeywordTyped,
          onSubmitted: (text) {
            _addKeywords(text);
            _keywordController.clear();
          },
        ),
        for (final m in moves)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              m,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
            ),
          ),
      ],
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
            ? const AppIcon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  /// A single tile showing the chosen icon; tapping it opens the searchable
  /// icon sheet (GitHub #102) instead of laying every icon out inline.
  Widget _iconField(ThemeData theme) {
    final color = Color(_colorValue);
    return GestureDetector(
      onTap: () async {
        final picked = await showIconPickerSheet(
          context,
          selected: _iconKey,
          accentColor: color,
          allowEmoji: true,
        );
        if (picked != null) setState(() => _iconKey = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: KeyIcon(_iconKey, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Tr(
                'Tap to change',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AppIcon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
