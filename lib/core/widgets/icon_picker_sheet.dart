import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../app_icons.dart';

/// Opens the icon picker and resolves to the chosen key, or `null` if the
/// sheet was dismissed without a pick. [accentColor] tints the selected tile
/// and the "Frequently used" row — pass whatever colour the caller's own
/// entity (category, account, ...) is using, so the preview matches what
/// saving will actually look like.
Future<String?> showIconPickerSheet(
  BuildContext context, {
  required String? selected,
  Color? accentColor,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        _IconPickerSheet(selected: selected, accentColor: accentColor),
  );
}

class _IconPickerSheet extends ConsumerStatefulWidget {
  const _IconPickerSheet({required this.selected, required this.accentColor});

  final String? selected;
  final Color? accentColor;

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
                  prefixIcon: const Icon(Icons.search),
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
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
        child: Icon(
          AppIcons.resolve(key),
          color: isSelected ? accent : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
