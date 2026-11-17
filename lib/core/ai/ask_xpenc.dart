import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import 'ai_engine.dart';
import 'ai_facts.dart';

/// One finished exchange in an Ask XPENC conversation.
class AiExchange {
  const AiExchange(this.question, this.answer);
  final String question;
  final String answer;
}

/// Ask XPENC: questions about your money, answered by the on-device model
/// from an [AiFactSheet] XPENC builds itself.
///
/// Read-only by design. The model sees facts and the user's AI Memory and
/// returns text; nothing it says is ever written to the ledger, and it is
/// told it can't change anything.
abstract final class AskXpenc {
  /// The question "Explain this month" asks (Stats, and the chat's chip).
  static String get explainMonthQuestion => tr(
    'Explain my month: what changed against last month, what stands out, '
    'and one thing to keep an eye on.',
  );

  /// Most exchanges the model is shown again — every one is read again
  /// before each answer, and a phone reads slowly.
  static const historyLimit = 2;

  /// The instructions, facts and memory the model answers from.
  static String systemPrompt({
    required AiFactSheet facts,
    required List<String> memories,
    required String languageName,
    DateTime? now,
  }) {
    final today = DateFormat(
      'EEEE d MMMM y',
      'en_US',
    ).format(now ?? DateTime.now());
    final out = StringBuffer()
      ..writeln(
        "You are XPENC's money assistant. You run offline on the user's "
        'phone and can only read; you cannot add, change or delete anything.',
      )
      ..writeln('Today is $today.')
      ..writeln('Rules:')
      ..writeln(
        '- Answer only from the FACTS below. Use their amounts exactly.',
      )
      ..writeln('- Never invent amounts, dates, names or categories.')
      ..writeln(
        "- If the facts don't answer the question, say you can't see that "
        'in XPENC.',
      )
      ..writeln(
        '- If asked to add, edit or delete something, say they can do it '
        'in XPENC themselves.',
      )
      ..writeln('- Be brief: at most 4 short sentences or 4 bullet points.')
      ..writeln('- Never give investment, tax or legal advice.')
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
  }) => [
    AiTurn.system(
      systemPrompt(
        facts: facts,
        memories: memories,
        languageName:
            languageName ?? appLanguageFor(L10n.code)?.englishName ?? 'English',
        now: now,
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
