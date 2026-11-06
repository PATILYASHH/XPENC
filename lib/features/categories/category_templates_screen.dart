import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/app_info.dart';
import '../../core/platform/outgoing_file.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/open_link.dart';
import '../../data/built_in_category_templates.dart';
import '../../data/category_template_file.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../settings/settings_common.dart';

/// Save the current category structure as a reusable template, and switch
/// between saved templates (GitHub #101). Switching never touches a
/// transaction — it only archives categories the target template doesn't
/// have and (re)creates the ones it does, exactly like a manual archive.
///
/// Templates also travel as files (GitHub #187): share one, import one
/// someone shared, or start from a ready-made one such as 50/30/20.
class CategoryTemplatesScreen extends ConsumerWidget {
  const CategoryTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final templatesAsync = ref.watch(categoryTemplatesProvider);

    return Scaffold(
      appBar: AppTopBar(
        title: const Text('Category templates'),
        actions: [
          IconButton(
            tooltip: 'Import from file',
            icon: const AppIcon(Icons.file_open_outlined),
            onPressed: () => _importTemplate(context, ref),
          ),
        ],
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: InlineErrorView(message: "Couldn't load templates"),
          ),
        ),
        data: (templates) => ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            96,
          ).plusNavBar(context),
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
                    AppIcon(
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
              AppCard(
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
            settingsSectionLabel(context, 'Ready-made'),
            AppCard(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (
                    var i = 0;
                    i < kBuiltInCategoryTemplates.length;
                    i++
                  ) ...[
                    if (i > 0) Divider(height: 1, indent: 60),
                    _BuiltInTile(file: kBuiltInCategoryTemplates[i]),
                  ],
                  const Divider(height: 1, indent: 60),
                  const _MoreTemplatesTile(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Save current as template',
        onPressed: () => _saveCurrentAsTemplate(context, ref),
        child: const AppIcon(Icons.add),
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

    return AppListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: AppIcon(
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
          _TemplateAction.share => _shareTemplate(context, ref, template),
          _TemplateAction.rename => _renameTemplate(context, ref, template),
          _TemplateAction.delete => _deleteTemplate(context, ref, template),
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _TemplateAction.apply,
            child: Text('Switch to this template'),
          ),
          PopupMenuItem(
            value: _TemplateAction.share,
            child: Text('Share as file'),
          ),
          PopupMenuItem(value: _TemplateAction.rename, child: Text('Rename')),
          PopupMenuItem(value: _TemplateAction.delete, child: Text('Delete')),
        ],
      ),
      onTap: () => _applyTemplate(context, ref, template),
    );
  }
}

enum _TemplateAction { apply, share, rename, delete }

/// A ready-made template, added to the saved ones with a tap — nothing
/// changes until the user switches to it.
class _BuiltInTile extends ConsumerWidget {
  const _BuiltInTile({required this.file});

  final CategoryTemplateFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 8),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: AppIcon(
          Icons.pie_chart_outline_rounded,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        file.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: file.description == null
          ? null
          : Text(
              file.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: TextButton(
        onPressed: () => _addTemplateFile(context, ref, file),
        child: const Text('Add'),
      ),
    );
  }
}

/// Opens xpenc.in/templates: every template in the XPENC-Templates repo,
/// community ones included, to preview and download. XPENC itself never goes
/// online, so the file comes back in through Import from file.
class _MoreTemplatesTile extends StatelessWidget {
  const _MoreTemplatesTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 16),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: AppIcon(
          Icons.travel_explore_outlined,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        'More templates on xpenc.in',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Student, Family Household and ones shared by the community. '
        'Download one, then use Import from file.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: AppIcon(
        Icons.open_in_new_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: () => openLink(context, AppInfo.templatesUrl),
    );
  }
}

/// Saves [file] as a template, and says so.
Future<void> _addTemplateFile(
  BuildContext context,
  WidgetRef ref,
  CategoryTemplateFile file,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(dbProvider).importCategoryTemplate(file);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('Added "${file.name}" — tap it to switch to it')),
    );
}

/// [template] as a file for the share sheet (a download on XPENC web):
/// category names, colours, icons and nesting only.
Future<void> _shareTemplate(
  BuildContext context,
  WidgetRef ref,
  CategoryTemplateRow template,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = await ref.read(dbProvider).exportCategoryTemplate(template.id);
    await OutgoingFile(
      name: file.fileName,
      bytes: utf8.encode(file.encode()),
      mimeType: 'application/json',
    ).deliver(
      subject: 'XPENC categories: ${template.name}',
      text:
          'My "${template.name}" categories for XPENC. Import it from '
          'Categories → Category templates.',
    );
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text("Couldn't share it: $e")));
  }
}

/// A template file someone shared, added to the saved ones after a look at
/// what's in it.
Future<void> _importTemplate(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  final FilePickerResult? picked;
  try {
    // No extension filter: some Android file managers grey out `.json`
    // under one. Decoding is the real check.
    picked = await FilePicker.platform.pickFiles(withData: true);
  } catch (e) {
    say("Couldn't open a file: $e");
    return;
  }
  final bytes = picked?.files.singleOrNull?.bytes;
  if (picked == null) return; // cancelled
  if (bytes == null) {
    say("Couldn't read that file.");
    return;
  }
  final CategoryTemplateFile file;
  try {
    file = CategoryTemplateFile.decode(utf8.decode(bytes));
  } on FormatException catch (e) {
    say(e.message);
    return;
  }
  if (!context.mounted) return;

  final count = file.categoryCount;
  final add = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Add "${file.name}"?'),
      content: Text(
        [
          ?file.description,
          '$count ${count == 1 ? 'category' : 'categories'}. Nothing changes '
              'until you switch to it.',
        ].join('\n\n'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  if (add != true || !context.mounted) return;
  await _addTemplateFile(context, ref, file);
}

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
  return showAppDialog<String>(
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
  final confirmed = await showAppDialog<bool>(
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
  final confirmed = await showAppDialog<bool>(
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
