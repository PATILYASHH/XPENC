import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_providers.dart';
import '../../core/l10n/l10n.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Settings → Local AI → AI Memory: what Local AI keeps in mind when it
/// answers. Only the user writes here — the AI never saves on its own.
class AiMemoryScreen extends ConsumerWidget {
  const AiMemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final memories = ref.watch(aiMemoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppTopBar(
        title: const Tr('AI Memory'),
        actions: [
          if (memories.isNotEmpty)
            IconButton(
              tooltip: tr('Forget everything'),
              icon: const AppIcon(Icons.delete_sweep_outlined),
              onPressed: () => _forgetAll(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96).plusNavBar(context),
        children: [
          Tr(
            'Local AI reads these every time it answers, so it knows what '
            "matters to you. Only you add them — the AI never saves "
            'anything by itself. They stay on this phone and in your '
            'backups.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (memories.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
              child: Column(
                children: [
                  AppIcon(
                    Icons.psychology_alt_outlined,
                    size: 48,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Tr(
                    'Nothing yet. For example: "My salary comes on the 1st", '
                    '"I\'m saving for a bike by June", "Rent is due on the 5th".',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
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
                  for (var i = 0; i < memories.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 16),
                    AppListTile(
                      title: Text(memories[i].content),
                      onTap: () =>
                          editAiMemory(context, ref, existing: memories[i]),
                      trailing: IconButton(
                        tooltip: tr('Delete'),
                        icon: AppIcon(Icons.delete_outline, color: cs.error),
                        onPressed: () =>
                            ref.read(dbProvider).deleteAiMemory(memories[i].id),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: tr('Add to memory'),
        onPressed: () => editAiMemory(context, ref),
        child: const AppIcon(Icons.add),
      ),
    );
  }

  Future<void> _forgetAll(BuildContext context, WidgetRef ref) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tr('Forget everything?'),
        content: const Tr('Local AI loses everything saved in AI Memory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Tr('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Tr('Forget'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(dbProvider).clearAiMemories();
  }
}

/// Adds a memory (prefilled with [initial]) or edits [existing]. Also what
/// Ask Exo's "Save to memory" opens, so the user always sees and confirms
/// what's kept.
Future<void> editAiMemory(
  BuildContext context,
  WidgetRef ref, {
  AiMemoryRow? existing,
  String? initial,
}) async {
  final controller = TextEditingController(
    text: existing?.content ?? initial ?? '',
  );
  final text = await showAppDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? tr('Add to memory') : tr('Edit memory')),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 300,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: tr('e.g. My salary comes on the 1st'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Tr('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Tr('Save'),
        ),
      ],
    ),
    // Not disposed here — see persons_screen.dart's `_createGroup`.
  );
  if (text == null || text.isEmpty) return;
  final db = ref.read(dbProvider);
  if (existing == null) {
    await db.addAiMemory(text);
  } else {
    await db.updateAiMemory(existing.id, text);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Tr('Saved to AI Memory')));
  }
}
