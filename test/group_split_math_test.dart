import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/group_split_math.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/tables.dart' show GroupSplitMethod;

void main() {
  group('computeGroupShares — equal', () {
    test('divides evenly when it divides evenly', () {
      final shares = computeGroupShares(
        amount: Money.fromRupees(300),
        splitMethod: GroupSplitMethod.equal,
        participantIds: [null, 1, 2],
      );
      expect(shares[null], Money.fromRupees(100));
      expect(shares[1], Money.fromRupees(100));
      expect(shares[2], Money.fromRupees(100));
    });

    test('a non-divisible total sums exactly, remainder goes to the first '
        'participants in order', () {
      final shares = computeGroupShares(
        amount: Money.fromRupees(100),
        splitMethod: GroupSplitMethod.equal,
        participantIds: [null, 1, 2],
      );
      // 10000 paise / 3 = 3333 base, remainder 1 -> first participant (null).
      expect(shares[null], Money.fromPaise(3334));
      expect(shares[1], Money.fromPaise(3333));
      expect(shares[2], Money.fromPaise(3333));
      final sum = shares.values.fold(const Money.zero(), (a, b) => a + b);
      expect(sum, Money.fromRupees(100));
    });

    test('remainder distribution follows participant order, not id order', () {
      final shares = computeGroupShares(
        amount: Money.fromPaise(101),
        splitMethod: GroupSplitMethod.equal,
        participantIds: [2, 1], // 2 listed first this time
      );
      expect(shares[2], Money.fromPaise(51));
      expect(shares[1], Money.fromPaise(50));
    });

    test('a single participant gets the whole amount', () {
      final shares = computeGroupShares(
        amount: Money.fromRupees(42),
        splitMethod: GroupSplitMethod.equal,
        participantIds: [null],
      );
      expect(shares[null], Money.fromRupees(42));
    });

    test('rejects an empty participant list', () {
      expect(
        () => computeGroupShares(
          amount: Money.fromRupees(10),
          splitMethod: GroupSplitMethod.equal,
          participantIds: [],
        ),
        throwsArgumentError,
      );
    });
  });

  group('computeGroupShares — percentage', () {
    test('splits by basis points and sums exactly', () {
      final shares = computeGroupShares(
        amount: Money.fromRupees(100),
        splitMethod: GroupSplitMethod.percentage,
        participantIds: [null, 1, 2],
        percentBasisPoints: {null: 3334, 1: 3333, 2: 3333},
      );
      final sum = shares.values.fold(const Money.zero(), (a, b) => a + b);
      expect(sum, Money.fromRupees(100));
    });

    test('uneven percentages (60/40) sum exactly', () {
      final shares = computeGroupShares(
        amount: Money.fromRupees(250),
        splitMethod: GroupSplitMethod.percentage,
        participantIds: [null, 1],
        percentBasisPoints: {null: 6000, 1: 4000},
      );
      expect(shares[null], Money.fromRupees(150));
      expect(shares[1], Money.fromRupees(100));
    });

    test('rejects percentages summing to 90%', () {
      expect(
        () => computeGroupShares(
          amount: Money.fromRupees(100),
          splitMethod: GroupSplitMethod.percentage,
          participantIds: [null, 1],
          percentBasisPoints: {null: 5000, 1: 4000},
        ),
        throwsArgumentError,
      );
    });

    test('rejects percentages summing to 110%', () {
      expect(
        () => computeGroupShares(
          amount: Money.fromRupees(100),
          splitMethod: GroupSplitMethod.percentage,
          participantIds: [null, 1],
          percentBasisPoints: {null: 6000, 1: 5000},
        ),
        throwsArgumentError,
      );
    });

    test('accepts a small display-rounding slack (99.99%)', () {
      final shares = computeGroupShares(
        amount: Money.fromRupees(100),
        splitMethod: GroupSplitMethod.percentage,
        participantIds: [null, 1, 2],
        percentBasisPoints: {null: 3333, 1: 3333, 2: 3333}, // 99.99%
      );
      final sum = shares.values.fold(const Money.zero(), (a, b) => a + b);
      expect(sum, Money.fromRupees(100));
    });

    test('requires percentBasisPoints', () {
      expect(
        () => computeGroupShares(
          amount: Money.fromRupees(100),
          splitMethod: GroupSplitMethod.percentage,
          participantIds: [null, 1],
        ),
        throwsArgumentError,
      );
    });
  });

  group('computeGroupShares — manual', () {
    test('accepts an exact-sum split unchanged', () {
      final shares = computeGroupShares(
        amount: Money.fromRupees(100),
        splitMethod: GroupSplitMethod.manual,
        participantIds: [null, 1],
        manualAmounts: {null: Money.fromRupees(70), 1: Money.fromRupees(30)},
      );
      expect(shares[null], Money.fromRupees(70));
      expect(shares[1], Money.fromRupees(30));
    });

    test('rejects a split that is one paisa short', () {
      expect(
        () => computeGroupShares(
          amount: Money.fromRupees(100),
          splitMethod: GroupSplitMethod.manual,
          participantIds: [null, 1],
          manualAmounts: {
            null: Money.fromRupees(70),
            1: Money.fromPaise(2999),
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects a split that is one paisa over', () {
      expect(
        () => computeGroupShares(
          amount: Money.fromRupees(100),
          splitMethod: GroupSplitMethod.manual,
          participantIds: [null, 1],
          manualAmounts: {
            null: Money.fromRupees(70),
            1: Money.fromPaise(3001),
          },
        ),
        throwsArgumentError,
      );
    });

    test('requires manualAmounts', () {
      expect(
        () => computeGroupShares(
          amount: Money.fromRupees(100),
          splitMethod: GroupSplitMethod.manual,
          participantIds: [null, 1],
        ),
        throwsArgumentError,
      );
    });
  });
}
