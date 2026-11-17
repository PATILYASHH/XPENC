import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/tables.dart';
import '../money.dart';
import 'ai_engine.dart';
import 'ai_providers.dart';
import 'ai_store.dart';

/// What Local AI read off a shared bank message or payment screenshot that
/// the built-in parser couldn't make out. Becomes a Review Inbox card the
/// user checks — it is never posted on its own.
class AiReadPayment {
  const AiReadPayment({
    required this.direction,
    required this.amount,
    this.payee,
    this.last4,
  });

  final TxDirection direction;
  final Money amount;
  final String? payee;
  final String? last4;
}

/// Local AI's two jobs in message capture (both read-only):
///
/// - [readPayment]: when the parser can't read a shared message or
///   screenshot, pull the payment out of its text.
/// - [pickCategory]: suggest one of the user's own categories for a card.
///
/// A small model can be wrong, so nothing it says is taken on trust: the
/// answer's shape is forced by a grammar, an amount must appear in the
/// text word for word, and a payee or account number the text doesn't
/// contain is dropped.
abstract final class AiCapture {
  /// The longest text the model is shown — a bank message is a few lines;
  /// OCR of a whole screen can run on with menus and ads.
  static const maxText = 1500;

  static const paymentGrammar = r'''
root ::= "{\"payment\": " bool ", \"direction\": " dir ", \"amount\": " amount ", \"payee\": " text ", \"last4\": " last4 "}"
bool ::= "true" | "false"
dir ::= "\"out\"" | "\"in\""
amount ::= "\"" [0-9]{1,9} ("." [0-9]{1,2})? "\""
text ::= "\"" [^"\\\n]{0,48} "\""
last4 ::= "\"\"" | "\"" [0-9]{4} "\""
''';

  static const _paymentInstructions =
      'You read one bank SMS, UPI alert or payment-app screenshot text and '
      'reply with JSON only.\n'
      '- payment: true only if money actually moved (paid, debited, '
      'credited, received, sent, refunded). false for OTPs, offers, '
      'reminders, balance alerts, failed or declined payments.\n'
      '- direction: "out" if the user paid or was debited, "in" if the user '
      'received money or was credited.\n'
      '- amount: the amount of this payment, digits only (no commas, no '
      'currency). Not the balance.\n'
      '- payee: the merchant or person on the other side, as written in the '
      'text; empty if none.\n'
      "- last4: the last 4 digits of the user's account or card if shown; "
      'empty otherwise.';

  static String _clip(String text) {
    final t = text.trim();
    return t.length > maxText ? t.substring(0, maxText) : t;
  }

  static Future<String> _run(
    AiEngine engine,
    List<AiTurn> turns,
    String grammar,
    int maxTokens,
  ) async {
    final out = StringBuffer();
    await for (final piece in engine.chat(
      turns,
      temperature: 0,
      maxTokens: maxTokens,
      grammar: grammar,
    )) {
      out.write(piece);
    }
    return out.toString();
  }

  /// Asks the model for the payment in [text]; null when it isn't one, or
  /// when what the model said doesn't hold up against the text.
  static Future<AiReadPayment?> readPayment(
    AiEngine engine,
    String text,
  ) async {
    final source = _clip(text);
    if (source.isEmpty) return null;
    final raw = await _run(
      engine,
      [const AiTurn.system(_paymentInstructions), AiTurn.user(source)],
      paymentGrammar,
      120,
    );
    return accept(source, raw);
  }

  /// The model's JSON [answer] for [source], checked: kept only if it's a
  /// payment whose amount is written in the text.
  static AiReadPayment? accept(String source, String answer) {
    final Object? json;
    try {
      json = jsonDecode(answer.trim());
    } catch (_) {
      return null;
    }
    if (json is! Map || json['payment'] != true) return null;

    final amountText = json['amount'];
    final value = amountText is String ? double.tryParse(amountText) : null;
    if (value == null || value <= 0 || !_mentions(source, value)) return null;
    final amount = Money.tryParse(amountText as String);
    if (amount == null || !amount.isPositive) return null;

    final direction = switch (json['direction']) {
      'out' => TxDirection.debit,
      'in' => TxDirection.credit,
      _ => null,
    };
    if (direction == null) return null;

    final lower = source.toLowerCase();
    final payeeText = json['payee'];
    final payee = payeeText is String ? payeeText.trim() : '';
    final last4Text = json['last4'];
    final last4 = last4Text is String ? last4Text.trim() : '';
    return AiReadPayment(
      direction: direction,
      amount: amount,
      payee: payee.length >= 2 && lower.contains(payee.toLowerCase())
          ? payee
          : null,
      last4: RegExp(r'^\d{4}$').hasMatch(last4) && source.contains(last4)
          ? last4
          : null,
    );
  }

  static final _number = RegExp(r'\d[\d,]*(?:\.\d+)?');

  /// Whether [value] is written in [source] — "1,250.00", "1250" and
  /// "1250.5" all count for 1250 / 1250.5. Stops a model inventing an
  /// amount, or turning a date or reference number into one.
  static bool _mentions(String source, double value) {
    for (final m in _number.allMatches(source)) {
      final n = double.tryParse(m[0]!.replaceAll(',', ''));
      if (n != null && (n - value).abs() < 0.005) return true;
    }
    return false;
  }

  /// A GBNF string literal for [s].
  static String _literal(String s) =>
      '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

  /// Exactly one of [names], or `none`.
  static String categoryGrammar(List<String> names) =>
      'root ::= ${[...names, 'none'].map(_literal).join(' | ')}\n';

  /// One of [categories] for a card, or null when none fits (or the model
  /// can't say). [kind] is the card's direction's kind.
  static Future<int?> pickCategory(
    AiEngine engine, {
    required List<CategoryRow> categories,
    required CategoryKind kind,
    required Money amount,
    String? payee,
    String? text,
  }) async {
    final byName = <String, int>{};
    for (final c in categories) {
      if (c.kind != kind || c.isArchived) continue;
      byName.putIfAbsent(c.name.trim(), () => c.id);
    }
    if (byName.isEmpty) return null;
    final names = byName.keys.toList();
    final raw = await _run(
      engine,
      [
        AiTurn.system(
          "You file the user's money entries into their own categories. "
          'Reply with exactly one category name from the list, or none if '
          'nothing fits.\nCategories: ${names.join(', ')}',
        ),
        AiTurn.user(
          [
            '${kind == CategoryKind.expense ? 'Money out' : 'Money in'}: '
                '${amount.rupees}',
            if (payee != null && payee.trim().isNotEmpty) 'Payee: $payee',
            if (text != null && text.trim().isNotEmpty)
              'Message: ${_clip(text)}',
          ].join('\n'),
        ),
      ],
      categoryGrammar(names),
      24,
    );
    return byName[raw.trim()];
  }
}

/// What message capture asks of Local AI — a seam, so share intake can run
/// (and be tested) without a model.
abstract interface class AiPaymentReader {
  /// On, with a chat model imported.
  Future<bool> get available;

  Future<AiReadPayment?> read(String text);
}

/// [AiPaymentReader] over the phone's own model. Loads it for the read and
/// lets it go after, so a share doesn't leave a gigabyte in memory.
class LocalAiPaymentReader implements AiPaymentReader {
  LocalAiPaymentReader(this.ref);

  final Ref ref;

  @override
  Future<bool> get available async {
    if (!ref.read(aiSupportedProvider)) return false;
    try {
      return (await ref.read(aiStateProvider.future)).ready;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AiReadPayment?> read(String text) async {
    if (!await available) return null;
    final controller = ref.read(aiStateProvider.notifier);
    try {
      final engine = await controller.ready(AiModelKind.chat);
      try {
        return await AiCapture.readPayment(engine, text);
      } finally {
        await engine.unloadChat();
      }
    } catch (_) {
      return null;
    }
  }
}
