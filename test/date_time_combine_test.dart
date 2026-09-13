import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/features/add_transaction/date_time_combine.dart';

/// GitHub #124: picking a new date reset a transaction's time to midnight,
/// since `showDatePicker` only ever returns a date-only (midnight)
/// `DateTime`. `combineDateAndTime` is the one place both the date picker
/// (new date, existing time) and the new time picker (existing date, new
/// time) go through, so picking one can never zero out the other.
void main() {
  group('combineDateAndTime', () {
    test('a new date keeps the existing time of day', () {
      final existing = DateTime(2026, 7, 8, 15, 44);
      final newDate = DateTime(2026, 7, 20); // what showDatePicker returns
      final result = combineDateAndTime(
        newDate,
        TimeOfDay.fromDateTime(existing),
      );
      expect(result, DateTime(2026, 7, 20, 15, 44));
    });

    test('a new time keeps the existing date', () {
      final existing = DateTime(2026, 7, 8, 0, 0);
      final result = combineDateAndTime(
        existing,
        const TimeOfDay(hour: 21, minute: 5),
      );
      expect(result, DateTime(2026, 7, 8, 21, 5));
    });

    test('midnight is a valid, distinguishable time of day', () {
      final result = combineDateAndTime(
        DateTime(2026, 7, 8, 13, 30),
        const TimeOfDay(hour: 0, minute: 0),
      );
      expect(result, DateTime(2026, 7, 8, 0, 0));
    });
  });
}
