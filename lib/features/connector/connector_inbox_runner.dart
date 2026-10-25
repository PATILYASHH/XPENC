import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/connector/connector_handoff.dart' show gitBlobSha;
import '../../core/connector/inbox/connector_inbox.dart';
import '../../core/connector/inbox/sync_memory.dart';
import '../../core/platform/platform_features.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';

sealed class InboxCheck {
  const InboxCheck();
}

final class InboxNothing extends InboxCheck {
  const InboxNothing();
}

final class InboxApplied extends InboxCheck {
  const InboxApplied(this.backup);
  final PendingBackup backup;
}

final class InboxNeedsAnswer extends InboxCheck {
  const InboxNeedsAnswer(this.backup);
  final PendingBackup backup;
}

/// Takes in a backup the Connector app pulled from another device — by
/// itself when this phone's data is exactly what its last sync left, and
/// only after asking when this phone has data the backup doesn't. Either
/// way a safety copy is saved first, and Connector is told afterwards, so
/// there's no Import from file and no "I've imported it".
class ConnectorInboxRunner {
  ConnectorInboxRunner({
    required this.ledger,
    required this.channel,
    required this.memory,
  });

  final InboxLedger ledger;
  final ConnectorInboxChannel channel;
  final SyncMemory memory;

  /// [dismissedSha]: a backup the user said "Not now" to this session.
  Future<InboxCheck> check({String? dismissedSha}) async {
    final inbox = await channel.read();
    final pending = inbox?.pending;
    if (inbox == null || pending == null) return const InboxNothing();
    final remembered = await memory.load();
    final action = decideInbox(
      inbox: inbox,
      currentFingerprint: dataFingerprint(await ledger.export()),
      memory: remembered,
      dismissedSha: dismissedSha,
    );
    switch (action) {
      case InboxAction.nothing:
        return const InboxNothing();
      case InboxAction.confirm:
        await channel.confirmImport(
          pending.sha,
          remembered.importedAt(pending.sha)!,
        );
        return const InboxNothing();
      case InboxAction.applyNow:
        await apply(pending);
        return InboxApplied(pending);
      case InboxAction.ask:
        return InboxNeedsAnswer(pending);
    }
  }

  /// Takes [backup] in: safety copy, import, then tells Connector.
  Future<void> apply(PendingBackup backup) async {
    final bytes = await channel.readPending();
    // The exact file Connector described, or nothing changes.
    if (gitBlobSha(bytes) != backup.sha) {
      throw StateError('The waiting backup changed. Try again.');
    }
    await ledger.saveSafetyCopy();
    await ledger.replaceWith(utf8.decode(bytes));
    final at = DateTime.now();
    await memory.recordImported(
      bytes,
      dataFingerprint(await ledger.export()),
      at,
    );
    await channel.confirmImport(backup.sha, at);
  }
}

/// The ledger as the runner needs it.
abstract interface class InboxLedger {
  Future<Map<String, dynamic>> export();

  /// A backup of the data as it is, before it's replaced.
  Future<void> saveSafetyCopy();

  /// XPENC's own import: validated, all-or-nothing.
  Future<void> replaceWith(String backupJson);
}

class _AppLedger implements InboxLedger {
  _AppLedger(this._ref);
  final Ref _ref;

  @override
  Future<Map<String, dynamic>> export() => _ref.read(dbProvider).exportAll();

  @override
  Future<void> saveSafetyCopy() =>
      _ref.read(backupServiceProvider).createBackup();

  @override
  Future<void> replaceWith(String backupJson) =>
      _ref.read(backupServiceProvider).restoreFromContent(backupJson);
}

final connectorInboxRunnerProvider = Provider<ConnectorInboxRunner>(
  (ref) => ConnectorInboxRunner(
    ledger: _AppLedger(ref),
    channel: const AndroidConnectorInboxChannel(),
    memory: connectorSyncMemory,
  ),
);

/// After Import from file: remember what was taken in, and if it's the
/// backup Connector has waiting, tell it. Null when there's no Connector
/// that understands this (none installed, or an older one).
Future<bool?> reportImportToConnector(WidgetRef ref, List<int> bytes) async {
  if (!PlatformFeatures.connectorHandoff) return null;
  final runner = ref.read(connectorInboxRunnerProvider);
  final at = DateTime.now();
  try {
    await runner.memory.recordImported(
      bytes,
      dataFingerprint(await runner.ledger.export()),
      at,
    );
    final inbox = await runner.channel.read();
    if (inbox == null) return null;
    final pending = inbox.pending;
    if (pending == null || pending.sha != gitBlobSha(bytes)) return false;
    return await runner.channel.confirmImport(pending.sha, at);
  } catch (_) {
    return null;
  }
}

String _when(DateTime t) => DateFormat('d MMM, h:mm a').format(t.toLocal());

/// Shown when [backup] would replace data this phone has that it doesn't.
/// True: the user chose to take it in.
Future<bool> askToTakeIn(PendingBackup backup) async {
  final context = appRouter.routerDelegate.navigatorKey.currentContext;
  if (context == null) return false;
  final yes = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Newer backup from ${backup.from}'),
      content: Text(
        'Made ${_when(backup.backupModifiedAt)}. This phone has changes '
        "that aren't in it — using it replaces this phone's data (a copy "
        'of it is saved first). Until you choose, Connector keeps backups '
        'from this phone back.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Use it'),
        ),
      ],
    ),
  );
  return yes == true;
}

void announceTakenIn(PendingBackup backup) => showAppSnackBar(
  'Updated with the backup from ${backup.from} '
  '(${_when(backup.backupModifiedAt)}). A copy of the previous data is in '
  'Backup & Restore.',
);
