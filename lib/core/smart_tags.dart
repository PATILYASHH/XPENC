import 'package:intl/intl.dart';

/// Smart tags (GitHub #189): a tag whose name holds a date part —
/// `{month}`, `{mon}`, `{year}` or `{quarter}` — lands on a transaction as
/// the plain tag that part reads on the transaction's own date. "{month}
/// {year}" on a template saves as "December 2026" in December and as
/// "January 2027" a month later, without anyone touching the template.
///
/// The pattern lives in the tag's name, so a smart tag is an ordinary
/// `Tags` row: templates, Auto rules, tag groups, modes and backups carry
/// it unchanged. Only `AppDatabase.resolveSmartTags` reads it, when tags
/// are written onto a transaction or person entry.
abstract final class SmartTags {
  /// The date parts, as typed between braces.
  static const parts = ['month', 'mon', 'year', 'quarter'];

  /// Same limit as `Tags.name`.
  static const maxLength = 30;

  static final _part = RegExp(
    r'\{(month|mon|year|quarter)\}',
    caseSensitive: false,
  );
  static final _spaces = RegExp(r'\s+');

  /// Whether [name] holds at least one date part. A brace that isn't one
  /// ("{work}") is plain text, so an ordinary tag never turns smart.
  static bool isSmart(String name) => _part.hasMatch(name);

  /// [pattern] as it reads on [date]: month names in the interface
  /// language (stand-alone form, so Russian gets "декабрь", not
  /// "декабря"), cut to [maxLength] like any tag name.
  static String resolve(String pattern, DateTime date) {
    final text = pattern
        .replaceAllMapped(
          _part,
          (m) => switch (m[1]!.toLowerCase()) {
            'month' => DateFormat('LLLL').format(date),
            'mon' => DateFormat('LLL').format(date),
            'year' => '${date.year}',
            _ => 'Q${(date.month - 1) ~/ 3 + 1}',
          },
        )
        .replaceAll(_spaces, ' ')
        .trim();
    return text.length > maxLength
        ? text.substring(0, maxLength).trimRight()
        : text;
  }

  /// What a tag shows on something dated [date]: a smart tag as it will
  /// read once saved, any other tag as its name.
  static String label(String name, DateTime date) =>
      isSmart(name) ? resolve(name, date) : name;
}
