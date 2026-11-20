import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../app_icons.dart';
import 'app_surfaces.dart';
import 'custom_icon_badge.dart';
import 'nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';

/// Opens the Exo icons picker — Exo's own library in sections, an iOS-style
/// set and brand logos, all searchable — and resolves to the chosen key, or `null` if the
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
          Tr(
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
            child: const Tr('Done'),
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

  /// The library being browsed — the one the current icon is from.
  late IconLibrary _library = widget.selected == null
      ? IconLibrary.exo
      : AppIcons.libraryOf(widget.selected!);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A search matches an icon's name or its Exo section's ("food" brings up
  /// every food icon), across every library at once.
  List<String> _filter(List<String> keys) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return keys;
    return keys.where((k) {
      if (AppIcons.labelOf(k).toLowerCase().contains(q)) return true;
      final section = AppIcons.sectionOf(k);
      return section != null &&
          exoSectionLabel(section).toLowerCase().contains(q);
    }).toList();
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
    final searching = _query.trim().isNotEmpty;
    // Frequent keys can outlive an icon that's since been removed from
    // AppIcons — drop anything that no longer resolves rather than showing a
    // fallback circle for a key that isn't pickable any more.
    final frequent = _filter(
      ref.watch(frequentIconKeysProvider).where(AppIcons.isKnown).toList(),
    );
    final results = searching ? _filter(AppIcons.allKeys) : const <String>[];
    final showEmoji = widget.allowEmoji && !searching;
    final emoji = showEmoji ? _knownEmojiKeys() : const <String>[];

    final slivers = <Widget>[
      if (showEmoji) ...[
        _label(theme, tr('Emoji')),
        _grid([null, ...emoji], accent, theme),
      ],
      if (frequent.isNotEmpty) ...[
        _label(theme, tr('Frequently used')),
        _grid(frequent, accent, theme),
      ],
      if (searching) ...[
        _label(theme, tr('Results')),
        if (results.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                tr('No icon matches "{0}".', [_query]),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          _grid(results, accent, theme),
      ] else
        ...switch (_library) {
          IconLibrary.exo => [
            for (final (section, keys) in AppIcons.exoSections) ...[
              _label(theme, exoSectionLabel(section)),
              _grid(keys, accent, theme),
            ],
          ],
          IconLibrary.ios => [
            _label(theme, tr('iOS style')),
            _grid(AppIcons.keysOf(IconLibrary.ios), accent, theme),
          ],
          IconLibrary.brands => [
            _label(theme, tr('Apps, services & cards')),
            _grid(AppIcons.keysOf(IconLibrary.brands), accent, theme),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  tr(
                    'Logos belong to their owners. Brand icons by Font '
                    'Awesome (CC BY 4.0).',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        },
    ];

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
              child: Tr('Exo icons', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('iconPickerSearch'),
                controller: _controller,
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const AppIcon(Icons.search),
                  hintText: tr('Search icons'),
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
            // Search looks through every library, so the switch steps
            // aside while it's in use.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: searching
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<IconLibrary>(
                          segments: const [
                            ButtonSegment(
                              value: IconLibrary.exo,
                              label: Tr('Exo'),
                            ),
                            ButtonSegment(
                              value: IconLibrary.ios,
                              label: Tr('iOS'),
                            ),
                            ButtonSegment(
                              value: IconLibrary.brands,
                              label: Tr('Brands'),
                            ),
                          ],
                          selected: {_library},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) =>
                              setState(() => _library = s.first),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      12,
                    ).plusNavBar(context),
                    sliver: SliverMainAxisGroup(slivers: slivers),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  /// Built lazily — the libraries run to hundreds of icons. A null key is
  /// the "type an emoji" tile.
  Widget _grid(List<String?> keys, Color accent, ThemeData theme) =>
      SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 64,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: keys.length,
        itemBuilder: (context, i) {
          final key = keys[i];
          return Center(
            child: key == null
                ? _addEmojiTile(theme)
                : _iconTile(theme, key, accent),
          );
        },
      );

  Widget _iconTile(ThemeData theme, String key, Color accent) {
    final isSelected = key == widget.selected;
    return Semantics(
      button: true,
      selected: isSelected,
      label: AppIcons.labelOf(key),
      child: GestureDetector(
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
      ),
    );
  }

  Widget _addEmojiTile(ThemeData theme) {
    return Tooltip(
      message: tr('Type an emoji'),
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

/// An Exo section's name, as the picker heads it.
String exoSectionLabel(ExoIconSection s) => switch (s) {
  ExoIconSection.money => tr('Money & accounts'),
  ExoIconSection.income => tr('Income'),
  ExoIconSection.food => tr('Food & drink'),
  ExoIconSection.shopping => tr('Shopping'),
  ExoIconSection.transport => tr('Transport'),
  ExoIconSection.home => tr('Home & bills'),
  ExoIconSection.health => tr('Health & care'),
  ExoIconSection.leisure => tr('Fun & sport'),
  ExoIconSection.work => tr('Work & tech'),
  ExoIconSection.travel => tr('Travel'),
  ExoIconSection.people => tr('People & faith'),
  ExoIconSection.finance => tr('Finance'),
  ExoIconSection.nature => tr('Nature'),
  ExoIconSection.symbols => tr('Symbols'),
};
