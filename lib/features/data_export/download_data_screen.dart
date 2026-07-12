import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Export the ledger to a file the user can carry off the phone.
///
/// Nothing here uploads anything — every button writes a file locally and then
/// hands it to the system share sheet, so the data leaves only when the user
/// picks a destination themselves.
class DownloadDataScreen extends ConsumerStatefulWidget {
  const DownloadDataScreen({super.key});

  @override
  ConsumerState<DownloadDataScreen> createState() =>
      _DownloadDataScreenState();
}

class _DownloadDataScreenState extends ConsumerState<DownloadDataScreen> {
  bool _busy = false;
  String? _running;

  Future<void> _export({
    required String tag,
    required Future<File> Function() write,
    required String subject,
  }) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    setState(() {
      _busy = true;
      _running = tag;
    });
    try {
      final f = await write();
      await service.share(f, subject: subject);
      if (!mounted) return;
      final name = f.uri.pathSegments.last;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Exported $name'),
            action: SnackBarAction(
              label: 'Share again',
              onPressed: () => service.share(f, subject: subject),
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't export: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _running = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download Data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const _IntroCard(),
          const SizedBox(height: 16),
          _ExportCard(
            icon: Icons.table_chart_outlined,
            title: 'Transactions (CSV)',
            subtitle: 'Opens in Excel or Google Sheets. Accountant friendly.',
            buttonLabel: 'Export CSV',
            busy: _busy && _running == 'csv',
            enabled: !_busy,
            onPressed: () => _export(
              tag: 'csv',
              write: () => ref.read(backupServiceProvider).writeCsv(),
              subject: 'XPENC transactions',
            ),
          ),
          const SizedBox(height: 12),
          _ExportCard(
            icon: Icons.data_object_outlined,
            title: 'Everything (JSON)',
            subtitle:
                'A complete copy of every account, transaction, budget and '
                'person.',
            buttonLabel: 'Export JSON',
            busy: _busy && _running == 'json',
            enabled: !_busy,
            onPressed: () => _export(
              tag: 'json',
              write: () => ref.read(backupServiceProvider).writeJson(),
              subject: 'XPENC data',
            ),
          ),
        ],
      ),
    );
  }
}

/// Reassures the user that exporting is a deliberate, local-first action.
class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Your data never leaves this phone unless you choose to share '
                'it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One export format: an icon, a plain-language description and a button that
/// spins while its file is being written.
class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: cs.onSurface, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: enabled ? onPressed : null,
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
