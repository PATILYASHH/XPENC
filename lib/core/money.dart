import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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
class MoneyFormat {
  const MoneyFormat._();

  static final NumberFormat _withSymbol = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _bare = NumberFormat.decimalPatternDigits(
    locale: 'en_IN',
    decimalDigits: 2,
  );

  static final NumberFormat _compact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
  );

  /// `₹12,50,000.00`
  static String symbol(Money m) => _withSymbol.format(m.rupees);

  /// `12,50,000.00`
  static String bare(Money m) => _bare.format(m.rupees);

  /// `₹12.5L` — for tight spaces like chart labels.
  static String compact(Money m) => _compact.format(m.rupees);

  /// `+₹500.00` / `-₹500.00` — for signed ledger rows.
  static String signed(Money m) {
    final sign = m.isNegative ? '-' : '+';
    return '$sign${symbol(m.abs)}';
  }
}

/// Amounts must render with tabular figures so columns of numbers line up.
const kTabularFigures = <FontFeature>[FontFeature.tabularFigures()];
