import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

/// Bank-SMS auto-capture is paused — this screen says so, honestly.
///
/// The 1.0 builds read bank SMS on-device and turned them into review cards.
/// Google Play Protect blocks direct-download APKs that request SMS
/// permissions, so installing XPENC meant pausing Play Protect first — the
/// wrong trade for a money app. 1.1.0 removed the permission; the whole
/// pipeline (parser, dedupe, Review Inbox) still exists behind the
/// `MessageSource` interface and returns in a Play-compliant form.
class MessageCaptureScreen extends ConsumerWidget {
  const MessageCaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Cards captured by an older build stay reviewable — never strand data.
    final pendingCount = ref.watch(pendingCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Message Capture')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.sms_outlined, color: cs.onSurface),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outline),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'COMING SOON',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Auto-capture will be back',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'XPENC used to read bank SMS on this device and turn them '
                    'into review cards. Google Play Protect blocks apps '
                    'installed outside the Play Store that ask for SMS '
                    'permissions — installing XPENC meant pausing your '
                    "phone's protection first. That is the wrong trade for a "
                    'money app, so this version removes the SMS permission '
                    'entirely and installs cleanly.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Auto-capture returns in a Play-compliant form. Until '
                    'then, adding a transaction by hand takes a few seconds — '
                    'and everything else works exactly as before.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Nothing about the privacy promise changes: your data '
                      'lives on this device and is never uploaded. This build '
                      'simply asks for no SMS permission at all.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (pendingCount > 0) ...[
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.inbox_outlined),
                title: const Text('Review Inbox'),
                subtitle: Text(
                  '$pendingCount earlier detected '
                  '${pendingCount == 1 ? 'transaction' : 'transactions'} '
                  'still waiting for review',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/inbox'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
