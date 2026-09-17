import 'package:flutter/material.dart';

import '../app_icons.dart';

/// Renders a `TransactionRow.customIcon` value — see the doc on
/// `Transactions.customIcon` for the two encodings this parses: an XPENC
/// icon-library pick (`"icon:<key>"`) or a raw emoji typed via the device's
/// own keyboard.
class CustomIconBadge extends StatelessWidget {
  const CustomIconBadge({
    required this.value,
    this.size = 40,
    this.color,
    this.scaled = true,
    super.key,
  });

  final String value;
  final double size;
  final Color? color;

  /// True (the default) sizes the glyph down from [size] the way a badge
  /// sitting inside a same-diameter circle wants — see the hero icon on
  /// transaction/goal/loan detail screens. Pass false to render the glyph
  /// at exactly [size] instead, as a drop-in replacement for a plain
  /// `Icon(fallback, size: size, color: color)` inside a row's own
  /// `CircleAvatar`/container, which already supplies its own padding.
  final bool scaled;

  static const _iconPrefix = 'icon:';

  static bool isIconKey(String value) => value.startsWith(_iconPrefix);

  /// The `AppIcons` key encoded in [value], or null if [value] is a raw
  /// emoji instead.
  static String? iconKeyOf(String value) =>
      isIconKey(value) ? value.substring(_iconPrefix.length) : null;

  static String encodeIconKey(String key) => '$_iconPrefix$key';

  @override
  Widget build(BuildContext context) {
    final key = iconKeyOf(value);
    final iconSize = scaled ? size * 0.55 : size;
    final emojiSize = scaled ? size * 0.6 : size;
    if (key != null) {
      return Icon(AppIcons.resolve(key), size: iconSize, color: color);
    }
    return Text(value, style: TextStyle(fontSize: emojiSize));
  }
}

/// Drop-in replacement for a row's `Icon(fallback, size: size, color: color)`
/// — [customIcon] (a `TransactionRow.customIcon`) takes over when set,
/// rendered at the same [size] the fallback icon would have used.
Widget transactionRowIcon({
  required String? customIcon,
  required IconData fallback,
  required double size,
  required Color color,
}) {
  if (customIcon == null) return Icon(fallback, size: size, color: color);
  return CustomIconBadge(
    value: customIcon,
    size: size,
    color: color,
    scaled: false,
  );
}
