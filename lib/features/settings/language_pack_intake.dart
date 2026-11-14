import 'dart:convert';
import 'dart:io';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/language_pack.dart';
import '../../data/category_template_file.dart';

/// What a JSON file opened with XPENC turned out to be (GitHub #191): a
/// language pack from xpenc.in/languages, or something else, with a pointer
/// to where that does belong.
sealed class OpenedFile {
  const OpenedFile();
}

class OpenedLanguagePack extends OpenedFile {
  const OpenedLanguagePack(this.pack);
  final LanguagePack pack;
}

class OpenedOtherFile extends OpenedFile {
  const OpenedOtherFile(this.message);

  /// Ready to show as is.
  final String message;
}

/// Far above any real pack (the whole app is ~250 KB of text), low enough
/// that opening a huge file can't stall the app.
const maxOpenedFileBytes = 4 * 1024 * 1024;

/// Reads the file at [path] — the opening app's file, copied into XPENC's
/// cache — and deletes that copy. Never throws.
Future<OpenedFile> readOpenedFile(String path) async {
  final file = File(path);
  try {
    final size = await file.length();
    if (size > maxOpenedFileBytes) {
      // Too big to be a pack — but a backup is often this big.
      final head = await file.openRead(0, 512).expand((b) => b).toList();
      return classifyOpenedFile(
        utf8.decode(head, allowMalformed: true),
        truncated: true,
      );
    }
    return classifyOpenedFile(
      utf8.decode(await file.readAsBytes(), allowMalformed: true),
    );
  } catch (_) {
    return OpenedOtherFile(tr("Couldn't read that file."));
  } finally {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover cache file is harmless.
    }
  }
}

/// [text] is the file's contents — only its start when [truncated].
OpenedFile classifyOpenedFile(String text, {bool truncated = false}) {
  if (!truncated) {
    try {
      return OpenedLanguagePack(LanguagePack.decode(text));
    } on FormatException catch (e) {
      final other = _elsewhere(text, truncated: false);
      if (other != null) return other;
      return OpenedOtherFile(e.message);
    }
  }
  return _elsewhere(text, truncated: true) ??
      OpenedOtherFile(tr("That isn't an XPENC language pack."));
}

/// A backup or a category template opened by mistake — XPENC's own files,
/// imported from their own screens.
OpenedOtherFile? _elsewhere(String text, {required bool truncated}) {
  // A backup starts with these keys (AppDatabase.exportAll), so the
  // first bytes are enough even for one too big to read whole.
  final head = text.length > 512 ? text.substring(0, 512) : text;
  if (head.contains('"schemaVersion"') && head.contains('"exportedAt"')) {
    return OpenedOtherFile(
      tr(
        'That is an XPENC backup. To restore it, open Backup & Restore '
        'and tap Import from file.',
      ),
    );
  }
  if (truncated) return null;
  try {
    final json = jsonDecode(text);
    if (json is Map && json['format'] == CategoryTemplateFile.format) {
      return OpenedOtherFile(
        tr(
          'That is a category template. To add it, open Categories → '
          'Templates and tap Import from file.',
        ),
      );
    }
  } catch (_) {
    // Not JSON at all — the pack's own message says so.
  }
  return null;
}
