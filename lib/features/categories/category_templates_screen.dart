import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Save the current category structure as a reusable template, and switch
/// between saved templates (GitHub #101). Switching never touches a
/// transaction — it only archives categories the target template doesn't
/// have and (re)creates the ones it does, exactly like a manual archive.
class CategoryTemplatesScreen extends ConsumerWidget {
  const CategoryTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final templatesAsync = ref.watch(categoryTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Category templates')),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: InlineErrorView(message: "Couldn't load templates"),
          ),
        ),
        data: (templates) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            Text(
              'A template is a saved snapshot of your category and '
              'sub-category structure. Save your current one before trying '
              'a reorganization, or switch to another template any time — '
              "past transactions always keep the category they're already "
              'tagged with, whether or not it stays in the template you '
              'switch to.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No templates saved yet — tap + to save your current '
                      'categories as one.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < templates.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 60),
                      _TemplateTile(template: templates[i]),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Save current as template',
        onPressed: () => _saveCurrentAsTemplate(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template});

  final CategoryTemplateRow template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemCount = ref
        .watch(categoryTemplateItemsProvider(template.id))
        .valueOrNull
        ?.length;
    final subtitle = itemCount == null
        ? 'Loading…'
        : '$itemCount ${itemCount == 1 ? 'category' : 'categories'}';

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.dashboard_customize_outlined,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        template.name,
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
      trailing: PopupMenuButton<_TemplateAction>(
        onSelected: (action) => switch (action) {
          _TemplateAction.apply => _applyTemplate(context, ref, template),
          _TemplateAction.rename => _renameTemplate(context, ref, template),
          _TemplateAction.delete => _deleteTemplate(context, ref, template),
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _TemplateAction.apply,
            child: Text('Switch to this template'),
          ),
          PopupMenuItem(value: _TemplateAction.rename, child: Text('Rename')),
          PopupMenuItem(value: _TemplateAction.delete, child: Text('Delete')),
        ],
      ),
      onTap: () => _applyTemplate(context, ref, template),
    );
  }
}

enum _TemplateAction { apply, rename, delete }

Future<void> _saveCurrentAsTemplate(BuildContext context, WidgetRef ref) async {
  final name = await _promptForName(context, title: 'Save as template');
  if (name == null || name.isEmpty) return;
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  await ref.read(dbProvider).saveCategoriesAsTemplate(name);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Saved "$name"')));
}

Future<void> _renameTemplate(
  BuildContext context,
  WidgetRef ref,
  CategoryTemplateRow template,
) async {
  final name = await _promptForName(
    context,
    title: 'Rename template',
    initialValue: template.name,
  );
  if (name == null || name.isEmpty || name == template.name) return;
  if (!context.mounted) return;

  await ref.read(dbProvider).renameCategoryTemplate(template.id, name);
}

Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Minimalist, Detailed tracking',
          counterText: '',
        ),
        onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> _applyTemplate(
  BuildContext context,
  WidgetRef ref,
  CategoryTemplateRow template,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Switch to "${template.name}"?'),
      content: const Text(
        'Categories not in this template are archived, not deleted — every '
        "transaction keeps the category it's already tagged with, and "
        'switching back later brings the same categories back. Categories '
        'this template adds are created fresh.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Switch'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(dbProvider).applyCategoryTemplate(template.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Switched to "${template.name}"')));
  } on ArgumentError catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? "Couldn't switch.")),
      );
  }
}

Future<void> _deleteTemplate(
  BuildContext context,
  WidgetRef ref,
  CategoryTemplateRow template,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete "${template.name}"?'),
      content: const Text(
        'This only deletes the saved template — your current categories '
        'and every transaction are untouched.',
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

  await ref.read(dbProvider).deleteCategoryTemplate(template.id);
}
