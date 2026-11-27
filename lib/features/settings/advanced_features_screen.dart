import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/platform/platform_features.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/beta_badge.dart';
import '../../data/providers.dart';

/// Settings → Advanced Features: what still runs as a BETA — it works, but
/// may change, so it lives here instead of in the everyday settings.
class AdvancedFeaturesScreen extends ConsumerWidget {
  const AdvancedFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Advanced Features')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Tr(
            'Early features. They work, but may change before they move '
            'into the rest of Settings — tell us on GitHub what breaks.',
            style: muted?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                if (PlatformFeatures.smsCapture)
                  AppListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: const AppIcon(Icons.sms_outlined),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            tr('Auto money tracking'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const BetaBadge(),
                      ],
                    ),
                    subtitle: Text(_smsSubtitle(ref), style: muted),
                    trailing: AppIcon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    onTap: () => context.push('/more/settings/advanced/sms'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _smsSubtitle(WidgetRef ref) {
    final declared = ref.watch(smsDeclaredProvider).valueOrNull;
    if (declared == false) return tr('Not in this version of XPENC');
    final on =
        ref.watch(settingsProvider).valueOrNull?.messageCaptureEnabled ?? false;
    if (!on) return tr('Reads bank SMS from the senders you pick · Off');
    final banks = {
      for (final r in ref.watch(senderRulesProvider).valueOrNull ?? const [])
        if (r.enabled) r.bankName,
    }.length;
    return plural(banks, 'On · 1 bank', 'On · {0} banks');
  }
}
