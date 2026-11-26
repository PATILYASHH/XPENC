import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/money_text.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'settings_common.dart';
import '../../core/l10n/l10n.dart';

/// Settings → General → Colours (GitHub #156): the colour of each money
/// direction, and what colours a transaction's icon. Each direction still
/// gets exactly one colour, used everywhere — only the hue is the person's.
class ColorsSettingsScreen extends ConsumerWidget {
  const ColorsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final choice = ref.watch(moneyColorChoiceProvider);
    final db = ref.read(dbProvider);

    Future<void> setDirection(_Direction d, int? argb) => db.setMoneyColors(
      income: d == _Direction.income ? argb : choice.income,
      expense: d == _Direction.expense ? argb : choice.expense,
      transfer: d == _Direction.transfer ? argb : choice.transfer,
      person: d == _Direction.person ? argb : choice.person,
    );

    final clash = AppColors.income == AppColors.expense;
    final anyCustom =
        choice.income != null ||
        choice.expense != null ||
        choice.transfer != null ||
        choice.person != null ||
        choice.iconMode != TxIconBackground.category ||
        choice.iconColor != null;

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Colours')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          settingsSectionLabel(context, tr('Money colours')),
          AppCard(
            child: Column(
              children: [
                for (final d in _Direction.values) ...[
                  if (d.index > 0)
                    Divider(height: 1, indent: 60),
                  _DirectionTile(
                    direction: d,
                    isCustom: d.stored(choice) != null,
                    onPick: (argb) => setDirection(d, argb),
                  ),
                ],
              ],
            ),
          ),
          if (clash)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Tr(
                'Money in and Money out are the same colour, so they’ll be '
                'hard to tell apart at a glance.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? Colors.amber
                      : Colors.orange.shade800,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Tr(
              'Each colour is used everywhere that kind of money shows — '
              'amounts, charts and icons.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),

          settingsSectionLabel(context, tr('Transaction icon')),
          AppCard(
            child: Column(
              children: [
                for (final mode in TxIconBackground.values) ...[
                  if (mode.index > 0)
                    Divider(height: 1, indent: 60),
                  _IconModeTile(
                    mode: mode,
                    selected: choice.iconMode == mode,
                    onTap: () =>
                        db.setTxIconStyle(mode, color: choice.iconColor),
                  ),
                ],
                if (choice.iconMode == TxIconBackground.single) ...[
                  Divider(height: 1, indent: 60),
                  AppListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: _Swatch(TxIconStyle.single),
                    title: const Tr('Icon colour'),
                    trailing: AppIcon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    onTap: () async {
                      final picked = await showColorPickerSheet(
                        context,
                        title: tr('Icon colour'),
                        current: TxIconStyle.single,
                        defaultColor: TxIconStyle.defaultSingle,
                      );
                      if (picked == null) return;
                      await db.setTxIconStyle(
                        TxIconBackground.single,
                        color: picked.argb,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _IconPreview(),

          if (anyCustom)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: TextButton.icon(
                  icon: const AppIcon(Icons.restart_alt_rounded),
                  label: const Tr('Reset all colours'),
                  onPressed: () async {
                    await db.setMoneyColors(
                      income: null,
                      expense: null,
                      transfer: null,
                      person: null,
                    );
                    await db.setTxIconStyle(TxIconBackground.category);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _Direction { income, expense, transfer, person }

extension on _Direction {
  String get label => switch (this) {
    _Direction.income => tr('Money in'),
    _Direction.expense => tr('Money out'),
    _Direction.transfer => tr('Transfer'),
    _Direction.person => tr('People'),
  };

  String get example => switch (this) {
    _Direction.income => tr('Salary, refunds — anything coming in'),
    _Direction.expense => tr('Spending — anything going out'),
    _Direction.transfer => tr('Between your own accounts'),
    _Direction.person => tr('Money lent, borrowed or settled'),
  };

  Color get current => switch (this) {
    _Direction.income => AppColors.income,
    _Direction.expense => AppColors.expense,
    _Direction.transfer => AppColors.transfer,
    _Direction.person => AppColors.person,
  };

  Color get fallback => switch (this) {
    _Direction.income => AppColors.defaultIncome,
    _Direction.expense => AppColors.defaultExpense,
    _Direction.transfer => AppColors.defaultTransfer,
    _Direction.person => AppColors.defaultPerson,
  };

  int? stored(MoneyColorChoice c) => switch (this) {
    _Direction.income => c.income,
    _Direction.expense => c.expense,
    _Direction.transfer => c.transfer,
    _Direction.person => c.person,
  };
}

class _DirectionTile extends StatelessWidget {
  const _DirectionTile({
    required this.direction,
    required this.isCustom,
    required this.onPick,
  });

  final _Direction direction;
  final bool isCustom;
  final ValueChanged<int?> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: _Swatch(direction.current),
      title: Text(direction.label),
      subtitle: Text(
        direction.example,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isCustom) Tr('Default', style: settingsTrailingStyle(context)),
          const SizedBox(width: 4),
          AppIcon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () async {
        final picked = await showColorPickerSheet(
          context,
          title: direction.label,
          current: direction.current,
          defaultColor: direction.fallback,
        );
        if (picked == null) return;
        onPick(picked.argb);
      },
    );
  }
}

class _IconModeTile extends StatelessWidget {
  const _IconModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TxIconBackground mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, subtitle) = switch (mode) {
      TxIconBackground.category => (
        tr('Category colour'),
        tr('Each icon wears its category’s colour'),
      ),
      TxIconBackground.direction => (
        tr('Money in / out colour'),
        tr('Icons match the money colours above'),
      ),
      TxIconBackground.single => (tr('One colour'), tr('Every icon the same colour')),
    };
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: AppIcon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected
            ? theme.colorScheme.secondary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}

/// How a spend, an income and a transfer row's icon will look.
class _IconPreview extends StatelessWidget {
  const _IconPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A stand-in category colour, so "Category colour" shows its own hue.
    const sampleCategory = Color(0xFFF97316);
    Widget sample(TxType type, IconData icon, String label) {
      final color = txIconColor(
        type,
        type == TxType.transfer ? AppColors.transfer : sampleCategory,
      );
      return Column(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: AppIcon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        sample(TxType.expense, Icons.restaurant_outlined, tr('Money out')),
        sample(TxType.income, Icons.work_outline_rounded, tr('Money in')),
        sample(TxType.transfer, Icons.swap_horiz_rounded, tr('Transfer')),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

/// A picked colour, or [argb] null for "back to the default".
typedef PickedColor = ({int? argb});

/// Colours offered as one tap. Anything else goes in the hex field.
const _swatches = <int>[
  0xFF16A34A, // green
  0xFF059669, // emerald
  0xFF0D9488, // teal
  0xFF0891B2, // cyan
  0xFF0EA5E9, // sky
  0xFF2563EB, // blue
  0xFF4F46E5, // indigo
  0xFF7C3AED, // violet
  0xFFA855F7, // purple
  0xFFC026D3, // fuchsia
  0xFFDB2777, // pink
  0xFFE11D48, // rose
  0xFFDC2626, // red
  0xFFEA580C, // orange
  0xFFD97706, // amber
  0xFFCA8A04, // yellow
  0xFF65A30D, // lime
  0xFF92400E, // brown
  0xFF475569, // slate
  0xFF78716C, // stone
];

/// Swatches plus a hex field, and "Use default". Resolves null when the sheet
/// is dismissed without a choice.
Future<PickedColor?> showColorPickerSheet(
  BuildContext context, {
  required String title,
  required Color current,
  required Color defaultColor,
}) {
  return showAppSheet<PickedColor>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ColorPickerSheet(
      title: title,
      current: current,
      defaultColor: defaultColor,
    ),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({
    required this.title,
    required this.current,
    required this.defaultColor,
  });

  final String title;
  final Color current;
  final Color defaultColor;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late final _hexController = TextEditingController(
    text: _hexOf(widget.current),
  );

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  static String _hexOf(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _pick(int argb) => Navigator.of(context).pop<PickedColor>((argb: argb));

  void _submitHex() {
    final raw = _hexController.text.trim().replaceFirst('#', '');
    final value = raw.length == 6 ? int.tryParse(raw, radix: 16) : null;
    if (value == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Tr('Enter six hex digits, like 16A34A.')),
        );
      return;
    }
    _pick(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentArgb = widget.current.toARGB32();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom:
            MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final argb in _swatches)
                  GestureDetector(
                    onTap: () => _pick(argb),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(argb),
                        shape: BoxShape.circle,
                        border: argb == currentArgb
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 2.5,
                              )
                            : null,
                      ),
                      child: argb == currentArgb
                          ? const AppIcon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 7,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                    ],
                    decoration: InputDecoration(
                      labelText: tr('Any colour (hex)'),
                      prefixText: '#',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _submitHex(),
                  ),
                ),
                const SizedBox(width: 12),
                // The theme stretches filled buttons full-width; in a Row
                // that's unbounded.
                SizedBox(
                  width: 88,
                  child: FilledButton(
                    onPressed: _submitHex,
                    child: const Tr('Use'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: widget.defaultColor,
                  shape: BoxShape.circle,
                ),
              ),
              label: const Tr('Use default'),
              onPressed: () =>
                  Navigator.of(context).pop<PickedColor>((argb: null)),
            ),
          ],
        ),
      ),
    );
  }
}
