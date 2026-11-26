import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'bottom_nav_settings_screen.dart' show BottomSpacingCard;
import 'more_screen_layout_sheet.dart';
import 'settings_common.dart';
import 'theme_picker_sheet.dart';
import '../../core/l10n/l10n.dart';

/// Appearance — theme, font, colours, how amounts and weeks read, and the
/// More page's layout: how XPENC looks, independent of app mode or any one
/// feature. (Language and Currency are Settings' own rows; the Dashboard
/// and the bottom bar are edited in place, by holding them.)
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final trailingStyle = settingsTrailingStyle(context);

    final themeChoice = ref.watch(themeChoiceProvider);
    final currency = ref.watch(currencyProvider);
    final showSymbol = ref.watch(showCurrencySymbolProvider);
    final moreScreenViewMode = ref.watch(moreScreenViewModeProvider);
    final weekStart = ref.watch(weekStartProvider);

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Appearance')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          AppCard(
            child: Column(
              children: [
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: AppIcon(themeChoice.style.icon),
                  title: const Tr('Theme'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(themeChoice.style.label, style: trailingStyle),
                      const SizedBox(width: 4),
                      AppIcon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: () => ThemePickerSheet.show(context),
                ),
                Divider(height: 1, indent: 60),
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.text_fields_rounded),
                  title: const Tr('Font'),
                  subtitle: Tr(
                    'Text size, boldness and font family',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: AppIcon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => context.push('/more/settings/font'),
                ),
                Divider(height: 1, indent: 60),
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.palette_outlined),
                  title: const Tr('Colours'),
                  subtitle: Tr(
                    'Money in, money out, people, and transaction icons',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: AppIcon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => context.push('/more/settings/colours'),
                ),
                Divider(height: 1, indent: 60),
                AppSwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const AppIcon(Icons.attach_money_rounded),
                  title: const Tr('Show currency symbol'),
                  subtitle: Text(
                    showSymbol
                        ? tr('Amounts show {0}', [currency.symbol])
                        : tr('Amounts show plain numbers — use this if your '
                              'currency symbol is missing'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: showSymbol,
                  onChanged: (v) =>
                      ref.read(dbProvider).setShowCurrencySymbol(v),
                ),
                Divider(height: 1, indent: 60),
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.dashboard_outlined),
                  title: const Tr('More screen layout'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        MoreScreenLayoutSheet.label(moreScreenViewMode),
                        style: trailingStyle,
                      ),
                      const SizedBox(width: 4),
                      AppIcon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: () => MoreScreenLayoutSheet.show(context),
                ),
              ],
            ),
          ),

          settingsSectionLabel(context, tr('Calendar')),
          AppCard(
            child: Column(
              children: [
                // GitHub #166: the Calendar tab and every date picker.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AppIcon(Icons.view_week_outlined),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Tr(
                              'Week starts on',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<WeekStart>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: WeekStart.sunday,
                              label: Tr('Sunday'),
                            ),
                            ButtonSegment(
                              value: WeekStart.monday,
                              label: Tr('Monday'),
                            ),
                          ],
                          selected: {weekStart},
                          onSelectionChanged: (s) =>
                              ref.read(dbProvider).setWeekStart(s.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          settingsSectionLabel(context, tr('Bottom spacing')),
          const BottomSpacingCard(),
        ],
      ),
    );
  }
}
