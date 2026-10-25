import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connector/connector_handoff.dart';
import '../../core/platform/platform_features.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../connector/connector_inbox_runner.dart';

/// Import a backup file the app didn't necessarily write itself — any
/// `.json` produced by "Everything (JSON)" on the Download Data screen or
/// by a backup made on another phone. Picks a file, confirms the
/// destructive replace, then restores it through
/// `BackupService.restoreFromContent`.
///
/// Shared by the Backup screen and the Download Data screen so this
/// data-destructive flow has exactly one implementation — not two that
/// could quietly drift apart.
///
/// [setBusy], if given, is only toggled around the actual create-safety-copy
/// + restore work — not around picking a file or the confirmation dialog —
/// so a caller's "busy" spinner matches exactly when something irreversible
/// is in flight.
Future<void> importDataFromFile(
  BuildContext context,
  WidgetRef ref, {
  void Function(bool busy)? setBusy,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final FilePickerResult? picked;
  try {
    // Deliberately not filtering by extension: some Android file managers
    // grey out `.json` under a custom filter, which would make a real backup
    // unpickable. `restoreFromContent` is the real gate — it rejects
    // anything that isn't an XPENC backup with a clear message.
    picked = await FilePicker.platform.pickFiles(withData: true);
  } catch (e) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text("Couldn't open a file: $e")));
    return;
  }
  if (picked == null || picked.files.isEmpty) return; // cancelled

  final file = picked.files.single;
  // Prefer the in-memory bytes (withData); fall back to reading the path.
  // The bytes themselves are kept: Connector recognises its file by them.
  List<int> bytes;
  String content;
  try {
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    } else {
      throw const FormatException('empty selection');
    }
    content = utf8.decode(bytes);
  } catch (_) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text("Couldn't read that file.")));
    return;
  }

  if (!context.mounted) return;
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Import this file?'),
      content: Text(
        'Importing "${file.name}" replaces ALL current data on this phone — '
        'every account, transaction, budget and person — with its contents. '
        'A safety copy of your current data is saved first, so this can be '
        'undone by restoring that copy.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Replace everything'),
        ),
      ],
    ),
  );
  if (!context.mounted || confirmed != true) return;

  final service = ref.read(backupServiceProvider);
  setBusy?.call(true);
  try {
    await service.createBackup(); // safety copy first
    await service.restoreFromContent(content);
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Imported. A safety copy of your previous data was saved.',
          ),
        ),
      );
    // A Connector that shares its inbox is told directly; an older one
    // only through its link, for the file it pulled.
    final told = await reportImportToConnector(ref, bytes);
    if (!context.mounted) return;
    if (told == null &&
        PlatformFeatures.connectorHandoff &&
        file.name == connectorPulledFileName) {
      await _offerConnectorHandoff(context, messenger, bytes);
    }
  } on ArgumentError catch (e) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${e.message} Nothing was changed.')),
      );
  } catch (e) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text("Couldn't import: $e Nothing was changed.")),
      );
  } finally {
    setBusy?.call(false);
  }
}

/// The file was the backup Connector pulled from another phone. Connector
/// holds this phone's uploads until it knows the import happened — saying
/// so here, in one tap, beats remembering to go back and do it there.
Future<void> _offerConnectorHandoff(
  BuildContext context,
  ScaffoldMessengerState messenger,
  List<int> bytes,
) async {
  final tell = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Let Connector know?'),
      content: const Text(
        'This backup came from Connector. Tell it the import is done, so '
        'backups from this phone carry on syncing from here.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Tell Connector'),
        ),
      ],
    ),
  );
  if (tell != true) return;
  if (!await tellConnectorImported(bytes)) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open Connector. In Connector, tap \"I've imported "
            'it" instead.',
          ),
        ),
      );
  }
}
