import 'package:flutter/material.dart';

import 'app_surfaces.dart';

/// A long-press actions sheet (title + a list of option tiles) that never
/// hides options behind the bottom nav.
///
/// Opens on the root navigator, so it sits above the shell's bottom nav
/// instead of underneath it, and is a [DraggableScrollableSheet]: it opens
/// tall enough to show every option when the screen allows (capped at 75%),
/// and on a short screen the user drags the handle up (to 95%) and scrolls
/// for the rest. The handle lives inside the scroll view — the built-in
/// `showDragHandle` handle only drags the sheet down, never up.
///
/// [optionCount] sizes the sheet; it's an estimate (two-line tiles), and
/// scrolling covers anything it gets wrong.
Future<T?> showActionSheet<T>({
  required BuildContext context,
  required String title,
  required int optionCount,
  required List<Widget> Function(BuildContext sheetContext) options,
}) {
  return showAppSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final theme = Theme.of(sheetContext);
      // handle 36 + title 44 + tiles ~72 each (text-scaled) + bottom breathing
      // room and the system nav inset.
      final tileHeight = media.textScaler.scale(72);
      final contentHeight =
          36 + 44 + optionCount * tileHeight + 16 + media.viewPadding.bottom;
      final fit = contentHeight / media.size.height;
      final maxSize = fit.clamp(0.3, 0.95).toDouble();
      final initialSize = fit.clamp(0.3, 0.75).toDouble();

      return DraggableScrollableSheet(
        expand: false,
        snap: true,
        initialChildSize: initialSize,
        minChildSize: 0.25,
        maxChildSize: maxSize,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: EdgeInsets.only(bottom: 16 + media.viewPadding.bottom),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...options(sheetContext),
          ],
        ),
      );
    },
  );
}
