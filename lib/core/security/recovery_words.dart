import 'dart:math';

/// Word source for the master recovery phrase (GitHub #74) — short, common,
/// unambiguous-to-spell English words only. 160 words at 10 words/phrase is
/// 160^10 (~1.1 x 10^22) possible phrases, far past what matters for a
/// device-local fallback: the threat model is "someone guessing without the
/// paper it's written on", not offline brute force.
class RecoveryWords {
  const RecoveryWords._();

  /// Words per phrase — fixed, not user-configurable (GitHub #74).
  static const int wordCount = 10;

  static const List<String> wordlist = [
    'anchor', 'apple', 'arrow', 'autumn', 'banana', 'basket', 'beach',
    'bear', 'bell', 'bench', 'berry', 'bicycle', 'blanket', 'bloom',
    'boat', 'bottle', 'branch', 'brave', 'bread', 'breeze', 'bridge',
    'bright', 'brook', 'brown', 'brush', 'bubble', 'candle', 'canyon',
    'castle', 'cedar', 'chair', 'cherry', 'chess', 'circle', 'cliff',
    'cloud', 'clover', 'coast', 'comet', 'copper', 'coral', 'cotton',
    'crane', 'crater', 'cricket', 'crown', 'crystal', 'dawn', 'daisy',
    'delta', 'desert', 'diamond', 'dolphin', 'dragon', 'dream', 'drift',
    'eagle', 'earth', 'ember', 'engine', 'evening', 'falcon', 'feather',
    'fence', 'ferry', 'field', 'flame', 'flute', 'forest', 'fossil',
    'fountain', 'fox', 'frost', 'garden', 'gate', 'ginger', 'glacier',
    'globe', 'gold', 'granite', 'grape', 'gravel', 'harbor', 'harvest',
    'hazel', 'hedge', 'helmet', 'heron', 'hill', 'honey', 'horizon',
    'island', 'ivory', 'jacket', 'jade', 'jasmine', 'jungle', 'kettle',
    'kingdom', 'kite', 'ladder', 'lagoon', 'lantern', 'laurel', 'leaf',
    'lemon', 'lighthouse', 'lily', 'lion', 'lotus', 'maple', 'marble',
    'marsh', 'meadow', 'melody', 'mint', 'mirror', 'mist', 'moon',
    'moss', 'mountain', 'nectar', 'needle', 'nest', 'noble', 'north',
    'oasis', 'ocean', 'olive', 'onyx', 'orange', 'orbit', 'orchard',
    'otter', 'owl', 'oxygen', 'oyster', 'palace', 'panther', 'pearl',
    'pebble', 'petal', 'pigeon', 'pillar', 'pine', 'planet', 'plum',
    'pond', 'poppy', 'prairie', 'quartz', 'rabbit', 'raven', 'reef',
    'ribbon', 'ridge', 'river', 'robin', 'rocket', 'rose', 'saddle',
    'saffron', 'sail', 'salmon', 'sand', 'sapphire', 'scarf', 'sequoia',
    'shadow', 'shell', 'shore', 'silver', 'sky', 'sleigh', 'smoke',
    'sparrow', 'spring', 'spruce', 'star', 'stone', 'storm', 'stream',
    'summer', 'sunset', 'swan', 'sycamore', 'temple', 'thistle', 'thunder',
    'tiger', 'timber', 'topaz', 'trail', 'tulip', 'tundra', 'turtle',
    'valley', 'velvet', 'violet', 'walnut', 'willow', 'winter', 'wolf',
  ];

  static final _random = Random.secure();

  /// [wordCount] distinct random words from [wordlist], in the order the
  /// user should write them down.
  static List<String> generate() {
    final pool = List<String>.of(wordlist)..shuffle(_random);
    return pool.take(wordCount).toList();
  }

  /// Trims, lowercases and collapses whitespace so free-text entry ("
  /// Rose  Tiger MAPLE ") matches what was generated/hashed.
  static List<String> normalize(String raw) => raw
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
}
