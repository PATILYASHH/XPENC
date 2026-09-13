import 'package:flutter/material.dart' show TimeOfDay;

/// Combines a calendar date with a time-of-day into one `DateTime` — no
/// widget tree, so this is testable without pumping a screen.
///
/// GitHub #124: picking a new date on a transaction silently reset its time
/// to midnight, because `showDatePicker` only ever returns a date-only
/// `DateTime` (always midnight) and `_pickDate` assigned it directly. This
/// is the one place both `_pickDate` (new date, existing time) and the new
/// `_pickTime` (existing date, new time) go through, so picking one of the
/// two can never zero out the other.
DateTime combineDateAndTime(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);
