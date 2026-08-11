import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/features/add_transaction/amount_buffer.dart';

/// GitHub #45: opening an existing transaction for edit prefilled the
/// keypad buffer with its amount (e.g. "15.44"), which already has two
/// decimal digits — the old inline guard in `_onKey` then rejected every
/// digit tap, since appending always lands after the decimal point once two
/// digits are already there. Only backspace worked. `freshEntry` is what
/// fixes it: the very first tap after loading a prefilled value clears the
/// buffer instead of trying to extend it.
void main() {
  group('AmountBuffer.applyKey — composing from scratch', () {
    test('digits accumulate left to right', () {
      var b = '';
      for (final k in ['1', '5']) {
        b = AmountBuffer.applyKey(b, k);
      }
      expect(b, '15');
    });

    test('a lone leading zero is replaced, not extended', () {
      expect(AmountBuffer.applyKey('0', '7'), '7');
    });

    test('a dot starts the fraction, defaulting the integer part to 0', () {
      expect(AmountBuffer.applyKey('', '.'), '0.');
    });

    test('a second dot is ignored', () {
      expect(AmountBuffer.applyKey('12.5', '.'), '12.5');
    });

    test('a third decimal digit is rejected', () {
      expect(AmountBuffer.applyKey('12.34', '5'), '12.34');
    });

    test('caps at 12 significant digits', () {
      final twelve = '1' * 12;
      expect(AmountBuffer.applyKey(twelve, '9'), twelve);
    });
  });

  group('AmountBuffer.applyKey — freshEntry (GitHub #45)', () {
    test('the first tap after loading a prefilled value replaces it', () {
      expect(
        AmountBuffer.applyKey('15.44', '7', freshEntry: true),
        '7',
        reason: 'before the fix, this tap was silently swallowed',
      );
    });

    test('a dot as the first fresh tap starts a clean fraction', () {
      expect(AmountBuffer.applyKey('15.44', '.', freshEntry: true), '0.');
    });

    test('freshEntry only clears on that one call — callers must not '
        'repeat it', () {
      var b = AmountBuffer.applyKey('15.44', '7', freshEntry: true);
      b = AmountBuffer.applyKey(b, '9'); // freshEntry: false, the default
      expect(b, '79');
    });
  });

  group('AmountBuffer.applyBackspace', () {
    test('removes the last character', () {
      expect(AmountBuffer.applyBackspace('15.44'), '15.4');
    });

    test('an empty buffer stays empty', () {
      expect(AmountBuffer.applyBackspace(''), '');
    });

    test('backspacing a prefilled value then typing extends what is left', () {
      final afterBackspace = AmountBuffer.applyBackspace('15.44');
      expect(afterBackspace, '15.4');
      // Only the very first interaction after loading is "fresh" — a digit
      // right after a backspace must extend, not wipe, what's left.
      expect(AmountBuffer.applyKey(afterBackspace, '9'), '15.49');
    });
  });
}
