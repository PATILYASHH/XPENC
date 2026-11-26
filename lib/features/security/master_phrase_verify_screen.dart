import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/master_phrase_field.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../core/l10n/l10n.dart';
import '../data_export/backup_service.dart' show BackupLock;

/// Turning the master phrase off requires re-entering it — same reasoning
/// as "Remove passcode" re-verifying the current PIN even though you're
/// already inside Settings: it proves whoever is disabling the fallback
/// actually has it. GitHub #74.
class MasterPhraseVerifyScreen extends ConsumerStatefulWidget {
  const MasterPhraseVerifyScreen({super.key});

  @override
  ConsumerState<MasterPhraseVerifyScreen> createState() =>
      _MasterPhraseVerifyScreenState();
}

class _MasterPhraseVerifyScreenState
    extends ConsumerState<MasterPhraseVerifyScreen> {
  String? _error;
  bool _checking = false;

  Future<void> _onSubmit(List<String> words) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await ref.read(dbProvider).verifyMasterPhrase(words);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _checking = false;
        _error = tr('Wrong phrase');
      });
      return;
    }
    // Backups locked with this phrase stay locked with it (#210).
    var lockedBackups = false;
    try {
      lockedBackups =
          await ref.read(backupServiceProvider).backupLock() ==
          BackupLock.recoveryPhrase;
    } catch (_) {}
    await ref.read(dbProvider).clearMasterPhrase();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: lockedBackups
              ? const Duration(seconds: 8)
              : const Duration(seconds: 4),
          content: Text(
            lockedBackups
                ? tr(
                    'Master recovery phrase turned off. Your backups are '
                    'still locked with it — keep the words, or switch them '
                    'to a password in Backup & Restore.',
                  )
                : tr('Master recovery phrase turned off'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppTopBar(title: const Tr('Turn off recovery phrase')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tr(
                'Enter your master recovery phrase to turn this off.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              MasterPhraseField(
                submitLabel: tr('Turn off'),
                error: _error,
                busy: _checking,
                onSubmit: _onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
