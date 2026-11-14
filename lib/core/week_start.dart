import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'l10n/l10n.dart';

import '../data/tables.dart';

/// Settings → General → Calendar → Week starts on (GitHub #166): which day
/// leads every week the app draws — the Calendar tab and every date picker.
extension WeekStartX on WeekStart {
  /// [MaterialLocalizations.firstDayOfWeekIndex]: 0 is Sunday, 1 Monday.
  int get materialIndex => this == WeekStart.sunday ? 0 : 1;

  /// One-letter weekday labels, in this week's order.
  List<String> get initials => this == WeekStart.sunday
      ? const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
      : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// How many blank cells come before [firstOfMonth] in a 7-wide month grid.
  int leadingBlanks(DateTime firstOfMonth) => this == WeekStart.sunday
      ? firstOfMonth.weekday % 7
      : firstOfMonth.weekday - 1;
}

/// Flutter's own Material strings — the date picker's OK and Cancel, its
/// month and weekday names, Back tooltips — in the interface language
/// (GitHub #191), with the week starting where the person chose (GitHub
/// #166). Flutter's per-language tables come with `flutter_localizations`,
/// which pins an `intl` the app can't share across its CI and local SDKs;
/// these few strings go through `tr` like the rest of the app, and dates
/// through `intl`, whose own locale data needs nothing extra.
class WeekStartMaterialLocalizations extends DefaultMaterialLocalizations {
  const WeekStartMaterialLocalizations(
    this.firstDayOfWeekIndex, {
    this.language = 'en',
  });

  @override
  final int firstDayOfWeekIndex;

  /// The interface language these strings and dates are in.
  final String language;

  bool get _english => language == 'en';

  @override
  String formatMonthYear(DateTime date) => _english
      ? super.formatMonthYear(date)
      : DateFormat.yMMMM(language).format(date);

  @override
  String formatMediumDate(DateTime date) => _english
      ? super.formatMediumDate(date)
      : DateFormat.MMMEd(language).format(date);

  @override
  String formatFullDate(DateTime date) => _english
      ? super.formatFullDate(date)
      : DateFormat.yMMMMEEEEd(language).format(date);

  @override
  String formatShortMonthDay(DateTime date) => _english
      ? super.formatShortMonthDay(date)
      : DateFormat.MMMd(language).format(date);

  @override
  List<String> get narrowWeekdays => _english
      ? super.narrowWeekdays
      : DateFormat.EEEEE(language).dateSymbols.STANDALONENARROWWEEKDAYS;

  @override
  String get okButtonLabel => tr('OK');
  @override
  String get cancelButtonLabel => tr('Cancel');
  @override
  String get closeButtonLabel => tr('Close');
  @override
  String get continueButtonLabel => tr('Continue');
  @override
  String get saveButtonLabel => tr('Save');
  @override
  String get copyButtonLabel => tr('Copy');
  @override
  String get cutButtonLabel => tr('Cut');
  @override
  String get pasteButtonLabel => tr('Paste');
  @override
  String get selectAllButtonLabel => tr('Select all');
  @override
  String get backButtonTooltip => tr('Back');
  @override
  String get closeButtonTooltip => tr('Close');
  @override
  String get deleteButtonTooltip => tr('Delete');
  @override
  String get moreButtonTooltip => tr('More');
  @override
  String get showMenuTooltip => tr('Show menu');
  @override
  String get searchFieldLabel => tr('Search');
  @override
  String get nextMonthTooltip => tr('Next month');
  @override
  String get previousMonthTooltip => tr('Previous month');
  @override
  String get datePickerHelpText => tr('Select date');
  @override
  String get dateRangePickerHelpText => tr('Select range');
  @override
  String get dateInputLabel => tr('Enter date');
  @override
  String get calendarModeButtonLabel => tr('Switch to calendar');
  @override
  String get inputDateModeButtonLabel => tr('Switch to input');
  @override
  String get invalidDateFormatLabel => tr('Invalid format.');
  @override
  String get dateOutOfRangeLabel => tr('Out of range.');
  @override
  String get dateRangeStartLabel => tr('Start date');
  @override
  String get dateRangeEndLabel => tr('End date');
  @override
  String get selectYearSemanticsLabel => tr('Select year');
  @override
  String get timePickerDialHelpText => tr('Select time');
  @override
  String get timePickerInputHelpText => tr('Enter time');
  @override
  String get timePickerHourLabel => tr('Hour');
  @override
  String get timePickerMinuteLabel => tr('Minute');
  @override
  String get inputTimeModeButtonLabel => tr('Switch to text input mode');
  @override
  String get dialModeButtonLabel => tr('Switch to dial picker mode');
  @override
  String get modalBarrierDismissLabel => tr('Dismiss');
}

/// Hands [WeekStartMaterialLocalizations] to `MaterialApp`, ahead of the
/// default — and reloads when the week start or the language changes.
class WeekStartLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const WeekStartLocalizationsDelegate(this.weekStart, {this.language = 'en'});

  final WeekStart weekStart;
  final String language;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(
    WeekStartMaterialLocalizations(
      weekStart.materialIndex,
      language: language,
    ),
  );

  @override
  bool shouldReload(WeekStartLocalizationsDelegate old) =>
      old.weekStart != weekStart || old.language != language;
}
