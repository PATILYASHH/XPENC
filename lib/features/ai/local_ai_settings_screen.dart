import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/ai_providers.dart';
import '../../core/ai/ai_store.dart';
import '../../core/l10n/l10n.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../core/widgets/open_link.dart';

/// Where models come from — a page on the XPENC site listing open models
/// that run well on a phone, with direct download links. XPENC itself never
/// downloads anything (it has no internet permission).
const localAiModelsUrl = 'https://xpenc.in/local-ai';

/// Settings → Local AI: the switch, the two model files, AI Memory.
class LocalAiSettingsScreen extends ConsumerWidget {
  const LocalAiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(aiStateProvider);
    final device = async.valueOrNull ?? const AiDeviceState();
    final memories = ref.watch(aiMemoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Local AI')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32).plusNavBar(context),
        children: [
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(Icons.auto_awesome_outlined, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Tr(
                      'Ask about your money and get answers, right on this '
                      'phone. Local AI only reads your XPENC data — it never '
                      'changes anything, needs no internet, and nothing '
                      'leaves the phone.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: AppSwitchListTile(
              title: const Tr('Use Local AI'),
              subtitle: const Tr(
                'Shows Ask XPENC (✨) on the Dashboard and Stats',
              ),
              value: device.enabled,
              onChanged: async.isLoading
                  ? null
                  : (v) => ref.read(aiStateProvider.notifier).setEnabled(v),
            ),
          ),
          if (device.enabled) ...[
            const SizedBox(height: 24),
            _ModelCard(
              kind: AiModelKind.chat,
              title: tr('AI model'),
              model: device.chat,
              hint: tr(
                'Small (about 490 MB) suits phones with 4 GB of memory. '
                'Better (about 1.1 GB) needs 6 GB or more.',
              ),
            ),
            const SizedBox(height: 16),
            _ModelCard(
              kind: AiModelKind.speech,
              title: tr('Voice input (optional)'),
              model: device.speech,
              hint: tr(
                'Tap 🎤 in Ask XPENC and speak your question. About 30–60 MB.',
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  AppListTile(
                    leading: const AppIcon(Icons.psychology_alt_outlined),
                    title: const Tr('AI Memory'),
                    subtitle: Text(
                      memories.isEmpty
                          ? tr('Things the AI should keep in mind')
                          : plural(
                              memories.length,
                              tr('1 thing to keep in mind'),
                              tr('{0} things to keep in mind'),
                            ),
                    ),
                    trailing: const AppIcon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/more/settings/local-ai/memory'),
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  AppListTile(
                    leading: const AppIcon(Icons.forum_outlined),
                    title: const Tr('Ask XPENC'),
                    subtitle: const Tr('Try it'),
                    trailing: const AppIcon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/ai'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Tr(
            'The models are open models by other makers, listed on '
            'xpenc.in/local-ai. AI can be wrong — every answer shows the '
            'figures it was based on, so you can check.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends ConsumerStatefulWidget {
  const _ModelCard({
    required this.kind,
    required this.title,
    required this.model,
    required this.hint,
  });

  final AiModelKind kind;
  final String title;
  final AiModelFile? model;
  final String hint;

  @override
  ConsumerState<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends ConsumerState<_ModelCard> {
  /// null when idle; 0..1 while copying; -1 while the file picker prepares
  /// the file or the model is being checked.
  double? _progress;
  String? _status;

  static String _size(int bytes) {
    final mb = bytes / (1024 * 1024);
    return mb >= 1024
        ? '${(mb / 1024).toStringAsFixed(1)} GB'
        : '${mb.round()} MB';
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _import() async {
    final controller = ref.read(aiStateProvider.notifier);
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        onFileLoading: (status) {
          if (!mounted) return;
          setState(() {
            _progress = status == FilePickerStatus.picking ? -1 : null;
            _status = status == FilePickerStatus.picking
                ? tr('Getting the file ready…')
                : null;
          });
        },
      );
    } catch (_) {
      picked = null;
    }
    final file = picked?.files.singleOrNull;
    if (file?.path == null) {
      if (mounted) setState(() => _progress = _status = null);
      return;
    }
    setState(() {
      _progress = 0;
      _status = tr('Importing…');
    });
    try {
      await controller.importModel(
        widget.kind,
        file!.path!,
        displayName: file.name,
        // The picker's copy lives in app storage; move it, don't copy again.
        move: true,
        onProgress: (f) {
          if (mounted) setState(() => _progress = f);
        },
      );
      if (!mounted) return;
      setState(() {
        _progress = -1;
        _status = tr('Checking the model on this phone…');
      });
      final engine = await controller.ready(widget.kind);
      // Checked; let it go until a question needs it, so a big model
      // doesn't sit in memory meanwhile.
      if (widget.kind == AiModelKind.chat) {
        await engine.unloadChat();
      } else {
        await engine.unloadSpeech();
      }
      _snack(tr('Ready — {0}', [file.name]));
    } on AiModelRejected catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(
        tr(
          "This model couldn't start on this phone. It may need more "
          'memory than the phone has free — try a smaller one.',
        ),
      );
    } finally {
      if (mounted) setState(() => _progress = _status = null);
      await FilePicker.platform.clearTemporaryFiles();
    }
  }

  Future<void> _remove() async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tr('Remove this model?'),
        content: const Tr(
          'It frees the space it takes. You can import it again any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Tr('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Tr('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(aiStateProvider.notifier).removeModel(widget.kind);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final model = widget.model;
    final busy = _progress != null;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                AppIcon(
                  model == null
                      ? Icons.download_for_offline_outlined
                      : Icons.check_circle_outline_rounded,
                  color: model == null ? cs.onSurfaceVariant : cs.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model?.name ?? tr('No model yet'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (model != null)
                        Text(
                          _size(model.bytes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (model != null && !busy)
                  IconButton(
                    tooltip: tr('Remove'),
                    icon: AppIcon(Icons.delete_outline, color: cs.error),
                    onPressed: _remove,
                  ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progress! < 0 ? null : _progress,
                  minHeight: 6,
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 6),
                Text(
                  _status!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const AppIcon(Icons.open_in_new_rounded, size: 18),
                    label: const Tr('Get models'),
                    onPressed: () => openLink(context, localAiModelsUrl),
                  ),
                  FilledButton.tonalIcon(
                    icon: const AppIcon(Icons.file_open_outlined, size: 18),
                    label: Text(model == null ? tr('Import') : tr('Replace')),
                    onPressed: _import,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              widget.hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
