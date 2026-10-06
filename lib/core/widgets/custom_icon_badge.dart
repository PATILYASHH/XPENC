import 'package:flutter/material.dart';

import '../app_icons.dart';
import '../theme/glass.dart';
import 'app_surfaces.dart';

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
      return AppIcon(AppIcons.resolve(key), size: iconSize, color: color);
    }
    return Text(value, style: TextStyle(fontSize: emojiSize));
  }
}

/// Drop-in replacement for a row's `Icon(fallback, size: size, color: color)`
/// — [customIcon] (a `TransactionRow.customIcon`) takes over when set,
/// rendered at the same [size] the fallback icon would have used.
///
/// Under Glass the glyph sits on a glossy [GlassIconTile] of [color] that
/// fills the row's own icon well, white on colour — the premium treatment.
Widget transactionRowIcon({
  required String? customIcon,
  required IconData fallback,
  required double size,
  required Color color,
}) => Builder(
  builder: (context) {
    if (!AppSurface.of(context).isGlass) {
      return _plainRowIcon(customIcon, fallback, size, color);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final extent = box.hasBoundedWidth && box.hasBoundedHeight
            ? (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight)
            : size * 2;
        return GlassIconTile(
          color: color,
          extent: extent,
          child: customIcon == null
              ? AppIcon(fallback, size: extent * 0.5, color: Colors.white)
              : CustomIconBadge(
                  value: customIcon,
                  size: extent * 0.5,
                  color: Colors.white,
                  scaled: false,
                ),
        );
      },
    );
  },
);

Widget _plainRowIcon(
  String? customIcon,
  IconData fallback,
  double size,
  Color color,
) {
  if (customIcon == null) return AppIcon(fallback, size: size, color: color);
  return CustomIconBadge(
    value: customIcon,
    size: size,
    color: color,
    scaled: false,
  );
}

/// The icon inside a tinted icon well (a fixed-size circle or rounded square
/// washed with the icon's colour). Outside Glass it is exactly
/// `AppIcon(icon, size: size, color: color)`; under Glass it fills the well
/// with a glossy [GlassIconTile] of [color] and a white glyph.
class IconWell extends StatelessWidget {
  const IconWell(this.icon, {this.size, this.color, super.key});

  final IconData? icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final surface = AppSurface.of(context);
    if (!surface.isGlass) return AppIcon(icon, size: size, color: color);
    final glyph = size ?? 24;
    return LayoutBuilder(
      builder: (context, box) {
        final extent = box.hasBoundedWidth && box.hasBoundedHeight
            ? (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight)
            : glyph * 2;
        return GlassIconTile(
          color: color ?? Theme.of(context).colorScheme.secondary,
          extent: extent,
          child: AppIcon(icon, size: extent * 0.5, color: Colors.white),
        );
      },
    );
  }
}
