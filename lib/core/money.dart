import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'currency.dart';

/// Money is stored as an **integer number of paise**. Never use `double` for
/// money — floating point silently corrupts totals.
///
/// `Money(1250)` == ₹12.50
@immutable
class Money implements Comparable<Money> {
  const Money(this.paise);

  const Money.zero() : paise = 0;

  /// Build from a rupee amount. Rounds to the nearest paisa.
  factory Money.fromRupees(num rupees) => Money((rupees * 100).round());

  /// Parse user input like `"1,250.50"`, `"₹1250"`, `"1250"`.
  /// Returns `null` when the text isn't a valid amount.
  static Money? tryParse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    final rupees = double.tryParse(cleaned);
    if (rupees == null) return null;
    return Money.fromRupees(rupees);
  }

  final int paise;

  double get rupees => paise / 100;

  bool get isZero => paise == 0;
  bool get isNegative => paise < 0;
  bool get isPositive => paise > 0;

  Money get abs => Money(paise.abs());

  Money operator +(Money other) => Money(paise + other.paise);
  Money operator -(Money other) => Money(paise - other.paise);
  Money operator -() => Money(-paise);
  Money operator *(int factor) => Money(paise * factor);

  bool operator <(Money other) => paise < other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => 'Money($paise paise)';
}

/// Single source of truth for rendering money. Do not format amounts anywhere
/// else — locale, symbol and decimal rules live here.
///
/// The active [currency] and whether to show its [showSymbol] are global and
/// change rarely (only from Settings). Call [configure] when they do; widgets
/// re-read the new formats on their next build. Defaults to [kDefaultCurrency]
/// with the symbol shown, so amounts render correctly before any configuration.
class MoneyFormat {
  const MoneyFormat._();

  static Currency _currency = kDefaultCurrency;
  static bool _showSymbol = true;

  static Currency get currency => _currency;
  static bool get showSymbol => _showSymbol;

  static NumberFormat _withSymbol = _buildWithSymbol(_currency);
  static NumberFormat _bare = _buildBare(_currency);
  static NumberFormat _compact = _buildCompact(_currency, _showSymbol);

  /// Point every formatter at [currency], honouring [showSymbol]. Cheap enough
  /// to call on each app build — it only rebuilds three `NumberFormat`s.
  static void configure({required Currency currency, required bool showSymbol}) {
    _currency = currency;
    _showSymbol = showSymbol;
    _withSymbol = _buildWithSymbol(currency);
    _bare = _buildBare(currency);
    _compact = _buildCompact(currency, showSymbol);
  }

  // Digit grouping follows the currency's home convention: the rupee groups in
  // lakhs (12,34,567), everyone else in thousands (1,234,567).
  static String _localeFor(Currency c) => c.code == 'INR' ? 'en_IN' : 'en_US';

  static NumberFormat _buildWithSymbol(Currency c) => NumberFormat.currency(
        locale: _localeFor(c),
        symbol: c.symbol,
        decimalDigits: c.decimalDigits,
      );

  static NumberFormat _buildBare(Currency c) =>
      NumberFormat.decimalPatternDigits(
        locale: _localeFor(c),
        decimalDigits: c.decimalDigits,
      );

  static NumberFormat _buildCompact(Currency c, bool showSymbol) =>
      NumberFormat.compactCurrency(
        locale: _localeFor(c),
        symbol: showSymbol ? c.symbol : '',
      );

  /// `₹12,50,000.00` — or the bare number when the symbol is hidden.
  static String symbol(Money m) =>
      _showSymbol ? _withSymbol.format(m.rupees) : _bare.format(m.rupees);

  /// `12,50,000.00` — never carries a symbol, whatever the setting.
  static String bare(Money m) => _bare.format(m.rupees);

  /// `₹12.5L` — for tight spaces like chart labels.
  static String compact(Money m) => _compact.format(m.rupees).trim();

  /// `+₹500.00` / `-₹500.00` — for signed ledger rows.
  static String signed(Money m) {
    final sign = m.isNegative ? '-' : '+';
    return '$sign${symbol(m.abs)}';
  }
}

/// Amounts must render with tabular figures so columns of numbers line up.
const kTabularFigures = <FontFeature>[FontFeature.tabularFigures()];
