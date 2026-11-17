import 'package:exosynk_ai/exosynk_ai.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../platform/distribution.dart';
import 'ai_engine.dart';
import 'ai_facts.dart';

/// One finished exchange in an Ask Exo conversation.
class AiExchange {
  const AiExchange(this.question, this.answer);
  final String question;
  final String answer;
}

/// Ask Exo, inside XPENC: questions about your money, answered by the
/// on-device model from an [AiFactSheet] XPENC builds itself.
///
/// Exo is the one assistant of every ExoSynk Labs app — who it is, what it
/// knows about ExoSynk Labs, and the rules it keeps everywhere come from
/// the shared `exosynk_ai` package. This class adds only XPENC's part: the
/// money rules and the figures.
///
/// Read-only by design. The model sees facts and the user's AI Memory and
/// returns text; nothing it says is ever written to the ledger.
abstract final class AskExo {
  /// The question "Explain this month" asks (Stats, and the chat's chip).
  static String get explainMonthQuestion => tr(
    'Explain my month: what changed against last month, what stands out, '
    'and one thing to keep an eye on.',
  );

  /// Most exchanges the model is shown again — every one is read again
  /// before each answer, and a phone reads slowly.
  static const historyLimit = 2;

  /// Sister apps this build mustn't mention — F-Droid's may not promote
  /// CONECTR (see [Distribution.promotesConectr]).
  static Set<String> get hiddenApps =>
      Distribution.promotesConectr ? const {} : const {'conectr'};

  /// The instructions, facts and memory the model answers from.
  /// [modelName] is the imported model's file name, so Exo can say
  /// honestly what it runs on.
  static String systemPrompt({
    required AiFactSheet facts,
    required List<String> memories,
    required String languageName,
    DateTime? now,
    String? modelName,
  }) {
    final today = DateFormat(
      'EEEE d MMMM y',
      'en_US',
    ).format(now ?? DateTime.now());
    final out = StringBuffer()
      ..writeln(
        ExoKnowledge.about(
          currentAppId: 'xpenc',
          hiddenApps: hiddenApps,
          modelName: modelName,
        ),
      )
      ..writeln('Today is $today.')
      ..writeln('Rules:');
    for (final rule in ExoKnowledge.sharedRules) {
      out.writeln('- $rule');
    }
    out
      ..writeln(
        '- For money questions, answer only from the FACTS below and use '
        'their amounts exactly.',
      )
      ..writeln(
        "- If the facts don't answer a money question, say you can't see "
        'that in XPENC.',
      )
      ..writeln(
        '- Questions about yourself, ${Exo.maker} or its apps: answer from '
        'what you were told above, nothing more.',
      )
      ..writeln('- Reply in $languageName.');
    if (memories.isNotEmpty) {
      out.writeln('\nREMEMBER (the user asked you to keep these in mind):');
      for (final m in memories) {
        out.writeln('- $m');
      }
    }
    out
      ..writeln('\nFACTS:')
      ..writeln(facts.toPrompt());
    return out.toString();
  }

  /// The conversation the model reads: instructions, the last few
  /// exchanges, then [question].
  static List<AiTurn> turns({
    required String question,
    required AiFactSheet facts,
    required List<String> memories,
    List<AiExchange> history = const [],
    String? languageName,
    DateTime? now,
    String? modelName,
  }) => [
    AiTurn.system(
      systemPrompt(
        facts: facts,
        memories: memories,
        languageName:
            languageName ?? appLanguageFor(L10n.code)?.englishName ?? 'English',
        now: now,
        modelName: modelName,
      ),
    ),
    for (final e
        in history.length > historyLimit
            ? history.sublist(history.length - historyLimit)
            : history) ...[AiTurn.user(e.question), AiTurn.assistant(e.answer)],
    AiTurn.user(question),
  ];

  /// Cleans what a small model sometimes adds around its answer: a
  /// "thinking" block, stray role tags, blank lines.
  static String tidy(String answer) {
    var text = answer.replaceAll(
      RegExp(r'<think>[\s\S]*?(</think>|$)', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'<\|[^|>]*\|>'), '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
