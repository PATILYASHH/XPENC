import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/voice/voice_parser.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/money.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../../core/l10n/l10n.dart';
import '../quick_entry/entry_sources.dart';
import 'voice_add_controller.dart';

/// What the bottom bar turns into while voice add is open: ✕ to stop, a
/// mic that pulses with your voice, the words as they're heard and — once
/// there's something to go on — what they'll fill in ("₹250 · Transport").
/// The ➕ beside it has become the send button ([VoiceSendButton]).
class VoiceAddBar extends ConsumerWidget {
  const VoiceAddBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceAddProvider);
    if (state == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final controller = ref.read(voiceAddProvider.notifier);
    final listening = state.phase == VoicePhase.listening;
    final error = state.phase == VoicePhase.error ? state.error : null;

    final Widget middle;
    if (error != null) {
      middle = _Problem(code: error);
    } else if (state.text.trim().isEmpty) {
      middle = Text(
        listening
            ? tr('Listening… e.g. "Taxi 250 rupees"')
            : tr('Tap the mic to try again'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      );
    } else {
      middle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          _Preview(text: state.text),
        ],
      );
    }

    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          IconButton(
            icon: const AppIcon(Icons.close_rounded),
            tooltip: tr('Cancel'),
            onPressed: controller.close,
          ),
          GestureDetector(
            onTap: listening ? null : () => controller.listen(),
            child: Tooltip(
              message: listening ? tr('Listening') : tr('Listen again'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listening
                      ? cs.secondary.withValues(
                          alpha: 0.18 + 0.5 * state.level,
                        )
                      : cs.surfaceContainerHighest,
                ),
                child: AppIcon(
                  listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  size: 20,
                  color: listening ? cs.secondary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: middle),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// "₹250 · Transport · Money out" — what Continue will fill in.
class _Preview extends ConsumerWidget {
  const _Preview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Same reading as Continue's, keywords and account names included.
    final draft = parseVoiceEntry(
      text,
      categories: ref.watch(entryCategoriesProvider),
      keywords: ref.watch(entryKeywordsProvider),
      accounts: ref.watch(entryAccountsProvider),
      now: DateTime.now(),
    );
    final category = ref.watch(categoryMapProvider)[draft.categoryId];
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final amount = draft.amount;
    final line = [
      if (amount != null) MoneyFormat.symbol(amount),
      ?category?.name,
      draft.type == TxType.income ? tr('Money in') : tr('Money out'),
    ].join(' · ');
    return Text(
      line,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// A problem that stopped listening, and the way out of it.
class _Problem extends ConsumerWidget {
  const _Problem({required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(voiceAddProvider.notifier);
    final message = switch (code) {
      'unsupported' => tr(
        'Voice add needs Android 12 or newer with offline speech '
        'recognition.',
      ),
      'language' => tr("Offline speech for Indian English isn't downloaded."),
      'permission' => tr('Allow the microphone to use voice add.'),
      'no-match' => tr("Didn't catch that — tap the mic to try again."),
      _ => tr("Couldn't listen — tap the mic to try again."),
    };
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (code != 'language') {
      return Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final asked = await controller.downloadLanguage();
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    asked
                        ? tr('Downloading — try voice add again in a minute.')
                        : tr(
                            'Download "English (India)" for offline speech '
                            "in your phone's Settings → Languages.",
                          ),
                  ),
                ),
              );
          },
          child: const Tr('Download'),
        ),
      ],
    );
  }
}
