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
    'pay_later': Icons.shopping_cart_checkout_outlined,
    'prepaid_balance': Icons.credit_score_outlined,

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

    // food & drink
    'coffee': Icons.coffee_outlined,
    'cafe': Icons.local_cafe_outlined,
    'fastfood': Icons.fastfood_outlined,
    'breakfast': Icons.breakfast_dining_outlined,
    'lunch': Icons.lunch_dining_outlined,
    'dinner': Icons.dinner_dining_outlined,
    'bakery': Icons.bakery_dining_outlined,
    'icecream': Icons.icecream_outlined,
    'pizza': Icons.local_pizza_outlined,
    'ramen': Icons.ramen_dining_outlined,
    'bar': Icons.local_bar_outlined,
    'cake': Icons.cake_outlined,
    'kitchen': Icons.kitchen_outlined,

    // shopping
    'mall': Icons.local_mall_outlined,
    'store': Icons.storefront_outlined,
    'clothing': Icons.checkroom_outlined,
    'jewelry': Icons.diamond_outlined,

    // transport
    'car': Icons.directions_car_outlined,
    'taxi': Icons.local_taxi_outlined,
    'fuel': Icons.local_gas_station_outlined,
    'train': Icons.train_outlined,
    'subway': Icons.subway_outlined,
    'bike': Icons.directions_bike_outlined,
    'scooter': Icons.two_wheeler_outlined,
    'parking': Icons.local_parking_outlined,
    'car_repair': Icons.car_repair_outlined,

    // home & utilities
    'house': Icons.house_outlined,
    'apartment': Icons.apartment_outlined,
    'electricity': Icons.bolt_outlined,
    'water': Icons.water_drop_outlined,
    'wifi': Icons.wifi_outlined,
    'gas': Icons.local_fire_department_outlined,
    'plumbing': Icons.plumbing_outlined,
    'repair': Icons.build_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'laundry': Icons.local_laundry_service_outlined,
    'furniture': Icons.chair_outlined,

    // health & fitness
    'doctor': Icons.medical_services_outlined,
    'pharmacy': Icons.local_pharmacy_outlined,
    'vaccine': Icons.vaccines_outlined,
    'fitness': Icons.fitness_center_outlined,
    'spa': Icons.spa_outlined,
    'therapy': Icons.psychology_outlined,

    // entertainment & leisure
    'gaming': Icons.sports_esports_outlined,
    'music': Icons.music_note_outlined,
    'theater': Icons.theater_comedy_outlined,
    'festival': Icons.festival_outlined,
    'park': Icons.park_outlined,
    'beach': Icons.beach_access_outlined,
    'hiking': Icons.hiking_outlined,
    'soccer': Icons.sports_soccer_outlined,
    'basketball': Icons.sports_basketball_outlined,
    'pool': Icons.pool_outlined,
    'streaming': Icons.live_tv_outlined,
    'reading': Icons.menu_book_outlined,

    // work & tech
    'laptop': Icons.laptop_mac_outlined,
    'computer': Icons.computer_outlined,
    'phone': Icons.phone_iphone_outlined,
    'tv': Icons.tv_outlined,
    'headphones': Icons.headphones_outlined,
    'print': Icons.print_outlined,
    'briefcase': Icons.business_center_outlined,

    // travel
    'hotel': Icons.hotel_outlined,
    'luggage': Icons.luggage_outlined,
    'map': Icons.map_outlined,

    // people & family
    'baby': Icons.child_care_outlined,
    'family': Icons.family_restroom_outlined,
    'pets': Icons.pets_outlined,
    'elderly': Icons.elderly_outlined,
    'donation': Icons.volunteer_activism_outlined,

    // finance & misc
    'invoice': Icons.receipt_long_outlined,
    'loyalty': Icons.loyalty_outlined,
    'insurance': Icons.security_outlined,
    'tax': Icons.request_quote_outlined,

    // misc
    'transfer': Icons.swap_horiz_rounded,
    'person': Icons.person_outline_rounded,
    'bar_chart': Icons.bar_chart_rounded,
    'currency_exchange': Icons.currency_exchange_rounded,
    'other': Icons.more_horiz_rounded,
  };

  static const fallback = Icons.circle_outlined;

  static IconData resolve(String key) => _map[key] ?? fallback;

  static List<String> get allKeys => _map.keys.toList(growable: false);
}
