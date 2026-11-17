import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/ai_engine.dart';
import '../../core/ai/ai_facts.dart';
import '../../core/ai/ai_providers.dart';
import '../../core/ai/ai_store.dart';
import '../../core/ai/ask_exo.dart';
import '../../core/ai/voice_input.dart';
import '../../core/l10n/l10n.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/open_link.dart';
import 'ai_memory_screen.dart';

/// Where "Report this answer" goes (Google Play asks every app with AI
/// answers to let people flag a bad one). Opens the mail app; XPENC itself
/// sends nothing.
const _reportEmail = 'feedback.yashpatil@gmail.com';

/// Ask Exo: a read-only conversation about your money with the on-device
/// model. [autoAsk] `month` asks "Explain my month" on open (Stats' ✨).
class AskExoScreen extends ConsumerStatefulWidget {
  const AskExoScreen({super.key, this.autoAsk});

  final String? autoAsk;

  @override
  ConsumerState<AskExoScreen> createState() => _AskExoScreenState();
}

class _AskExoScreenState extends ConsumerState<AskExoScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _listening = false;
  bool _transcribing = false;
  late final AiEngine _engine;
  late final AskExoController _conversation;

  @override
  void initState() {
    super.initState();
    _engine = ref.read(aiEngineProvider);
    _conversation = ref.read(askExoProvider.notifier);
    if (widget.autoAsk == 'month') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final asked = ref.read(askExoProvider);
        final q = AskExo.explainMonthQuestion;
        if (asked.isEmpty || asked.last.question != q) _ask(q);
      });
    }
  }

  @override
  void dispose() {
    if (_listening) VoiceInput.cancel();
    // A model can hold a gigabyte; give it back once the user leaves. The
    // conversation itself stays until "New chat" or the app closes.
    _conversation.stop().then((_) async {
      await _engine.unloadChat();
      await _engine.unloadSpeech();
    });
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _ask(String question) async {
    final q = question.trim();
    if (q.isEmpty) return;
    _input.clear();
    _toBottom();
    await ref.read(askExoProvider.notifier).ask(q);
    _toBottom();
  }

  Future<void> _mic() async {
    if (_transcribing) return;
    if (!_listening) {
      final started = await VoiceInput.start();
      switch (started) {
        case VoiceStartResult.ok:
          setState(() => _listening = true);
        case VoiceStartResult.noPermission:
          _snack(tr('Voice input needs the microphone.'));
        case VoiceStartResult.blocked:
          _snack(
            tr('Turn the microphone on in Settings → Permissions to speak.'),
          );
        case VoiceStartResult.failed:
          _snack(tr("The microphone couldn't start."));
      }
      return;
    }
    final pcm = await VoiceInput.stop();
    setState(() {
      _listening = false;
      _transcribing = true;
    });
    try {
      if (VoiceInput.tooShort(pcm)) {
        _snack(tr("Didn't catch that — tap 🎤, speak, then tap again."));
        return;
      }
      final engine = await ref
          .read(aiStateProvider.notifier)
          .ready(AiModelKind.speech);
      final text = await engine.transcribe(
        pcm,
        language: VoiceInput.whisperLanguage(),
      );
      if (!mounted) return;
      final heard = text.trim();
      if (heard.isEmpty) {
        _snack(tr("Didn't catch that — tap 🎤, speak, then tap again."));
        return;
      }
      final current = _input.text.trim();
      _input.text = current.isEmpty ? heard : '$current $heard';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    } catch (_) {
      _snack(
        tr("Voice input couldn't start. Check the voice model in Local AI."),
      );
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final messages = ref.watch(askExoProvider);
    final device = ref.watch(aiStateProvider).valueOrNull;
    final on = ref.watch(aiOnProvider);
    final busy = messages.isNotEmpty && messages.last.busy;
    ref.listen(askExoProvider, (_, _) => _toBottom());

    return Scaffold(
      appBar: AppTopBar(
        title: const Tr('Ask Exo'),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              tooltip: tr('New chat'),
              icon: const AppIcon(Icons.add_comment_outlined),
              onPressed: () => ref.read(askExoProvider.notifier).clear(),
            ),
          IconButton(
            tooltip: tr('Local AI settings'),
            icon: const AppIcon(Icons.tune_rounded),
            onPressed: () => context.push('/more/settings/local-ai'),
          ),
        ],
      ),
      body: !on
          ? _OffState(onOpen: () => context.push('/more/settings/local-ai'))
          : Column(
              children: [
                if (device != null && device.chat == null)
                  _NoModelBanner(
                    onOpen: () => context.push('/more/settings/local-ai'),
                  ),
                Expanded(
                  child: messages.isEmpty
                      ? _Suggestions(onPick: _ask)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: messages.length,
                          itemBuilder: (context, i) =>
                              _Exchange(message: messages[i]),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 300,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction: TextInputAction.send,
                                onSubmitted: busy ? null : _ask,
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: _listening
                                      ? tr('Listening… tap 🎤 to stop')
                                      : _transcribing
                                      ? tr('Turning speech into text…')
                                      : tr('Ask about your money'),
                                ),
                              ),
                            ),
                            if (device?.canListen ?? false) ...[
                              const SizedBox(width: 6),
                              IconButton.filledTonal(
                                tooltip: _listening
                                    ? tr('Stop listening')
                                    : tr('Speak'),
                                style: _listening
                                    ? IconButton.styleFrom(
                                        backgroundColor: cs.errorContainer,
                                        foregroundColor: cs.onErrorContainer,
                                      )
                                    : null,
                                icon: _transcribing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : AppIcon(
                                        _listening
                                            ? Icons.stop_rounded
                                            : Icons.mic_none_rounded,
                                      ),
                                onPressed: busy ? null : _mic,
                              ),
                            ],
                            const SizedBox(width: 6),
                            busy
                                ? IconButton.filled(
                                    tooltip: tr('Stop'),
                                    icon: const AppIcon(Icons.stop_rounded),
                                    onPressed: () => ref
                                        .read(askExoProvider.notifier)
                                        .stop(),
                                  )
                                : IconButton.filled(
                                    tooltip: tr('Ask'),
                                    icon: const AppIcon(
                                      Icons.arrow_upward_rounded,
                                    ),
                                    onPressed: () => _ask(_input.text),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Tr(
                          'Runs on this phone and only reads. It can be '
                          'wrong — check the figures under each answer.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _OffState extends StatelessWidget {
  const _OffState({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Tr(
              'Local AI is off. Turn it on in Settings → Local AI.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onOpen, child: const Tr('Open Local AI')),
          ],
        ),
      ),
    );
  }
}

class _NoModelBanner extends StatelessWidget {
  const _NoModelBanner({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AppCard(
        child: AppListTile(
          leading: AppIcon(
            Icons.download_for_offline_outlined,
            color: cs.primary,
          ),
          title: const Tr('Add an AI model to get answers in words'),
          subtitle: const Tr('Until then, you see the figures on their own.'),
          trailing: const AppIcon(Icons.chevron_right_rounded),
          onTap: onOpen,
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final suggestions = [
      AskExo.explainMonthQuestion,
      tr('Where did my money go this month?'),
      tr('How am I doing on my budgets?'),
      tr('Who owes me money?'),
      tr("What's coming up in the next two weeks?"),
      tr('How does this month compare with last month?'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        AppIcon(Icons.auto_awesome_outlined, size: 44, color: cs.primary),
        const SizedBox(height: 12),
        Tr(
          "Hi, I'm Exo",
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Tr(
          'Ask about your money. Answers come from your XPENC data, worked '
          'out on this phone.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, s) in suggestions.indexed)
              ActionChip(
                avatar: i == 0
                    ? AppIcon(
                        Icons.insights_rounded,
                        size: 16,
                        color: cs.primary,
                      )
                    : null,
                label: Text(i == 0 ? tr('Explain my month') : s, maxLines: 2),
                onPressed: () => onPick(s),
              ),
          ],
        ),
      ],
    );
  }
}

class _Exchange extends ConsumerWidget {
  const _Exchange({required this.message});
  final AskMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final m = message;

    final status = switch (m.status) {
      AskStatus.gathering => tr('Reading your data…'),
      AskStatus.loading => tr('Starting the AI…'),
      AskStatus.answering when m.answer.isEmpty => tr('Thinking…'),
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onLongPress: () =>
                  editAiMemory(context, ref, initial: m.question),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  m.question,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status != null)
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          status,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  if (m.answer.isNotEmpty)
                    SelectableText(m.answer, style: theme.textTheme.bodyMedium),
                  if (m.status == AskStatus.noModel)
                    Tr(
                      'No AI model yet, so here are the figures it would '
                      'answer from.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  if (m.status == AskStatus.failed)
                    Text(
                      m.error ?? tr('Something went wrong.'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.error,
                      ),
                    ),
                  if (m.status == AskStatus.stopped)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Tr(
                        'Stopped.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (m.facts != null && !m.facts!.isEmpty)
                    _BasedOn(
                      facts: m.facts!,
                      initiallyExpanded: m.status == AskStatus.noModel,
                    ),
                  if (m.status == AskStatus.done && m.answer.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: tr('Copy'),
                          visualDensity: VisualDensity.compact,
                          icon: const AppIcon(Icons.copy_rounded, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: m.answer),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(content: Tr('Copied')));
                          },
                        ),
                        IconButton(
                          tooltip: tr('Report this answer'),
                          visualDensity: VisualDensity.compact,
                          icon: const AppIcon(Icons.flag_outlined, size: 18),
                          onPressed: () => _report(context, ref, m),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref, AskMessage m) {
    final model = ref.read(aiStateProvider).valueOrNull?.chat?.name ?? '?';
    final body =
        'Model: $model\n\nQuestion:\n${m.question}\n\nAnswer:\n${m.answer}\n\n'
        'What was wrong:\n';
    final uri = Uri(
      scheme: 'mailto',
      path: _reportEmail,
      queryParameters: {
        'subject': 'XPENC Local AI answer report',
        'body': body,
      },
    );
    // Uri encodes spaces as '+', which mail apps show literally.
    return openLink(
      context,
      uri.toString().replaceAll('+', '%20'),
      copyValue: body,
    );
  }
}

class _BasedOn extends StatelessWidget {
  const _BasedOn({required this.facts, required this.initiallyExpanded});
  final AiFactSheet facts;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: AppIcon(
          Icons.fact_check_outlined,
          size: 18,
          color: cs.primary,
        ),
        title: Tr(
          'Based on',
          style: theme.textTheme.labelLarge?.copyWith(color: cs.primary),
        ),
        children: [
          for (final s in facts.sections)
            if (s.lines.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Text(
                  s.title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final line in s.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• $line',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
