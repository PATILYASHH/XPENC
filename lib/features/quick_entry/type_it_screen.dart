import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/currency.dart';
import '../../core/l10n/l10n.dart';
import '../../core/money.dart';
import '../../core/voice/voice_parser.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/modes_db.dart';
import '../../data/providers.dart';
import '../voice_add/voice_add_controller.dart' show voiceAddRoute;
import 'entry_sources.dart';

/// "Type it" (GitHub #213): an amount and a word or two — "34 supermarket"
/// — and Save files it, no form. The category comes from the keywords the
/// person gave their categories (or a category's own name), money in or out
/// from that category, the account from the words or the last one used.
/// What will be saved is shown as it's typed; "Edit first" opens Add
/// Transaction filled in instead.
class TypeItScreen extends ConsumerStatefulWidget {
  const TypeItScreen({super.key});

  @override
  ConsumerState<TypeItScreen> createState() => _TypeItScreenState();
}

class _TypeItScreenState extends ConsumerState<TypeItScreen> {
  final _text = TextEditingController();

  /// The account the newest transaction used — the default, as on Add.
  int? _lastAccountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    ref.read(dbProvider).watchTransactions(limit: 1).first.then((txs) {
      if (mounted && txs.isNotEmpty) {
        setState(() => _lastAccountId = txs.first.accountId);
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// The account it goes to: one the words named, else the last used, else
  /// the first — always one the mode that's ON allows.
  AccountRow? _account(VoiceDraft draft, ModeRow? mode, {bool listen = true}) {
    T get<T>(ProviderListenable<T> p) => listen ? ref.watch(p) : ref.read(p);
    final allowed = {
      for (final a in get(pickerAccountsProvider(mode?.id))) a.id,
    };
    final usable = [
      for (final a in get(entryAccountRowsProvider))
        if (allowed.contains(a.id)) a,
    ];
    AccountRow? byId(int? id) => usable.where((a) => a.id == id).firstOrNull;
    return byId(draft.accountId) ??
        byId(_lastAccountId) ??
        usable.where((a) => a.linkedAccountId == null).firstOrNull ??
        usable.firstOrNull;
  }

  /// The currency [account] posts in — a debit card follows its bank.
  Currency _currencyOf(AccountRow account, {bool listen = true}) {
    final map = listen
        ? ref.watch(accountMapProvider)
        : ref.read(accountMapProvider);
    final code = account.linkedAccountId == null
        ? account.currencyCode
        : map[account.linkedAccountId]?.currencyCode;
    return code == null ? MoneyFormat.currency : currencyForCode(code);
  }

  /// A trip abroad keeps its own currency — the typed figure can't say which
  /// it means, so that one goes through Add, where both are on screen.
  bool _modeAbroad(ModeRow? mode) =>
      mode?.currencyCode != null &&
      mode!.currencyCode != MoneyFormat.currency.code;

  DateTime _when(VoiceDraft draft) {
    final now = DateTime.now();
    final day = draft.date;
    return day == null
        ? now
        : DateTime(day.year, day.month, day.day, now.hour, now.minute);
  }

  Future<void> _save() async {
    if (_saving) return;
    final mode = ref.read(activeModeProvider);
    final draft = parseTypedEntry(ref, _text.text, listen: false);
    final amount = draft.amount;
    final account = _account(draft, mode, listen: false);
    if (amount == null || !amount.isPositive || account == null) return;
    if (_modeAbroad(mode)) return _editFirst();

    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final category = ref.read(categoryMapProvider)[draft.categoryId];
    final shown = MoneyFormat.symbolIn(
      amount,
      _currencyOf(account, listen: false),
    );
    final db = ref.read(dbProvider);
    setState(() => _saving = true);
    final int id;
    try {
      id = await db.addTransaction(
        type: draft.type,
        amount: amount,
        accountId: account.id,
        categoryId: draft.categoryId,
        date: _when(draft),
        note: draft.note,
        payee: draft.payee,
        modeId: mode?.id,
      );
      await db.applyModeTags(id, mode?.id);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message?.toString() ?? tr('Could not save transaction')),
        ),
      );
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          tr('Saved {0} · {1}', [shown, category?.name ?? tr('No category')]),
        ),
        // Not right? Fix it where everything can be changed.
        action: SnackBarAction(
          label: tr('Edit'),
          onPressed: () => router.push('/add?id=$id'),
        ),
      ),
    );
  }

  /// Add Transaction with what was typed filled in, in place of this page.
  void _editFirst() {
    final draft = parseTypedEntry(ref, _text.text, listen: false);
    GoRouter.of(context).pushReplacement(voiceAddRoute(draft));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mode = ref.watch(activeModeProvider);
    final typed = _text.text.trim();
    final draft = parseTypedEntry(ref, typed);
    final account = _account(draft, mode);
    final amount = draft.amount;
    final abroad = _modeAbroad(mode);
    final canSave =
        amount != null && amount.isPositive && account != null && !_saving;
    final noKeywords = ref.watch(entryKeywordsProvider).isEmpty;

    return Scaffold(
      appBar: AppTopBar(
        leading: IconButton(
          icon: const AppIcon(Icons.close_rounded),
          tooltip: tr('Close'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Tr('Type it'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextField(
              key: const Key('type-it-field'),
              controller: _text,
              autofocus: true,
              textInputAction: TextInputAction.done,
              style: theme.textTheme.titleLarge,
              decoration: InputDecoration(
                hintText: tr('34 supermarket'),
                prefixIcon: const AppIcon(Icons.keyboard_alt_outlined),
              ),
              onSubmitted: (_) => abroad
                  ? (canSave ? _editFirst() : null)
                  : (canSave ? _save() : null),
            ),
            const SizedBox(height: 8),
            Tr(
              'An amount and a word or two. Where it goes comes from the '
              "keywords you give your categories — or a category's name.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (typed.isNotEmpty)
              _Preview(
                draft: draft,
                account: account,
                currency: account == null ? null : _currencyOf(account),
                when: _when(draft),
              ),
            if (typed.isNotEmpty && amount == null) ...[
              const SizedBox(height: 12),
              _Hint(text: tr('Add an amount — like "34 supermarket".')),
            ] else if (typed.isNotEmpty && draft.categoryId == null) ...[
              const SizedBox(height: 12),
              _Hint(
                text: tr(
                  'No category matched. It saves without one — or give a '
                  'category this word as a keyword, and next time it goes '
                  'there by itself.',
                ),
              ),
            ],
            if (abroad) ...[
              const SizedBox(height: 12),
              _Hint(
                text: tr(
                  '{0} keeps its own currency, so this opens in Add to say '
                  'which one the amount is in.',
                  [mode!.name],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('type-it-edit-first'),
                    onPressed: typed.isEmpty ? null : _editFirst,
                    child: const Tr('Edit first'),
                  ),
                ),
                if (!abroad) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('type-it-save'),
                      onPressed: canSave ? _save : null,
                      child: const Tr('Save'),
                    ),
                  ),
                ],
              ],
            ),
            if (noKeywords) ...[
              const SizedBox(height: 28),
              _Hint(
                icon: Icons.lightbulb_outline_rounded,
                text: tr(
                  'Give a category keywords — open it in Categories & Tags, '
                  'or hold it in the category picker — and "34 supermarket" '
                  'files itself.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What Save will file, read live from the words.
class _Preview extends ConsumerWidget {
  const _Preview({
    required this.draft,
    required this.account,
    required this.currency,
    required this.when,
  });

  final VoiceDraft draft;
  final AccountRow? account;
  final Currency? currency;
  final DateTime when;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final category = ref.watch(categoryMapProvider)[draft.categoryId];
    final parent = ref.watch(categoryMapProvider)[category?.parentId];
    final amount = draft.amount;
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(when);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );

    Widget row(Widget leading, Widget label) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(width: 32, child: Center(child: leading)),
          const SizedBox(width: 12),
          Expanded(child: label),
        ],
      ),
    );

    return AppCard(
      key: const Key('type-it-preview'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(
                  iconForTxType(draft.type),
                  color: colorForTxType(draft.type),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    labelForTxType(draft.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorForTxType(draft.type),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // A long figure shrinks rather than pushing off the card.
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        amount == null
                            ? '—'
                            : currency == null
                            ? MoneyFormat.symbol(amount)
                            : MoneyFormat.symbolIn(amount, currency!),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorForTxType(draft.type),
                          fontFeatures: kTabularFigures,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            row(
              category == null
                  ? AppIcon(Icons.help_outline_rounded, color: cs.onSurfaceVariant)
                  : IconWell.forKey(
                      category.iconKey,
                      color: Color(category.colorValue),
                      size: 20,
                    ),
              Text(
                category == null
                    ? tr('No category')
                    : parent == null
                    ? category.name
                    : '${parent.name} › ${category.name}',
                style: category == null ? muted : theme.textTheme.bodyLarge,
              ),
            ),
            row(
              AppIcon(
                Icons.account_balance_wallet_outlined,
                color: cs.onSurfaceVariant,
              ),
              Text(
                account?.name ?? tr('No account to post to'),
                style: account == null ? muted : theme.textTheme.bodyLarge,
              ),
            ),
            if (draft.payee != null)
              row(
                AppIcon(Icons.person_outline_rounded, color: cs.onSurfaceVariant),
                Text(draft.payee!, style: theme.textTheme.bodyLarge),
              ),
            if (draft.note != null)
              row(
                AppIcon(Icons.notes_rounded, color: cs.onSurfaceVariant),
                Text(draft.note!, style: theme.textTheme.bodyLarge),
              ),
            if (day != today)
              row(
                AppIcon(Icons.event_outlined, color: cs.onSurfaceVariant),
                Text(
                  MaterialLocalizations.of(context).formatMediumDate(day),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
