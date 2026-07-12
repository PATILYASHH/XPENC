import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// Phase 5 control panel: the trust story, capture toggle + manual scan, the
/// review inbox, auto-approve, and the merchant/bank rules the app has learned.
///
/// Everything here reads and writes settings on-device only. The privacy card
/// stays first, deliberately — it is the promise the rest of the screen keeps.
class MessageCaptureScreen extends ConsumerStatefulWidget {
  const MessageCaptureScreen({super.key});

  @override
  ConsumerState<MessageCaptureScreen> createState() =>
      _MessageCaptureScreenState();
}

class _MessageCaptureScreenState extends ConsumerState<MessageCaptureScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Message Capture')),
      // Never crash the page while settings load — show a spinner instead.
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorBody(context, e),
        data: (settings) => _content(context, settings),
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────

  Widget _content(BuildContext context, SettingRow settings) {
    final pendingCount = ref.watch(pendingCountProvider);
    final merchantRulesAsync = ref.watch(merchantRulesProvider);
    final senderRulesAsync = ref.watch(senderRulesProvider);
    final categoryMap = ref.watch(categoryMapProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        // 1 ── Privacy ────────────────────────────────────────────────────
        _caption(context, 'Privacy'),
        _privacyCard(context),

        // 2 ── Capture ────────────────────────────────────────────────────
        _caption(context, 'Capture'),
        _captureCard(context, settings, pendingCount),

        // 3 ── Auto-approve ───────────────────────────────────────────────
        _caption(context, 'Auto-Approve'),
        _autoApproveCard(context, settings),

        // 4 ── Learned merchants ──────────────────────────────────────────
        _caption(context, 'Learned Merchants'),
        _merchantsCard(context, merchantRulesAsync, categoryMap),

        // 5 ── Banks ──────────────────────────────────────────────────────
        _caption(context, 'Banks'),
        _banksCard(context, senderRulesAsync),
        _footnote(
          context,
          "Messages from senders that aren't enabled banks are ignored.",
        ),

        // 6 ── Notifications ──────────────────────────────────────────────
        _caption(context, 'Notifications'),
        _notificationsCard(context, settings),
      ],
    );
  }

  // ── 1. Privacy ────────────────────────────────────────────────────────────

  Widget _privacyCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Bank messages are read and parsed entirely on this device. '
                'Nothing is uploaded, ever.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Capture ──────────────────────────────────────────────────────────

  Widget _captureCard(
    BuildContext context,
    SettingRow settings,
    int pendingCount,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final on = settings.messageCaptureEnabled;

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: const Icon(Icons.sms_outlined),
            title: const Text('Read bank SMS'),
            subtitle: Text(
              "Detects transactions from your bank's SMS and queues them for "
              'review.',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            value: on,
            onChanged: _toggleCapture,
          ),
          Divider(height: 1, indent: 60, color: cs.outline),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.refresh),
            title: const Text('Scan now'),
            enabled: on,
            onTap: on
                ? () {
                    final messenger = ScaffoldMessenger.of(context);
                    _scanNow(messenger);
                  }
                : null,
          ),
          Divider(height: 1, indent: 60, color: cs.outline),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('Review Inbox'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pendingCount > 0) _CountBadge(count: pendingCount),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: () => context.push('/inbox'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCapture(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(dbProvider);

    // Turning off is unconditional.
    if (!value) {
      await db.setMessageCaptureEnabled(false);
      return;
    }

    final src = ref.read(messageSourceProvider);

    final supported = await src.isSupported();
    if (!mounted) return;
    if (!supported) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Not supported on this device')),
        );
      return;
    }

    var granted = await src.hasPermission();
    if (!granted) granted = await src.requestPermission();
    if (!mounted) return;
    if (!granted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Permission denied — capture stays off')),
        );
      return;
    }

    await db.setMessageCaptureEnabled(true);
    if (!mounted) return;

    // Turning it on should immediately show the user what's there.
    await _scanNow(messenger);
  }

  Future<void> _scanNow(ScaffoldMessengerState messenger) async {
    final service = ref.read(captureServiceProvider);
    final result = await service.scan();
    if (!mounted) return;

    final text = !result.didRun
        ? (result.reason ?? "Capture didn't run")
        : 'Scanned ${result.scanned} · ${result.ingested} new · '
            '${result.autoFilled} auto-filled · ${result.skippedSender} ignored';

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ── 3. Auto-approve ─────────────────────────────────────────────────────

  Widget _autoApproveCard(BuildContext context, SettingRow settings) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: const Icon(Icons.auto_mode_outlined),
            title: const Text('Auto-Approve'),
            subtitle: Text(
              "When a payment matches a merchant you've categorised before, "
              'fill it in and add it automatically. The card still appears so '
              'you can see what was filled — and undo it.',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            value: settings.autoApprove,
            onChanged: (v) => ref.read(dbProvider).setAutoApprove(v),
          ),
          Divider(height: 1, indent: 60, color: cs.outline),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Auto-Approve never guesses. It only fires from a merchant '
                    'rule you taught it, on a high-confidence message, for a '
                    'known account.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Learned merchants ────────────────────────────────────────────────

  Widget _merchantsCard(
    BuildContext context,
    AsyncValue<List<MerchantRuleRow>> rulesAsync,
    Map<int, CategoryRow> categoryMap,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: rulesAsync.when(
        loading: () => const _CardLoading(),
        error: (_, _) => const _CardError('Could not load learned merchants.'),
        data: (rules) {
          if (rules.isEmpty) {
            return const _CardEmpty(
              "None yet. Categorise a detected transaction and tick "
              "'Remember'.",
            );
          }
          return Column(
            children: [
              for (var i = 0; i < rules.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 16, color: cs.outline),
                _merchantTile(context, rules[i], categoryMap),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _merchantTile(
    BuildContext context,
    MerchantRuleRow rule,
    Map<int, CategoryRow> categoryMap,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final categoryName = categoryMap[rule.categoryId]?.name ?? 'Uncategorised';

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      title: Text(rule.matchPattern),
      subtitle: Text(
        '→ $categoryName · used ${rule.hitCount}×',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Forget merchant',
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await ref.read(dbProvider).deleteMerchantRule(rule.id);
          if (!mounted) return;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Forgot ${rule.matchPattern}')),
            );
        },
      ),
    );
  }

  // ── 5. Banks ────────────────────────────────────────────────────────────

  Widget _banksCard(
    BuildContext context,
    AsyncValue<List<SenderRuleRow>> rulesAsync,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: rulesAsync.when(
        loading: () => const _CardLoading(),
        error: (_, _) => const _CardError('Could not load banks.'),
        data: (rules) {
          if (rules.isEmpty) {
            return const _CardEmpty('No banks configured yet.');
          }
          return Column(
            children: [
              for (var i = 0; i < rules.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 16, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(rules[i].bankName),
                  subtitle: Text(
                    rules[i].senderPattern,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                      letterSpacing: 0.2,
                    ),
                  ),
                  value: rules[i].enabled,
                  onChanged: (v) =>
                      ref.read(dbProvider).setSenderRuleEnabled(rules[i].id, v),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── 6. Notifications ────────────────────────────────────────────────────

  Widget _notificationsCard(BuildContext context, SettingRow settings) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: const Icon(Icons.notifications_outlined),
        title: const Text('Notifications'),
        subtitle: Text(
          'Budget alerts, payment reminders, and detected transactions.',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        value: settings.notificationsEnabled,
        onChanged: _toggleNotifications,
      ),
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    final db = ref.read(dbProvider);
    final notifications = ref.read(notificationServiceProvider);
    await db.setNotificationsEnabled(value);
    if (value) await notifications.requestPermission();
  }

  // ── Shared chrome ───────────────────────────────────────────────────────

  Widget _caption(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _footnote(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _errorBody(BuildContext context, Object error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load message capture settings.\n$error',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.error),
        ),
      ),
    );
  }
}

/// Small accent pill showing how many cards await review.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: cs.onSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// In-card placeholders so a Card never renders empty or unbounded.
class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

class _CardEmpty extends StatelessWidget {
  const _CardEmpty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _CardError extends StatelessWidget {
  const _CardError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }
}
