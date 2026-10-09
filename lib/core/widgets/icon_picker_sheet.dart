import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../app_icons.dart';
import 'app_surfaces.dart';
import 'custom_icon_badge.dart';
import 'nav_bar_inset.dart';

/// Opens the icon picker and resolves to the chosen key, or `null` if the
/// sheet was dismissed without a pick. [accentColor] tints the selected tile
/// and the "Frequently used" row — pass whatever colour the caller's own
/// entity (category, account, ...) is using, so the preview matches what
/// saving will actually look like.
///
/// [allowEmoji] adds an "Emoji" section on top: the user's own emoji, typed
/// with their keyboard, resolved as an `AppIcons.encodeEmoji` key. Only pass
/// it where every place that draws the key handles one (`KeyIcon`,
/// `IconWell.forKey`) — categories do; accounts and goals don't.
Future<String?> showIconPickerSheet(
  BuildContext context, {
  required String? selected,
  Color? accentColor,
  bool allowEmoji = false,
}) {
  return showAppSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _IconPickerSheet(
      selected: selected,
      accentColor: accentColor,
      allowEmoji: allowEmoji,
    ),
  );
}

/// A small sheet with one text field that brings up the user's own keyboard,
/// emoji key included — rather than a bundled emoji browser, which would need
/// an extra dependency and an emoji data set of its own to maintain. Resolves
/// to the trimmed text, or `null` if dismissed.
///
/// [maxLength] counts characters as the user sees them (grapheme clusters),
/// so a skin-toned or ZWJ emoji is one.
Future<String?> showEmojiInputSheet(
  BuildContext context, {
  String initial = '',
  int maxLength = 8,
}) {
  // Pre-selected, so typing a new emoji replaces the current one.
  final controller = TextEditingController(text: initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  final result = showAppSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom:
            MediaQuery.of(sheetContext).padding.bottom +
            MediaQuery.of(sheetContext).viewInsets.bottom +
            20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Emoji',
            style: Theme.of(
              sheetContext,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('emojiInputField'),
            controller: controller,
            autofocus: true,
            textAlign: TextAlign.center,
            maxLength: maxLength,
            style: const TextStyle(fontSize: 40),
            decoration: const InputDecoration(hintText: '🙂', counterText: ''),
            onSubmitted: (v) => Navigator.of(sheetContext).pop(v.trim()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                Navigator.of(sheetContext).pop(controller.text.trim()),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
  // Deliberately not disposed — see the same note in persons_screen.dart's
  // _createGroup: disposing right after the sheet resolves can crash the
  // TextField mid exit-transition.
  return result;
}

class _IconPickerSheet extends ConsumerStatefulWidget {
  const _IconPickerSheet({
    required this.selected,
    required this.accentColor,
    required this.allowEmoji,
  });

  final String? selected;
  final Color? accentColor;
  final bool allowEmoji;

  @override
  ConsumerState<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends ConsumerState<_IconPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "car_repair" -> "Car repair" — the keys are already short, descriptive
  /// slugs, so a plain underscore swap reads fine without a separate label
  /// table to keep in sync with `AppIcons`.
  static String _label(String key) {
    final spaced = key.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  List<String> _filter(List<String> keys) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return keys;
    return keys.where((k) => _label(k).toLowerCase().contains(q)).toList();
  }

  void _pick(String key) {
    ref.read(dbProvider).recordIconUsed(key);
    Navigator.of(context).pop(key);
  }

  /// One emoji per icon: a category badge is a single glyph, and anything
  /// longer wouldn't fit the icon-key column's 40 characters anyway.
  Future<void> _typeEmoji() async {
    final typed = await showEmojiInputSheet(
      context,
      initial: AppIcons.emojiOf(widget.selected) ?? '',
      maxLength: 1,
    );
    if (typed == null || typed.isEmpty || !mounted) return;
    final key = AppIcons.encodeEmoji(typed.characters.first);
    if (key.length > 40) return;
    _pick(key);
  }

  /// Emoji the user has already used, newest pick first, then any still on a
  /// category — so a favourite is one tap away for the next category.
  List<String> _knownEmojiKeys() {
    final keys = <String>{
      if (AppIcons.emojiOf(widget.selected) != null) widget.selected!,
      ...ref
          .watch(frequentIconKeysProvider)
          .where((k) => AppIcons.emojiOf(k) != null),
      for (final c in ref.watch(categoryMapProvider).values)
        if (AppIcons.emojiOf(c.iconKey) != null) c.iconKey,
    };
    return keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.accentColor ?? theme.colorScheme.secondary;
    // Frequent keys can outlive an icon that's since been removed from
    // AppIcons — drop anything that no longer resolves rather than showing a
    // fallback circle for a key that isn't pickable any more.
    final frequent = _filter(
      ref
          .watch(frequentIconKeysProvider)
          .where(AppIcons.allKeys.contains)
          .toList(),
    );
    final all = _filter(AppIcons.allKeys);
    final showEmoji = widget.allowEmoji && _query.trim().isEmpty;
    final emoji = showEmoji ? _knownEmojiKeys() : const <String>[];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Icon', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('iconPickerSearch'),
                controller: _controller,
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const AppIcon(Icons.search),
                  hintText: 'Search icons',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: all.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No icon matches "$_query".',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12).plusNavBar(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showEmoji) ...[
                            _sectionLabel(theme, 'Emoji'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _addEmojiTile(theme),
                                for (final k in emoji)
                                  _iconTile(theme, k, accent),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (frequent.isNotEmpty) ...[
                            _sectionLabel(theme, 'Frequently used'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final k in frequent)
                                  _iconTile(theme, k, accent),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                          _sectionLabel(
                            theme,
                            _query.isEmpty ? 'All icons' : 'Results',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final k in all) _iconTile(theme, k, accent),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) => Text(
    text,
    style: theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _iconTile(ThemeData theme, String key, Color accent) {
    final isSelected = key == widget.selected;
    return GestureDetector(
      onTap: () => _pick(key),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.15)
              : theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? accent : theme.colorScheme.outline,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: IconWell.forKey(
          key,
          color: isSelected ? accent : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _addEmojiTile(ThemeData theme) {
    return Tooltip(
      message: 'Type an emoji',
      child: GestureDetector(
        key: const Key('iconPickerAddEmoji'),
        onTap: _typeEmoji,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: AppIcon(
            Icons.add_reaction_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
