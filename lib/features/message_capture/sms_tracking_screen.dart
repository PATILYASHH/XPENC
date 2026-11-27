import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/permissions/app_permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/beta_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/open_link.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../settings/settings_common.dart';
import 'capture_service.dart';
import 'parser/bank_message.dart';
import 'parser/bank_templates.dart';
import 'parser/message_parser.dart';
import 'sms_inbox.dart';

/// Settings → Advanced Features → Auto money tracking (BETA).
///
/// Bank SMS become Review Inbox cards — read on the phone, only from the
/// senders listed here (the bank templates people shared on GitHub, plus
/// any the user adds). The list at the bottom shows exactly which messages
/// that is, and what XPENC made of each, so capture is never a black box.
class SmsTrackingScreen extends ConsumerStatefulWidget {
  const SmsTrackingScreen({super.key});

  /// How far back "Messages" looks.
  static const messagesWindow = Duration(days: 30);

  /// How far back "Found in your messages" looks for other banks.
  static const sendersWindow = Duration(days: 90);

  @override
  ConsumerState<SmsTrackingScreen> createState() => _SmsTrackingScreenState();
}

class _SmsTrackingScreenState extends ConsumerState<SmsTrackingScreen>
    with WidgetsBindingObserver {
  static const _parser = MessageParser();

  PermissionState? _permission;
  bool _loading = false;

  /// Asked to load again while a load ran — its rules may be stale.
  bool _reloadAfter = false;
  bool _scanning = false;

  /// Newest first, from the tracked senders only.
  List<_Read> _messages = const [];

  /// Each message's card, by [AppDatabase.dedupeKeyFor].
  Map<String, PendingStatus> _cards = const {};

  /// Other senders whose messages look like payments.
  List<InboxSender> _found = const [];

  /// The bank name the list is narrowed to.
  String? _bank;
  bool _showSkipped = false;

  SmsInbox get _inbox => ref.read(smsInboxProvider);
  bool get _granted => _permission == PermissionState.granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from system settings, where SMS may just have been allowed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!await _inbox.declared()) return;
    final permission = await _inbox.permission();
    if (!mounted) return;
    setState(() => _permission = permission);
    await _loadMessages();
  }

  /// Reads the tracked senders' messages and who else has written.
  Future<void> _loadMessages() async {
    if (!_granted) return;
    if (_loading) {
      _reloadAfter = true;
      return;
    }
    setState(() => _loading = true);
    try {
      final db = ref.read(dbProvider);
      final rules = await db.watchSenderRules().first;
      final tracked = [
        for (final r in rules)
          if (r.enabled) r.senderPattern,
      ];
      final now = DateTime.now();
      final raw = await _inbox.messages(
        since: now.subtract(SmsTrackingScreen.messagesWindow),
        senders: tracked,
        newestFirst: true,
        limit: 300,
      );
      final reads = [
        for (final m in raw)
          if (tracksSender(m.sender, tracked))
            _Read(m, _parser.parse(m), _bankOf(m.sender, rules)),
      ];
      final cards = await db.captureStatusOf(raw);

      // Every rule, switched on or off, counts as "already listed".
      final listed = [for (final r in rules) r.senderPattern];
      final found = [
        for (final s in await _inbox.senders(
          since: now.subtract(SmsTrackingScreen.sendersWindow),
        ))
          if (!isPromotionalSender(s.sender) &&
              !tracksSender(s.sender, listed) &&
              normalizeSenderPattern(s.sender) != null &&
              s.samples.any(
                (body) =>
                    _parser.parse(
                      RawMessage(
                        body: body,
                        sender: s.sender,
                        receivedAt: s.last,
                      ),
                    )
                    is ParsedMessage,
              ))
            s,
      ];
      if (!mounted) return;
      setState(() {
        _messages = reads;
        _cards = cards;
        _found = found.take(8).toList();
        if (_bank != null && !reads.any((r) => r.bank == _bank)) _bank = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (_reloadAfter && mounted) {
      _reloadAfter = false;
      await _loadMessages();
    }
  }

  static String _bankOf(String sender, List<SenderRuleRow> rules) {
    final s = sender.toUpperCase();
    for (final r in rules) {
      if (r.enabled && s.contains(r.senderPattern.toUpperCase())) {
        return r.bankName;
      }
    }
    return templateForSender(sender)?.bank ?? sender;
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _setTracking(bool on) async {
    final db = ref.read(dbProvider);
    if (!on) {
      await db.setMessageCaptureEnabled(false);
      return;
    }
    if (!_granted && !await _askForSms()) return;

    // Back on after a long pause: read the last 30 days, not every message
    // since it was switched off.
    final last = (await db.getSettings()).lastMessageScanAt;
    final cutoff = DateTime.now().subtract(CaptureService.firstScanWindow);
    if (last == null || last.isBefore(cutoff)) await db.restartMessageScan();
    await db.setMessageCaptureEnabled(true);
    await _scan();
  }

  /// Android's SMS dialog — or, once Android won't show it again, the
  /// app's page in system settings. True when SMS is now allowed.
  Future<bool> _askForSms() async {
    final after = await _inbox.requestPermission();
    if (!mounted) return false;
    setState(() => _permission = after);
    if (after == PermissionState.granted) return true;
    if (after == PermissionState.blocked) {
      final go = await showAppDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Tr('Allow SMS in system settings'),
          content: const Tr(
            "Android won't ask again. Open XPENC's settings page, then "
            'Permissions → SMS → Allow.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Tr('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Tr('Open settings'),
            ),
          ],
        ),
      );
      if (go ?? false) await AppPermissions.openSettings(AppPermission.sms);
    }
    return false;
  }

  Future<void> _scan() async {
    if (_scanning) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.maybeOf(context);
    setState(() => _scanning = true);
    try {
      final result = await ref.read(captureServiceProvider).scan();
      final waiting = result.ingested - result.autoFilled;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              !result.didRun
                  ? tr(result.reason!)
                  : result.ingested == 0
                  ? tr('No new payments in your bank messages')
                  : result.autoFilled == 0
                  ? plural(
                      waiting,
                      '1 new payment in Review Inbox',
                      '{0} new payments in Review Inbox',
                    )
                  : tr('{0} in Review Inbox · {1} added for you', [
                      waiting,
                      result.autoFilled,
                    ]),
            ),
            action: waiting > 0 && router != null
                ? SnackBarAction(
                    label: tr('Review'),
                    onPressed: () => router.push('/inbox'),
                  )
                : null,
          ),
        );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    await _loadMessages();
  }

  /// One message the scan didn't queue (from before tracking began, say).
  Future<void> _addOne(_Read read) async {
    final parsed = read.result;
    if (parsed is! ParsedMessage) return;
    await ref.read(dbProvider).ingestMessage(read.message, parsed);
    await _loadMessages();
  }

  Future<void> _toggleBank(List<SenderRuleRow> rules, bool on) async {
    final db = ref.read(dbProvider);
    for (final r in rules) {
      await db.setSenderRuleEnabled(r.id, on);
    }
    await _loadMessages();
  }

  Future<void> _deleteBank(String bank, List<SenderRuleRow> rules) async {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Stop tracking {0}?', [bank])),
        content: const Tr(
          'Its sender comes off this list. Cards already in Review Inbox '
          'stay there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tr('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tr('Remove'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    final db = ref.read(dbProvider);
    for (final r in rules) {
      await db.deleteSenderRule(r.id);
    }
    await _loadMessages();
  }

  Future<void> _track(String sender) async {
    final code = normalizeSenderPattern(sender);
    if (code == null) return;
    await ref
        .read(dbProvider)
        .addSenderRule(code, templateForSender(sender)?.bank ?? code);
    await _loadMessages();
  }

  Future<void> _addSender() async {
    final added = await showAppDialog<({String code, String bank})>(
      context: context,
      builder: (_) => const _AddSenderDialog(),
    );
    if (added == null) return;
    await ref.read(dbProvider).addSenderRule(added.code, added.bank);
    await _loadMessages();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final declared = ref.watch(smsDeclaredProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final rules = ref.watch(senderRulesProvider).valueOrNull ?? const [];
    ref.listen(senderRulesProvider, (_, _) => unawaited(_loadMessages()));

    return Scaffold(
      appBar: AppTopBar(
        title: const Tr('Auto money tracking'),
        actions: [
          if (declared.valueOrNull == true && _granted)
            IconButton(
              tooltip: tr('Check messages now'),
              onPressed: _scanning ? null : _scan,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppIcon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _Intro(muted: muted),
          if (declared.isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (declared.valueOrNull != true)
            _NotInThisBuild(muted: muted)
          else ...[
            const SizedBox(height: 12),
            _controls(context, settings, muted),
            settingsSectionLabel(context, tr('Your banks')),
            _banks(context, rules, muted),
            if (_granted && _found.isNotEmpty) ...[
              settingsSectionLabel(context, tr('Found in your messages')),
              _foundCard(context, muted),
            ],
            settingsSectionLabel(context, tr('Messages · last 30 days')),
            _messagesCard(context, muted),
          ],
          const SizedBox(height: 16),
          _Footer(muted: muted),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context, SettingRow? settings, TextStyle? muted) {
    final enabled = settings?.messageCaptureEnabled ?? false;
    final on = enabled && _granted;
    final pending = ref.watch(pendingCountProvider);
    return AppCard(
      child: Column(
        children: [
          AppSwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: const AppIcon(Icons.sms_outlined),
            title: const Tr('Track bank SMS'),
            subtitle: Text(
              on
                  ? tr('New messages from your banks are read each time you '
                        'open XPENC')
                  : enabled
                  ? tr('SMS permission is off — switch on to allow it again')
                  : tr('Asks to read SMS the first time'),
              style: muted,
            ),
            value: on,
            onChanged: _setTracking,
          ),
          Divider(height: 1, indent: 60),
          AppSwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: const AppIcon(Icons.bolt_outlined),
            title: const Tr('Auto-add payees you taught XPENC'),
            subtitle: Tr(
              'Only a payee you ticked "Remember" for, read with confidence '
              'into a known account. Everything else waits for you.',
              style: muted,
            ),
            value: settings?.autoApprove ?? false,
            onChanged: on
                ? (v) => ref.read(dbProvider).setAutoApprove(v)
                : null,
          ),
          Divider(height: 1, indent: 60),
          AppListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const AppIcon(Icons.inbox_outlined),
            title: const Tr('Review Inbox'),
            subtitle: Text(
              pending == 0
                  ? tr('Nothing waiting')
                  : plural(pending, '1 waiting for you', '{0} waiting for you'),
              style: muted,
            ),
            trailing: const AppIcon(Icons.chevron_right_rounded),
            onTap: () => context.push('/inbox'),
          ),
        ],
      ),
    );
  }

  Widget _banks(
    BuildContext context,
    List<SenderRuleRow> rules,
    TextStyle? muted,
  ) {
    // One row per bank: SBI writes as SBIINB and SBIUPI.
    final byBank = <String, List<SenderRuleRow>>{};
    for (final r in rules) {
      (byBank[r.bankName] ??= []).add(r);
    }
    final counts = <String, int>{};
    for (final m in _messages) {
      counts[m.bank] = (counts[m.bank] ?? 0) + 1;
    }
    final banks = byBank.keys.toList()
      ..sort((a, b) {
        final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        return byCount != 0 ? byCount : a.compareTo(b);
      });

    return AppCard(
      child: Column(
        children: [
          for (final (i, bank) in banks.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 60),
            _BankTile(
              bank: bank,
              rules: byBank[bank]!,
              messages: _granted ? counts[bank] ?? 0 : null,
              muted: muted,
              onChanged: (on) => _toggleBank(byBank[bank]!, on),
              onLongPress: () => _deleteBank(bank, byBank[bank]!),
            ),
          ],
          if (banks.isNotEmpty) Divider(height: 1, indent: 60),
          AppListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const AppIcon(Icons.add_rounded),
            title: const Tr('Add a sender'),
            subtitle: Tr(
              'Your bank isn\'t listed? Add its sender ID. Hold a bank to '
              'remove it.',
              style: muted,
            ),
            onTap: _addSender,
          ),
        ],
      ),
    );
  }

  Widget _foundCard(BuildContext context, TextStyle? muted) {
    return AppCard(
      child: Column(
        children: [
          for (final (i, s) in _found.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 60),
            AppListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const AppIcon(Icons.account_balance_outlined),
              title: Text(templateForSender(s.sender)?.bank ?? s.sender),
              subtitle: Text(
                [
                  // The title already is the ID when the bank's unknown.
                  if (templateForSender(s.sender) != null) s.sender,
                  plural(s.count, '1 message', '{0} messages'),
                  tr('looks like payments'),
                ].join(' · '),
                style: muted,
              ),
              trailing: TextButton(
                onPressed: () => _track(s.sender),
                child: const Tr('Track'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _messagesCard(BuildContext context, TextStyle? muted) {
    if (!_granted) {
      return _Empty(
        text: tr('Allow SMS (switch on Track bank SMS) to see your bank '
            'messages here.'),
        muted: muted,
      );
    }
    if (_loading && _messages.isEmpty) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_messages.isEmpty) {
      return _Empty(
        text: tr('No messages from these banks in the last 30 days.'),
        muted: muted,
      );
    }

    final banks = <String>{for (final m in _messages) m.bank}.toList()..sort();
    final inBank = [
      for (final m in _messages)
        if (_bank == null || m.bank == _bank) m,
    ];
    final payments = [
      for (final m in inBank)
        if (m.result is ParsedMessage) m,
    ];
    final skipped = inBank.length - payments.length;
    final shown = _showSkipped ? inBank : payments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banks.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Tr('All'),
                  selected: _bank == null,
                  onSelected: (_) => setState(() => _bank = null),
                ),
                for (final b in banks) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(b),
                    selected: _bank == b,
                    onSelected: (_) => setState(() => _bank = b),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        AppCard(
          child: Column(
            children: [
              for (final (i, m) in shown.indexed) ...[
                if (i > 0) Divider(height: 1, indent: 60),
                _MessageTile(
                  read: m,
                  card: _cards[AppDatabase.dedupeKeyFor(m.message)],
                  muted: muted,
                  onAdd: () => _addOne(m),
                ),
              ],
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Tr('No payments here yet.', style: muted),
                ),
              if (skipped > 0) ...[
                Divider(height: 1),
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  dense: true,
                  title: Text(
                    _showSkipped
                        ? tr('Hide skipped messages')
                        : plural(
                            skipped,
                            '1 skipped — an OTP, offer or balance alert',
                            '{0} skipped — OTPs, offers, balance alerts',
                          ),
                    style: muted,
                  ),
                  trailing: AppIcon(
                    _showSkipped
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                  ),
                  onTap: () => setState(() => _showSkipped = !_showSkipped),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A message, what the parser made of it, and the bank it's from.
class _Read {
  const _Read(this.message, this.result, this.bank);

  final RawMessage message;
  final ParseResult result;
  final String bank;
}

class _Intro extends StatelessWidget {
  const _Intro({required this.muted});

  final TextStyle? muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Tr(
                    'Auto money tracking',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const BetaBadge(),
              ],
            ),
            const SizedBox(height: 8),
            Tr(
              'XPENC reads SMS from the banks below — no one else — on this '
              'phone, and turns each payment into a card in Review Inbox. '
              'Nothing is added until you approve it.',
              style: muted?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// A build without READ_SMS: say why, honestly, and what works instead.
class _NotInThisBuild extends StatelessWidget {
  const _NotInThisBuild({required this.muted});

  final TextStyle? muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tr(
                'Not in this version',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Tr(
                'This copy of XPENC was built without the SMS permission. '
                'Google Play Protect blocks apps installed from a browser '
                'that ask for it, so it only comes in builds made for '
                'testing it.',
                style: muted?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 8),
              Tr(
                'Meanwhile, share a bank message to XPENC from your '
                'messages app — it is read the same way.',
                style: muted?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.muted});

  final TextStyle? muted;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const AppIcon(Icons.forum_outlined),
            title: const Tr('Bank missing or read wrong?'),
            subtitle: Tr(
              'Share a redacted sample on GitHub. The banks here came from '
              'people who did.',
              style: muted,
            ),
            trailing: const AppIcon(Icons.open_in_new_rounded, size: 18),
            onTap: () => openLink(context, kBankSupportIssueUrl),
          ),
          Divider(height: 1, indent: 60),
          AppListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const AppIcon(Icons.lock_outline_rounded),
            title: const Tr('Stays on this phone'),
            subtitle: Tr(
              'XPENC cannot connect to the internet, so no message is ever '
              'uploaded. Texts from people (phone numbers) are never read.',
              style: muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankTile extends StatelessWidget {
  const _BankTile({
    required this.bank,
    required this.rules,
    required this.messages,
    required this.muted,
    required this.onChanged,
    required this.onLongPress,
  });

  final String bank;
  final List<SenderRuleRow> rules;

  /// In the last 30 days; null while SMS isn't allowed.
  final int? messages;
  final TextStyle? muted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final codes = rules.map((r) => r.senderPattern).join(', ');
    final shared = templateForSender(rules.first.senderPattern)?.sharedIn;
    final parts = [
      codes,
      if (messages != null)
        plural(messages!, '1 message', '{0} messages'),
      if (shared != null) tr('shared on GitHub #{0}', [shared]),
    ];
    return GestureDetector(
      onLongPress: onLongPress,
      child: AppSwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: const AppIcon(Icons.account_balance_outlined),
        title: Text(bank, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(parts.join(' · '), style: muted),
        value: rules.any((r) => r.enabled),
        onChanged: onChanged,
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.read,
    required this.card,
    required this.muted,
    required this.onAdd,
  });

  final _Read read;
  final PendingStatus? card;
  final TextStyle? muted;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('d MMM, h:mm a').format(read.message.receivedAt);
    final result = read.result;
    if (result is! ParsedMessage) {
      return AppListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: AppIcon(Icons.remove_circle_outline_rounded, color: muted?.color),
        title: Text(
          read.message.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: muted,
        ),
        subtitle: Text(
          '${read.bank} · $when · ${_reason((result as Rejected).reason)}',
          style: muted,
        ),
      );
    }
    final out = result.direction == TxDirection.debit;
    final color = out ? AppColors.expense : AppColors.income;
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: AppIcon(
        out ? Icons.north_east_rounded : Icons.south_west_rounded,
        color: color,
      ),
      title: Row(
        children: [
          MoneyText(
            result.amount,
            color: color,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (result.merchant != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.merchant!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        [
          read.bank,
          when,
          if (result.accountHint != null) '••${result.accountHint}',
        ].join(' · '),
        style: muted,
      ),
      trailing: switch (card) {
        null => IconButton(
          tooltip: tr('Add to Review Inbox'),
          icon: const AppIcon(Icons.add_circle_outline_rounded),
          onPressed: onAdd,
        ),
        _ => Text(_cardLabel(card!), style: muted),
      },
    );
  }

  static String _cardLabel(PendingStatus s) => switch (s) {
    PendingStatus.pending => tr('In inbox'),
    PendingStatus.duplicate => tr('Possible duplicate'),
    PendingStatus.approved => tr('Added'),
    PendingStatus.autoFilled => tr('Added for you'),
    PendingStatus.dismissed => tr('Dismissed'),
  };

  static String _reason(RejectReason r) => switch (r) {
    RejectReason.otp => tr('OTP'),
    RejectReason.promotional => tr('Offer'),
    RejectReason.balanceOnly => tr('Balance only'),
    RejectReason.declined => tr('Declined'),
    RejectReason.noAmount ||
    RejectReason.noDirection ||
    RejectReason.notATransaction => tr('Not a payment'),
  };
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, required this.muted});

  final String text;
  final TextStyle? muted;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(text, style: muted?.copyWith(height: 1.5)),
    ),
  );
}

/// "Add a sender": the ID as the phone shows it, and a name for it.
class _AddSenderDialog extends StatefulWidget {
  const _AddSenderDialog();

  @override
  State<_AddSenderDialog> createState() => _AddSenderDialogState();
}

class _AddSenderDialogState extends State<_AddSenderDialog> {
  final _sender = TextEditingController();
  final _bank = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _sender.dispose();
    _bank.dispose();
    super.dispose();
  }

  void _save() {
    final code = normalizeSenderPattern(_sender.text);
    if (code == null) {
      setState(() => _error = tr('Enter the sender ID, like AX-FEDBNK-S'));
      return;
    }
    final bank = _bank.text.trim().isEmpty
        ? templateForSender(code)?.bank ?? code
        : _bank.text.trim();
    Navigator.pop(context, (code: code, bank: bank));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Tr('Add a sender'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('sms-sender-id'),
            controller: _sender,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: tr('Sender ID'),
              hintText: 'AX-FEDBNK-S',
              errorText: _error,
              helperText: tr('As your messages app shows it'),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('sms-sender-bank'),
            controller: _bank,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: tr('Bank name')),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Tr('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Tr('Add')),
      ],
    );
  }
}
