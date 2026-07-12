import 'package:flutter/material.dart';

/// Icons are persisted as **stable string keys**, never raw codepoints.
///
/// Storing `IconData(codePoint)` built at runtime defeats Flutter's icon
/// tree-shaking and fails `flutter build --release`. A const lookup keeps the
/// icons const and the DB rows portable.
class AppIcons {
  const AppIcons._();

  static const _map = <String, IconData>{
    // accounts
    'cash': Icons.payments_outlined,
    'bank': Icons.account_balance_outlined,
    'card': Icons.credit_card_outlined,
    'wallet': Icons.account_balance_wallet_outlined,
    'savings': Icons.savings_outlined,

    // income
    'salary': Icons.work_outline_rounded,
    'profit': Icons.trending_up_rounded,
    'gift': Icons.card_giftcard_rounded,
    'interest': Icons.percent_rounded,
    'refund': Icons.undo_rounded,

    // expense
    'rent': Icons.home_outlined,
    'food': Icons.restaurant_outlined,
    'groceries': Icons.local_grocery_store_outlined,
    'transport': Icons.directions_bus_outlined,
    'bills': Icons.receipt_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'health': Icons.favorite_outline_rounded,
    'entertainment': Icons.movie_outlined,
    'emi': Icons.account_balance_wallet_outlined,
    'education': Icons.school_outlined,
    'travel': Icons.flight_outlined,

    // misc
    'transfer': Icons.swap_horiz_rounded,
    'person': Icons.person_outline_rounded,
    'other': Icons.more_horiz_rounded,
  };

  static const fallback = Icons.circle_outlined;

  static IconData resolve(String key) => _map[key] ?? fallback;

  static List<String> get allKeys => _map.keys.toList(growable: false);
}
