import 'package:intl/intl.dart';

/// `xpenc-ram-statement-20261008-1042` — safe on every filesystem. Handing
/// the file on is `OutgoingFile.deliver`'s job.
String shareFileStem(String what) {
  final slug = what
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
  return 'xpenc-${slug.isEmpty ? 'share' : slug}-$stamp';
}
