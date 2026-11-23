import '../../data/tables.dart' show TxType;
import '../money.dart';

/// A category voice add can file an entry under.
typedef VoiceCategory = ({int id, String name, bool income});

/// What a spoken sentence came to — everything optional except the type,
/// and all of it still editable on Add Transaction.
class VoiceDraft {
  const VoiceDraft({
    required this.type,
    this.amount,
    this.categoryId,
    this.payee,
    this.date,
    this.note,
  });

  /// [TxType.expense] or [TxType.income]. Expense unless something said
  /// money came in.
  final TxType type;
  final Money? amount;
  final int? categoryId;
  final String? payee;

  /// Only when the sentence named a day other than today.
  final DateTime? date;

  /// The words left once amount, type, payee and day are taken out —
  /// "taxi", "milk and bread".
  final String? note;

  @override
  String toString() =>
      'VoiceDraft($type, ${amount?.paise}, cat $categoryId, payee $payee, '
      'date $date, note $note)';
}

/// Reads a spoken money entry — "I took a taxi for 250 rupees", "got salary
/// 50,000", "Ramesh ko 500 diye" — into a [VoiceDraft]. No AI: fixed word
/// lists for Indian English and common Hinglish (India is the only country
/// voice add supports so far, see `voiceAddCountries`). Category names are
/// the user's own, so a category they made in any language still matches.
VoiceDraft parseVoiceEntry(
  String text, {
  required List<VoiceCategory> categories,
  required DateTime now,
}) {
  final tokens = _tokens(text);
  final used = List<bool>.filled(tokens.length, false);

  // ── Type ──────────────────────────────────────────────────────────────
  var expense = false;
  var income = false;
  var weakIncome = false;
  for (final (i, t) in tokens.indexed) {
    if (_expenseWords.contains(t)) {
      expense = true;
      used[i] = true;
    } else if (_incomeWords.contains(t)) {
      income = true;
      used[i] = true;
    } else if (_weakIncomeWords.contains(t)) {
      weakIncome = true;
      used[i] = true;
    }
  }
  final type = !expense && (income || weakIncome)
      ? TxType.income
      : TxType.expense;

  // ── Amount ────────────────────────────────────────────────────────────
  final amount = _amount(tokens, used);

  // ── Day ───────────────────────────────────────────────────────────────
  DateTime? date;
  final today = DateTime(now.year, now.month, now.day);
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t == 'yesterday') {
      final dayBefore = i >= 2 && tokens[i - 1] == 'before' && tokens[i - 2] == 'day';
      date = today.subtract(Duration(days: dayBefore ? 2 : 1));
      used[i] = true;
      if (dayBefore) used[i - 1] = used[i - 2] = true;
    } else if (t == 'today' || t == 'aaj') {
      used[i] = true;
    }
  }

  // ── Payee ─────────────────────────────────────────────────────────────
  String? payee;
  final marker = type == TxType.income ? 'from' : 'to';
  for (var i = 0; i < tokens.length && payee == null; i++) {
    if (tokens[i] == marker) {
      final words = <int>[];
      for (var j = i + 1; j < tokens.length && words.length < 3; j++) {
        if (!_isNameWord(tokens[j])) break;
        words.add(j);
      }
      if (words.isNotEmpty) {
        payee = _titleCase(words.map((j) => tokens[j]).join(' '));
        used[i] = true;
        for (final j in words) {
          used[j] = true;
        }
      }
    } else if (tokens[i] == 'ko' && i > 0 && _isNameWord(tokens[i - 1])) {
      // Hinglish: "Ramesh ko 500 diye".
      payee = _titleCase(tokens[i - 1]);
      used[i] = used[i - 1] = true;
    }
  }

  // ── Category ──────────────────────────────────────────────────────────
  final wantIncome = type == TxType.income;
  final pool = [
    for (final c in categories)
      if (c.income == wantIncome) c,
  ];
  final categoryId = _category(tokens, pool);

  // ── Note: what's left ─────────────────────────────────────────────────
  final rest = [
    for (final (i, t) in tokens.indexed)
      if (!used[i] && !_filler.contains(t)) t,
  ];
  // Trailing joiners ("taxi for", "milk and") read badly on their own.
  while (rest.isNotEmpty && _joiners.contains(rest.last)) {
    rest.removeLast();
  }
  while (rest.isNotEmpty && _joiners.contains(rest.first)) {
    rest.removeAt(0);
  }
  final note = rest.isEmpty
      ? null
      : '${rest.first[0].toUpperCase()}${rest.join(' ').substring(1)}';

  return VoiceDraft(
    type: type,
    amount: amount,
    categoryId: categoryId,
    payee: payee,
    date: date,
    note: note,
  );
}

// ── Words ───────────────────────────────────────────────────────────────

const _expenseWords = {
  'buy', 'bought', 'buying', 'purchase', 'purchased', 'paid', 'pay', //
  'paying', 'spent', 'spend', 'spending', 'gave', 'give', 'took', 'ordered',
  'order', 'recharged', 'kharida', 'kharidi', 'kharide', 'kharid', 'diya',
  'diye', 'di', 'bhara', 'bhare', 'lagaya', 'lagaye', 'kharcha', 'kharch',
  'expense',
};

const _incomeWords = {
  'received', 'receive', 'earned', 'earn', 'credited', 'salary', //
  'income', 'refund', 'refunded', 'cashback', 'bonus', 'sold', 'mila',
  'mile', 'mili', 'aaya', 'aaye', 'aayi', 'kamaya', 'kamaye',
};

/// Says money came in only when nothing says it went out — "got a taxi".
const _weakIncomeWords = {'got', 'get'};

const _currencyWords = {
  'rs', 'rupees', 'rupee', 'rupaye', 'rupay', 'rupiya', 'rupaiya', 'inr', //
  'bucks',
};

const _filler = {
  'i', 'a', 'an', 'the', 'my', 'me', 'of', 'for', 'on', 'at', 'in', 'is', //
  'was', 'it', 'some', 'worth', 'just', 'ka', 'ki', 'ke', 'se', 'ne',
  'maine', 'mene', 'hai', 'tha', 'thi', 'liye', 'by',
};

const _joiners = {'and', 'with', 'for', 'of', 'aur'};

/// Words that end a payee's name: "paid 500 to Ramesh for lunch".
const _nameStops = {
  'for', 'on', 'at', 'of', 'and', 'with', 'by', 'via', 'using', 'from', //
  'to', 'in', 'today', 'yesterday', 'aaj', 'kal', 'ko', 'ke', 'ki', 'ka',
  'se', 'liye',
};

bool _isNameWord(String t) =>
    RegExp(r'^[a-z][a-z.]*$').hasMatch(t) &&
    !_nameStops.contains(t) &&
    !_currencyWords.contains(t) &&
    !_expenseWords.contains(t) &&
    !_incomeWords.contains(t) &&
    !_weakIncomeWords.contains(t) &&
    !_filler.contains(t) &&
    !_numberWords.containsKey(t) &&
    !_multipliers.containsKey(t);

String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Lower-cased words, ₹ split off, commas inside numbers dropped
/// ("1,50,000" → "150000"), and stray punctuation gone.
List<String> _tokens(String text) {
  var t = text.toLowerCase().replaceAll('₹', ' rs ');
  // Indian grouping too: repeat until no digit,digit pair is left.
  final comma = RegExp(r'(\d),(\d)');
  while (comma.hasMatch(t)) {
    t = t.replaceAllMapped(comma, (m) => '${m[1]}${m[2]}');
  }
  t = t.replaceAll(RegExp(r'rs\.'), 'rs ');
  t = t.replaceAll(RegExp(r'[!?;:"“”()]'), ' ');
  return [
    for (final raw in t.split(RegExp(r'\s+')))
      if (raw.isNotEmpty)
        // A full stop or comma ending a word, never a decimal point.
        raw.replaceAll(RegExp(r'[.,]+$'), ''),
  ].where((w) => w.isNotEmpty).toList();
}

// ── Numbers ─────────────────────────────────────────────────────────────

const _numberWords = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, //
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
  'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
  'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
  'seventy': 70, 'eighty': 80, 'ninety': 90,
  // Hinglish — only the ones that can't be mistaken for an English word.
  'ek': 1, 'teen': 3, 'char': 4, 'chaar': 4, 'paanch': 5, 'panch': 5,
  'saat': 7, 'aath': 8, 'das': 10, 'bees': 20, 'pachas': 50,
  'pachaas': 50,
};

const _multipliers = {
  'hundred': 100, 'sau': 100, 'thousand': 1000, 'k': 1000, //
  'hazar': 1000, 'hazaar': 1000, 'lakh': 100000, 'lakhs': 100000,
  'lac': 100000, 'lacs': 100000, 'crore': 10000000, 'crores': 10000000,
  'cr': 10000000,
};

/// A number read from [start]: digits ("250", "2.5k", "1.5 lakh") or words
/// ("two hundred fifty", "five thousand", "two fifty" = 250), with how many
/// tokens it took. Null when nothing numeric starts there.
({double value, int length})? _numberAt(List<String> tokens, int start) {
  final first = tokens[start];

  final digits = RegExp(r'^(\d+(?:\.\d+)?)(k|l|cr)?$').firstMatch(first);
  if (digits != null) {
    var value = double.parse(digits[1]!);
    var length = 1;
    final suffix = digits[2];
    if (suffix != null) {
      value *= switch (suffix) {
        'k' => 1000,
        'l' => 100000,
        _ => 10000000,
      };
    } else if (start + 1 < tokens.length &&
        _multipliers.containsKey(tokens[start + 1])) {
      value *= _multipliers[tokens[start + 1]]!;
      length = 2;
    }
    return (value: value, length: length);
  }

  // Words. A Hindi "do" (two) only counts before a multiplier — alone it's
  // the English "do".
  bool isNum(int i) =>
      i < tokens.length &&
      (_numberWords.containsKey(tokens[i]) ||
          (tokens[i] == 'do' &&
              i + 1 < tokens.length &&
              _multipliers.containsKey(tokens[i + 1])) ||
          (tokens[i] == 'a' &&
              i + 1 < tokens.length &&
              _multipliers.containsKey(tokens[i + 1])));
  if (!isNum(start)) return null;

  var total = 0.0;
  var current = 0.0;
  var i = start;
  var sawMultiplier = false;
  final plain = <int>[]; // bare number words, for "two fifty"
  while (i < tokens.length) {
    final t = tokens[i];
    if (isNum(i)) {
      final n = t == 'do' ? 2 : (t == 'a' ? 1 : _numberWords[t]!);
      current += n;
      plain.add(n);
    } else if (_multipliers.containsKey(t) && (current > 0 || total > 0)) {
      final m = _multipliers[t]!;
      sawMultiplier = true;
      if (m == 100) {
        current *= 100;
      } else {
        total += (current == 0 ? 1 : current) * m;
        current = 0;
      }
    } else if (t == 'and' && i + 1 < tokens.length && isNum(i + 1)) {
      // "two hundred and fifty"
    } else {
      break;
    }
    i++;
  }
  // "two fifty" — how prices are said: hundreds, then the rest.
  if (!sawMultiplier &&
      plain.length == 2 &&
      plain[0] < 10 &&
      plain[1] >= 10 &&
      plain[1] < 100) {
    return (value: plain[0] * 100.0 + plain[1], length: i - start);
  }
  return (value: total + current, length: i - start);
}

/// The amount: the number nearest a currency word ("₹250", "50 rupees")
/// if there is one, else the first number that isn't a time or a date.
Money? _amount(List<String> tokens, List<bool> used) {
  ({double value, int start, int length})? best;
  var bestScore = -1;
  var i = 0;
  while (i < tokens.length) {
    final n = _numberAt(tokens, i);
    if (n == null) {
      i++;
      continue;
    }
    final after = i + n.length < tokens.length ? tokens[i + n.length] : '';
    final before = i > 0 ? tokens[i - 1] : '';
    final isTime = {'am', 'pm', "o'clock", 'baje', 'th', 'st', 'nd', 'rd'}
        .contains(after);
    final score = isTime
        ? 0
        : (_currencyWords.contains(after) || _currencyWords.contains(before))
        ? 3
        : 1;
    if (score > bestScore) {
      bestScore = score;
      best = (value: n.value, start: i, length: n.length);
    }
    i += n.length;
  }
  if (best == null || bestScore == 0 || best.value <= 0) return null;
  for (var j = best.start; j < best.start + best.length; j++) {
    used[j] = true;
  }
  final before = best.start - 1;
  final after = best.start + best.length;
  if (before >= 0 && _currencyWords.contains(tokens[before])) {
    used[before] = true;
  }
  if (after < tokens.length && _currencyWords.contains(tokens[after])) {
    used[after] = true;
  }
  return Money((best.value * 100).round());
}

// ── Categories ──────────────────────────────────────────────────────────

/// Everyday words → the category names they usually live under, most
/// likely first. Matched against the user's own categories by name.
const _hints = <String, List<String>>{
  // Getting around.
  'taxi': ['taxi', 'cab', 'transport', 'travel'],
  'cab': ['cab', 'taxi', 'transport', 'travel'],
  'uber': ['taxi', 'cab', 'transport', 'travel'],
  'ola': ['taxi', 'cab', 'transport', 'travel'],
  'rapido': ['taxi', 'cab', 'transport', 'travel'],
  'auto': ['auto', 'transport', 'travel'],
  'rickshaw': ['auto', 'transport', 'travel'],
  'metro': ['metro', 'transport', 'travel'],
  'bus': ['bus', 'transport', 'travel'],
  'train': ['train', 'transport', 'travel'],
  'flight': ['flight', 'travel', 'transport'],
  'petrol': ['fuel', 'petrol', 'transport', 'vehicle'],
  'diesel': ['fuel', 'transport', 'vehicle'],
  'fuel': ['fuel', 'transport', 'vehicle'],
  'parking': ['parking', 'transport', 'vehicle'],
  'toll': ['toll', 'transport', 'travel'],
  // Eating.
  'lunch': ['food', 'dining', 'eating', 'restaurant'],
  'dinner': ['food', 'dining', 'eating', 'restaurant'],
  'breakfast': ['food', 'dining', 'eating'],
  'snacks': ['food', 'snack'],
  'chai': ['food', 'tea', 'snack'],
  'tea': ['food', 'tea', 'snack'],
  'coffee': ['food', 'coffee', 'cafe'],
  'swiggy': ['food', 'dining'],
  'zomato': ['food', 'dining'],
  'restaurant': ['restaurant', 'dining', 'food'],
  'pizza': ['food', 'dining'],
  'biryani': ['food', 'dining'],
  'khana': ['food'],
  // Groceries.
  'grocery': ['grocer', 'food'],
  'groceries': ['grocer', 'food'],
  'vegetables': ['grocer', 'vegetable', 'food'],
  'sabzi': ['grocer', 'vegetable', 'food'],
  'fruits': ['grocer', 'fruit', 'food'],
  'milk': ['grocer', 'milk', 'dairy', 'food'],
  'doodh': ['grocer', 'milk', 'dairy', 'food'],
  'kirana': ['grocer', 'food'],
  'blinkit': ['grocer', 'food'],
  'zepto': ['grocer', 'food'],
  'bigbasket': ['grocer', 'food'],
  // Bills.
  'electricity': ['electric', 'bill', 'utilit'],
  'bijli': ['electric', 'bill', 'utilit'],
  'wifi': ['internet', 'wifi', 'bill', 'utilit'],
  'internet': ['internet', 'bill', 'utilit'],
  'broadband': ['internet', 'bill', 'utilit'],
  'gas': ['gas', 'bill', 'utilit'],
  'recharge': ['recharge', 'mobile', 'phone', 'bill'],
  'mobile': ['recharge', 'mobile', 'phone', 'bill'],
  'emi': ['emi', 'loan'],
  'rent': ['rent', 'housing', 'home'],
  'kiraya': ['rent', 'housing', 'home'],
  // Shopping.
  'clothes': ['cloth', 'shopping'],
  'shoes': ['shoe', 'cloth', 'shopping'],
  'amazon': ['shopping'],
  'flipkart': ['shopping'],
  'myntra': ['cloth', 'shopping'],
  'shopping': ['shopping'],
  // Health.
  'medicine': ['medic', 'health', 'pharma'],
  'medicines': ['medic', 'health', 'pharma'],
  'dawai': ['medic', 'health', 'pharma'],
  'doctor': ['doctor', 'medic', 'health'],
  'hospital': ['hospital', 'medic', 'health'],
  'pharmacy': ['pharma', 'medic', 'health'],
  // Fun.
  'movie': ['movie', 'entertain', 'fun'],
  'movies': ['movie', 'entertain', 'fun'],
  'netflix': ['subscription', 'entertain'],
  'cinema': ['movie', 'entertain'],
  // Learning.
  'fees': ['fee', 'education', 'school'],
  'school': ['school', 'education'],
  'college': ['college', 'education'],
  'books': ['book', 'education'],
  // Money in.
  'salary': ['salary', 'income', 'pay'],
  'tankhwah': ['salary', 'income'],
  'interest': ['interest'],
  'refund': ['refund'],
  'cashback': ['cashback', 'refund', 'reward'],
  'bonus': ['bonus', 'salary', 'income'],
  'gift': ['gift'],
  'profit': ['profit', 'business'],
};

/// A category straight by name — "food", "Eating out" — longest first,
/// else through [_hints]. Null when nothing fits.
int? _category(List<String> tokens, List<VoiceCategory> pool) {
  if (pool.isEmpty) return null;
  final sentence = ' ${tokens.join(' ')} ';
  final byLength = [...pool]
    ..sort((a, b) => b.name.length.compareTo(a.name.length));
  for (final c in byLength) {
    final name = c.name.toLowerCase().trim();
    if (name.isEmpty) continue;
    if (sentence.contains(' $name ') ||
        // A plural said for a singular name: "groceries"/"grocery".
        sentence.contains(' ${name}s ')) {
      return c.id;
    }
  }
  for (final t in tokens) {
    final hints = _hints[t];
    if (hints == null) continue;
    for (final hint in hints) {
      for (final c in pool) {
        if (c.name.toLowerCase().contains(hint)) return c.id;
      }
    }
  }
  return null;
}
