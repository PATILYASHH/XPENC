import 'money.dart';
import '../data/tables.dart' show GroupSplitMethod;

/// Splits [amount] across [participantIds] (`null` = "me") for
/// [splitMethod], paisa-exact — the returned shares always sum to exactly
/// [amount], never a paisa off either way.
///
/// The *only* place this math is implemented — `AppDatabase.addGroupExpense`
/// and the Add Group Expense screen's live preview both call this, so what
/// a user sees while entering a split is always exactly what gets saved.
///
/// [participantIds]' order decides who gets a rounding remainder paisa
/// first (see [_distributeRemainder]) — pass a stable order (e.g.
/// `GroupMembers.id` order) so which participant gets the extra paisa is
/// deterministic and explainable, not arbitrary.
Map<int?, Money> computeGroupShares({
  required Money amount,
  required GroupSplitMethod splitMethod,
  required List<int?> participantIds,
  Map<int?, int>? percentBasisPoints,
  Map<int?, Money>? manualAmounts,
}) {
  if (participantIds.isEmpty) {
    throw ArgumentError('Need at least one participant.');
  }

  switch (splitMethod) {
    case GroupSplitMethod.equal:
      final base = amount.paise ~/ participantIds.length;
      return _distributeRemainder(amount, participantIds, (_) => base);

    case GroupSplitMethod.percentage:
      if (percentBasisPoints == null) {
        throw ArgumentError('Percentages are required for a percentage split.');
      }
      final totalBp = percentBasisPoints.values.fold(0, (a, b) => a + b);
      // ±0.5% (50 basis points) of slack for display rounding — a manual
      // amount split has no such tolerance (exact integer paise there).
      if ((totalBp - 10000).abs() > 50) {
        throw ArgumentError('Percentages must add up to 100%.');
      }
      return _distributeRemainder(
        amount,
        participantIds,
        (id) => (amount.paise * (percentBasisPoints[id] ?? 0)) ~/ 10000,
      );

    case GroupSplitMethod.manual:
      if (manualAmounts == null) {
        throw ArgumentError('Amounts are required for a manual split.');
      }
      final sum = manualAmounts.values.fold(
        const Money.zero(),
        (a, b) => a + b,
      );
      if (sum != amount) {
        throw ArgumentError('Amounts must add up to the total exactly.');
      }
      return Map.of(manualAmounts);
  }
}

/// Assigns each participant `baseFor(id)` paise, then hands out whatever's
/// left of [amount] one paisa at a time, in [participantIds] order — so the
/// result always sums to exactly [amount].
Map<int?, Money> _distributeRemainder(
  Money amount,
  List<int?> participantIds,
  int Function(int? id) baseFor,
) {
  final result = <int?, Money>{};
  var used = 0;
  for (final id in participantIds) {
    final base = baseFor(id);
    result[id] = Money.fromPaise(base);
    used += base;
  }
  var remainder = amount.paise - used;
  for (final id in participantIds) {
    if (remainder <= 0) break;
    result[id] = result[id]! + const Money(1);
    remainder--;
  }
  return result;
}
