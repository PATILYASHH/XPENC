import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding/app_info.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import 'ocr_correction_export.dart';

/// Settings > Message Capture > OCR corrections. See
/// docs/superpowers/specs/2026-08-14-ocr-corrections-design.md.
class OcrCorrectionScreen extends ConsumerWidget {
  const OcrCorrectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pending =
        ref.watch(pendingOcrCorrectionsProvider).valueOrNull ?? const [];
    final sent = ref.watch(sentOcrCorrectionsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('OCR corrections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/more/capture/ocr-feedback/new'),
        icon: const Icon(Icons.add),
        label: const Text('Test a screenshot'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Optional and entirely on-device. Pick a screenshot to see '
                "what OCR reads and mark whether it's right. Sharing a "
                'correction hands over only the extracted text — never the '
                'image — to ${AppInfo.feedbackEmail}, and only if you tap '
                'the button below.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (pending.isEmpty && sent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No corrections yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          for (final row in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Slidable(
                key: ValueKey(row.id),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) =>
                          ref.read(dbProvider).deleteOcrCorrection(row.id),
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                    ),
                  ],
                ),
                child: _CorrectionTile(row: row),
              ),
            ),
          if (sent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
              child: Text(
                'SENT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            for (final row in sent)
              Opacity(
                opacity: 0.6,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CorrectionTile(row: row),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: pending.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ids = pending.map((r) => r.id).toList();
                    try {
                      await sendOcrCorrections(pending);
                    } catch (_) {
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Couldn't open anything to send this — your "
                              'corrections are still saved, try again later.',
                            ),
                          ),
                        );
                      return;
                    }
                    await ref.read(dbProvider).markOcrCorrectionsSent(ids);
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('Opened for sending')),
                      );
                  },
                  child: Text(
                    'Send ${pending.length} correction'
                    '${pending.length == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ),
    );
  }
}

class _CorrectionTile extends StatelessWidget {
  const _CorrectionTile({required this.row});

  final OcrCorrectionRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(
          row.wasCorrect ? Icons.check_circle_outline : Icons.error_outline,
          color: row.wasCorrect
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
        title: Text(row.appLabel),
        subtitle: Text(
          row.rawOcrText.split('\n').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
