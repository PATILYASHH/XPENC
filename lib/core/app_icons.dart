import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// The sections the Exo icon library is browsed by in the picker.
enum ExoIconSection {
  money,
  income,
  food,
  shopping,
  transport,
  home,
  health,
  leisure,
  work,
  travel,
  people,
  finance,
  nature,
  symbols,
}

/// The icon libraries the picker offers: Exo's own (Material line icons,
/// in sections), an iOS-style set, and brand logos (subscriptions, apps,
/// cards, wallets).
enum IconLibrary { exo, ios, brands }

/// Exo icons — every icon a category, account, goal or transaction can wear.
///
/// Icons are persisted as **stable string keys**, never raw codepoints.
/// Storing `IconData(codePoint)` built at runtime defeats Flutter's icon
/// tree-shaking and fails `flutter build --release`. A const lookup keeps the
/// icons const and the DB rows portable.
///
/// Three libraries share the one key space: a plain key (`food`) is an Exo
/// icon — every key ever saved before the other libraries existed — `ios.…`
/// an iOS-style one and `brand.…` a brand logo. A key this build doesn't
/// know (a newer backup, a removed icon) resolves to [fallback].
class AppIcons {
  const AppIcons._();

  static const _money = <String, IconData>{
    'cash': Icons.payments_outlined,
    'bank': Icons.account_balance_outlined,
    'card': Icons.credit_card_outlined,
    'wallet': Icons.account_balance_wallet_outlined,
    'savings': Icons.savings_outlined,
    'pay_later': Icons.shopping_cart_checkout_outlined,
    'prepaid_balance': Icons.credit_score_outlined,
    'atm': Icons.local_atm_outlined,
    'coins': Icons.toll_outlined,
    'rupee': Icons.currency_rupee_rounded,
    'dollar': Icons.attach_money_rounded,
    'euro': Icons.euro_rounded,
    'pound': Icons.currency_pound_rounded,
    'yen': Icons.currency_yen_rounded,
    'bitcoin': Icons.currency_bitcoin_rounded,
    'qr_pay': Icons.qr_code_2_rounded,
    'contactless': Icons.contactless_outlined,
    'point_of_sale': Icons.point_of_sale_outlined,
    'currency_exchange': Icons.currency_exchange_rounded,
    'transfer': Icons.swap_horiz_rounded,
  };

  static const _income = <String, IconData>{
    'salary': Icons.work_outline_rounded,
    'profit': Icons.trending_up_rounded,
    'gift': Icons.card_giftcard_rounded,
    'interest': Icons.percent_rounded,
    'refund': Icons.undo_rounded,
    'bonus': Icons.redeem_outlined,
    'freelance': Icons.laptop_chromebook_outlined,
    'rental_income': Icons.real_estate_agent_outlined,
    'stocks': Icons.show_chart_rounded,
    'dividend': Icons.pie_chart_outline_rounded,
    'cashback': Icons.price_check_rounded,
    'pension': Icons.elderly_woman_outlined,
    'business': Icons.business_outlined,
  };

  static const _food = <String, IconData>{
    'food': Icons.restaurant_outlined,
    'groceries': Icons.local_grocery_store_outlined,
    'coffee': Icons.coffee_outlined,
    'cafe': Icons.local_cafe_outlined,
    'tea': Icons.emoji_food_beverage_outlined,
    'fastfood': Icons.fastfood_outlined,
    'breakfast': Icons.breakfast_dining_outlined,
    'brunch': Icons.brunch_dining_outlined,
    'lunch': Icons.lunch_dining_outlined,
    'dinner': Icons.dinner_dining_outlined,
    'rice_bowl': Icons.rice_bowl_outlined,
    'set_meal': Icons.set_meal_outlined,
    'soup': Icons.soup_kitchen_outlined,
    'takeout': Icons.takeout_dining_outlined,
    'delivery': Icons.delivery_dining_outlined,
    'bakery': Icons.bakery_dining_outlined,
    'cookie': Icons.cookie_outlined,
    'icecream': Icons.icecream_outlined,
    'pizza': Icons.local_pizza_outlined,
    'ramen': Icons.ramen_dining_outlined,
    'egg': Icons.egg_outlined,
    'bar': Icons.local_bar_outlined,
    'beer': Icons.sports_bar_outlined,
    'wine': Icons.wine_bar_outlined,
    'liquor': Icons.liquor_outlined,
    'cake': Icons.cake_outlined,
    'kitchen': Icons.kitchen_outlined,
    'menu': Icons.restaurant_menu_outlined,
  };

  static const _shopping = <String, IconData>{
    'shopping': Icons.shopping_bag_outlined,
    'cart': Icons.shopping_cart_outlined,
    'basket': Icons.shopping_basket_outlined,
    'mall': Icons.local_mall_outlined,
    'store': Icons.storefront_outlined,
    'clothing': Icons.checkroom_outlined,
    'jewelry': Icons.diamond_outlined,
    'watch': Icons.watch_outlined,
    'beauty': Icons.face_retouching_natural_outlined,
    'cosmetics': Icons.brush_outlined,
    'toys': Icons.toys_outlined,
    'books': Icons.auto_stories_outlined,
    'electronics': Icons.devices_other_outlined,
    'florist': Icons.local_florist_outlined,
    'hardware': Icons.hardware_outlined,
    'parcel': Icons.inventory_2_outlined,
    'sale': Icons.sell_outlined,
    'offer': Icons.local_offer_outlined,
  };

  static const _transport = <String, IconData>{
    'transport': Icons.directions_bus_outlined,
    'car': Icons.directions_car_outlined,
    'electric_car': Icons.electric_car_outlined,
    'taxi': Icons.local_taxi_outlined,
    'car_rental': Icons.car_rental_outlined,
    'fuel': Icons.local_gas_station_outlined,
    'ev_charging': Icons.ev_station_outlined,
    'train': Icons.train_outlined,
    'subway': Icons.subway_outlined,
    'tram': Icons.tram_outlined,
    'bike': Icons.directions_bike_outlined,
    'scooter': Icons.two_wheeler_outlined,
    'motorcycle': Icons.motorcycle_outlined,
    'electric_scooter': Icons.electric_scooter_outlined,
    'walk': Icons.directions_walk_outlined,
    'boat': Icons.directions_boat_outlined,
    'shuttle': Icons.airport_shuttle_outlined,
    'commute': Icons.commute_outlined,
    'shipping': Icons.local_shipping_outlined,
    'parking': Icons.local_parking_outlined,
    'car_repair': Icons.car_repair_outlined,
    'car_wash': Icons.local_car_wash_outlined,
    'tyre': Icons.tire_repair_outlined,
  };

  static const _home = <String, IconData>{
    'rent': Icons.home_outlined,
    'house': Icons.house_outlined,
    'apartment': Icons.apartment_outlined,
    'electricity': Icons.bolt_outlined,
    'lightbulb': Icons.lightbulb_outline_rounded,
    'water': Icons.water_drop_outlined,
    'wifi': Icons.wifi_outlined,
    'broadband': Icons.router_outlined,
    'mobile_recharge': Icons.phone_android_outlined,
    'dth': Icons.satellite_alt_outlined,
    'gas': Icons.local_fire_department_outlined,
    'air_conditioner': Icons.ac_unit_outlined,
    'plumbing': Icons.plumbing_outlined,
    'repair': Icons.build_outlined,
    'handyman': Icons.handyman_outlined,
    'paint': Icons.format_paint_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'laundry': Icons.local_laundry_service_outlined,
    'furniture': Icons.chair_outlined,
    'bed': Icons.bed_outlined,
    'garden': Icons.yard_outlined,
    'pest_control': Icons.pest_control_outlined,
    'key': Icons.key_outlined,
    'garbage': Icons.delete_outline_rounded,
  };

  static const _health = <String, IconData>{
    'health': Icons.favorite_outline_rounded,
    'doctor': Icons.medical_services_outlined,
    'hospital': Icons.local_hospital_outlined,
    'pharmacy': Icons.local_pharmacy_outlined,
    'medicine': Icons.medication_outlined,
    'vaccine': Icons.vaccines_outlined,
    'heart_check': Icons.monitor_heart_outlined,
    'blood_test': Icons.bloodtype_outlined,
    'healing': Icons.healing_outlined,
    'eye_care': Icons.visibility_outlined,
    'therapy': Icons.psychology_outlined,
    'fitness': Icons.fitness_center_outlined,
    'running': Icons.directions_run_outlined,
    'yoga': Icons.self_improvement_outlined,
    'spa': Icons.spa_outlined,
    'haircut': Icons.content_cut_outlined,
  };

  static const _leisure = <String, IconData>{
    'entertainment': Icons.movie_outlined,
    'tickets': Icons.confirmation_number_outlined,
    'streaming': Icons.live_tv_outlined,
    'subscription': Icons.subscriptions_outlined,
    'music': Icons.music_note_outlined,
    'piano': Icons.piano_outlined,
    'podcast': Icons.podcasts_outlined,
    'gaming': Icons.sports_esports_outlined,
    'video_game': Icons.videogame_asset_outlined,
    'theater': Icons.theater_comedy_outlined,
    'festival': Icons.festival_outlined,
    'celebration': Icons.celebration_outlined,
    'nightlife': Icons.nightlife_outlined,
    'casino': Icons.casino_outlined,
    'attractions': Icons.attractions_outlined,
    'stadium': Icons.stadium_outlined,
    'camera': Icons.photo_camera_outlined,
    'art': Icons.palette_outlined,
    'reading': Icons.menu_book_outlined,
    'park': Icons.park_outlined,
    'beach': Icons.beach_access_outlined,
    'hiking': Icons.hiking_outlined,
    'cricket': Icons.sports_cricket_outlined,
    'soccer': Icons.sports_soccer_outlined,
    'basketball': Icons.sports_basketball_outlined,
    'tennis': Icons.sports_tennis_outlined,
    'golf': Icons.golf_course_outlined,
    'pool': Icons.pool_outlined,
    'surfing': Icons.surfing_outlined,
    'skiing': Icons.downhill_skiing_outlined,
    'kayaking': Icons.kayaking_outlined,
  };

  static const _work = <String, IconData>{
    'laptop': Icons.laptop_mac_outlined,
    'computer': Icons.computer_outlined,
    'phone': Icons.phone_iphone_outlined,
    'tablet': Icons.tablet_mac_outlined,
    'tv': Icons.tv_outlined,
    'headphones': Icons.headphones_outlined,
    'keyboard': Icons.keyboard_outlined,
    'mouse': Icons.mouse_outlined,
    'storage': Icons.sd_storage_outlined,
    'cloud': Icons.cloud_outlined,
    'software': Icons.code_rounded,
    'apps': Icons.apps_rounded,
    'print': Icons.print_outlined,
    'briefcase': Icons.business_center_outlined,
    'office': Icons.corporate_fare_outlined,
    'meeting': Icons.groups_outlined,
    'email': Icons.email_outlined,
    'stationery': Icons.edit_note_outlined,
    'education': Icons.school_outlined,
  };

  static const _travel = <String, IconData>{
    'travel': Icons.flight_outlined,
    'flight_takeoff': Icons.flight_takeoff_outlined,
    'hotel': Icons.hotel_outlined,
    'holiday_home': Icons.holiday_village_outlined,
    'luggage': Icons.luggage_outlined,
    'map': Icons.map_outlined,
    'explore': Icons.explore_outlined,
    'tour': Icons.tour_outlined,
    'mountain': Icons.landscape_outlined,
    'world': Icons.public_outlined,
    'id_card': Icons.badge_outlined,
  };

  static const _people = <String, IconData>{
    'person': Icons.person_outline_rounded,
    'friends': Icons.people_outline_rounded,
    'family': Icons.family_restroom_outlined,
    'baby': Icons.child_care_outlined,
    'stroller': Icons.child_friendly_outlined,
    'elderly': Icons.elderly_outlined,
    'pets': Icons.pets_outlined,
    'partner': Icons.favorite_border_rounded,
    'donation': Icons.volunteer_activism_outlined,
    'temple': Icons.temple_hindu_outlined,
    'buddhist_temple': Icons.temple_buddhist_outlined,
    'mosque': Icons.mosque_outlined,
    'church': Icons.church_outlined,
    'synagogue': Icons.synagogue_outlined,
  };

  static const _finance = <String, IconData>{
    'bills': Icons.receipt_outlined,
    'invoice': Icons.receipt_long_outlined,
    'emi': Icons.account_balance_wallet_outlined,
    'loan': Icons.handshake_outlined,
    'tax': Icons.request_quote_outlined,
    'fees': Icons.price_change_outlined,
    'insurance': Icons.security_outlined,
    'policy': Icons.policy_outlined,
    'legal': Icons.balance_outlined,
    'fine': Icons.gavel_outlined,
    'investment': Icons.candlestick_chart_outlined,
    'loss': Icons.trending_down_rounded,
    'recurring': Icons.autorenew_rounded,
    'calculator': Icons.calculate_outlined,
    'loyalty': Icons.loyalty_outlined,
    'bar_chart': Icons.bar_chart_rounded,
  };

  static const _nature = <String, IconData>{
    'sun': Icons.wb_sunny_outlined,
    'moon': Icons.dark_mode_outlined,
    'umbrella': Icons.umbrella_outlined,
    'eco': Icons.eco_outlined,
    'recycle': Icons.recycling_rounded,
    'forest': Icons.forest_outlined,
    'grass': Icons.grass_rounded,
    'waves': Icons.waves_rounded,
  };

  static const _symbols = <String, IconData>{
    'star': Icons.star_outline_rounded,
    'heart': Icons.favorite_rounded,
    'flag': Icons.flag_outlined,
    'bookmark': Icons.bookmark_outline_rounded,
    'trophy': Icons.emoji_events_outlined,
    'rocket': Icons.rocket_launch_outlined,
    'sparkle': Icons.auto_awesome_outlined,
    'puzzle': Icons.extension_outlined,
    'label': Icons.label_outline_rounded,
    'calendar': Icons.calendar_month_outlined,
    'schedule': Icons.schedule_rounded,
    'alarm': Icons.alarm_rounded,
    'notification': Icons.notifications_none_rounded,
    'check': Icons.check_circle_outline_rounded,
    'warning': Icons.warning_amber_rounded,
    'info': Icons.info_outline_rounded,
    'lock': Icons.lock_outline_rounded,
    'other': Icons.more_horiz_rounded,
  };

  static const _sections = <ExoIconSection, Map<String, IconData>>{
    ExoIconSection.money: _money,
    ExoIconSection.income: _income,
    ExoIconSection.food: _food,
    ExoIconSection.shopping: _shopping,
    ExoIconSection.transport: _transport,
    ExoIconSection.home: _home,
    ExoIconSection.health: _health,
    ExoIconSection.leisure: _leisure,
    ExoIconSection.work: _work,
    ExoIconSection.travel: _travel,
    ExoIconSection.people: _people,
    ExoIconSection.finance: _finance,
    ExoIconSection.nature: _nature,
    ExoIconSection.symbols: _symbols,
  };

  // Spread into one const map: a key in two sections is a compile error.
  static const _exo = <String, IconData>{
    ..._money,
    ..._income,
    ..._food,
    ..._shopping,
    ..._transport,
    ..._home,
    ..._health,
    ..._leisure,
    ..._work,
    ..._travel,
    ..._people,
    ..._finance,
    ..._nature,
    ..._symbols,
  };

  static const _iosPrefix = 'ios.';
  static const _brandPrefix = 'brand.';

  static const _ios = <String, IconData>{
    'ios.cart': CupertinoIcons.cart,
    'ios.bag': CupertinoIcons.bag,
    'ios.creditcard': CupertinoIcons.creditcard,
    'ios.money': CupertinoIcons.money_dollar_circle,
    'ios.euro': CupertinoIcons.money_euro_circle,
    'ios.pound': CupertinoIcons.money_pound_circle,
    'ios.yen': CupertinoIcons.money_yen_circle,
    'ios.bitcoin': CupertinoIcons.bitcoin_circle,
    'ios.gift': CupertinoIcons.gift,
    'ios.tag': CupertinoIcons.tag,
    'ios.percent': CupertinoIcons.percent,
    'ios.chart_bar': CupertinoIcons.chart_bar,
    'ios.chart_pie': CupertinoIcons.chart_pie,
    'ios.graph': CupertinoIcons.graph_square,
    'ios.house': CupertinoIcons.house,
    'ios.building': CupertinoIcons.building_2_fill,
    'ios.bed': CupertinoIcons.bed_double,
    'ios.lightbulb': CupertinoIcons.lightbulb,
    'ios.bolt': CupertinoIcons.bolt,
    'ios.drop': CupertinoIcons.drop,
    'ios.flame': CupertinoIcons.flame,
    'ios.wifi': CupertinoIcons.wifi,
    'ios.phone': CupertinoIcons.phone,
    'ios.iphone': CupertinoIcons.device_phone_portrait,
    'ios.laptop': CupertinoIcons.device_laptop,
    'ios.desktop': CupertinoIcons.desktopcomputer,
    'ios.tv': CupertinoIcons.tv,
    'ios.headphones': CupertinoIcons.headphones,
    'ios.game': CupertinoIcons.game_controller,
    'ios.music': CupertinoIcons.music_note,
    'ios.film': CupertinoIcons.film,
    'ios.ticket': CupertinoIcons.ticket,
    'ios.book': CupertinoIcons.book,
    'ios.briefcase': CupertinoIcons.briefcase,
    'ios.hammer': CupertinoIcons.hammer,
    'ios.wrench': CupertinoIcons.wrench,
    'ios.scissors': CupertinoIcons.scissors,
    'ios.paintbrush': CupertinoIcons.paintbrush,
    'ios.car': CupertinoIcons.car_detailed,
    'ios.bus': CupertinoIcons.bus,
    'ios.tram': CupertinoIcons.tram_fill,
    'ios.airplane': CupertinoIcons.airplane,
    'ios.train': CupertinoIcons.train_style_one,
    'ios.heart': CupertinoIcons.heart,
    'ios.bandage': CupertinoIcons.bandage,
    'ios.capsule': CupertinoIcons.capsule,
    'ios.eyeglasses': CupertinoIcons.eyeglasses,
    'ios.person': CupertinoIcons.person,
    'ios.people': CupertinoIcons.person_2,
    'ios.group': CupertinoIcons.person_3,
    'ios.paw': CupertinoIcons.paw,
    'ios.star': CupertinoIcons.star,
    'ios.flag': CupertinoIcons.flag,
    'ios.bell': CupertinoIcons.bell,
    'ios.calendar': CupertinoIcons.calendar,
    'ios.clock': CupertinoIcons.clock,
    'ios.alarm': CupertinoIcons.alarm,
    'ios.hourglass': CupertinoIcons.hourglass,
    'ios.globe': CupertinoIcons.globe,
    'ios.map': CupertinoIcons.map,
    'ios.location': CupertinoIcons.location,
    'ios.compass': CupertinoIcons.compass,
    'ios.sun': CupertinoIcons.sun_max,
    'ios.moon': CupertinoIcons.moon,
    'ios.cloud': CupertinoIcons.cloud,
    'ios.rain': CupertinoIcons.cloud_rain,
    'ios.snow': CupertinoIcons.snow,
    'ios.tree': CupertinoIcons.tree,
    'ios.umbrella': CupertinoIcons.umbrella,
    'ios.camera': CupertinoIcons.camera,
    'ios.photo': CupertinoIcons.photo,
    'ios.mic': CupertinoIcons.mic,
    'ios.envelope': CupertinoIcons.envelope,
    'ios.chat': CupertinoIcons.chat_bubble,
    'ios.doc': CupertinoIcons.doc_text,
    'ios.folder': CupertinoIcons.folder,
    'ios.box': CupertinoIcons.cube_box,
    'ios.archive': CupertinoIcons.archivebox,
    'ios.shield': CupertinoIcons.shield,
    'ios.lock': CupertinoIcons.lock,
    'ios.sparkles': CupertinoIcons.sparkles,
    'ios.repeat': CupertinoIcons.arrow_2_circlepath,
    'ios.speedometer': CupertinoIcons.speedometer,
    'ios.thermometer': CupertinoIcons.thermometer,
    'ios.wand': CupertinoIcons.wand_stars,
  };

  static const _brands = <String, FaIconData>{
    'brand.youtube': FontAwesomeIcons.youtube,
    'brand.spotify': FontAwesomeIcons.spotify,
    'brand.amazon': FontAwesomeIcons.amazon,
    'brand.apple': FontAwesomeIcons.apple,
    'brand.google': FontAwesomeIcons.google,
    'brand.google_play': FontAwesomeIcons.googlePlay,
    'brand.app_store': FontAwesomeIcons.appStore,
    'brand.itunes': FontAwesomeIcons.itunes,
    'brand.audible': FontAwesomeIcons.audible,
    'brand.microsoft': FontAwesomeIcons.microsoft,
    'brand.windows': FontAwesomeIcons.windows,
    'brand.android': FontAwesomeIcons.android,
    'brand.linux': FontAwesomeIcons.linux,
    'brand.steam': FontAwesomeIcons.steam,
    'brand.playstation': FontAwesomeIcons.playstation,
    'brand.xbox': FontAwesomeIcons.xbox,
    'brand.battle_net': FontAwesomeIcons.battleNet,
    'brand.twitch': FontAwesomeIcons.twitch,
    'brand.uber': FontAwesomeIcons.uber,
    'brand.lyft': FontAwesomeIcons.lyft,
    'brand.airbnb': FontAwesomeIcons.airbnb,
    'brand.paypal': FontAwesomeIcons.paypal,
    'brand.google_pay': FontAwesomeIcons.googlePay,
    'brand.apple_pay': FontAwesomeIcons.applePay,
    'brand.amazon_pay': FontAwesomeIcons.amazonPay,
    'brand.alipay': FontAwesomeIcons.alipay,
    'brand.cash_app': FontAwesomeIcons.cashApp,
    'brand.venmo': FontAwesomeIcons.venmo,
    'brand.stripe': FontAwesomeIcons.stripe,
    'brand.visa': FontAwesomeIcons.ccVisa,
    'brand.mastercard': FontAwesomeIcons.ccMastercard,
    'brand.amex': FontAwesomeIcons.ccAmex,
    'brand.bitcoin': FontAwesomeIcons.bitcoin,
    'brand.ethereum': FontAwesomeIcons.ethereum,
    'brand.whatsapp': FontAwesomeIcons.whatsapp,
    'brand.telegram': FontAwesomeIcons.telegram,
    'brand.signal': FontAwesomeIcons.signalMessenger,
    'brand.instagram': FontAwesomeIcons.instagram,
    'brand.facebook': FontAwesomeIcons.facebook,
    'brand.x': FontAwesomeIcons.xTwitter,
    'brand.threads': FontAwesomeIcons.threads,
    'brand.linkedin': FontAwesomeIcons.linkedin,
    'brand.reddit': FontAwesomeIcons.reddit,
    'brand.discord': FontAwesomeIcons.discord,
    'brand.snapchat': FontAwesomeIcons.snapchat,
    'brand.pinterest': FontAwesomeIcons.pinterest,
    'brand.tiktok': FontAwesomeIcons.tiktok,
    'brand.skype': FontAwesomeIcons.skype,
    'brand.github': FontAwesomeIcons.github,
    'brand.gitlab': FontAwesomeIcons.gitlab,
    'brand.dropbox': FontAwesomeIcons.dropbox,
    'brand.google_drive': FontAwesomeIcons.googleDrive,
    'brand.slack': FontAwesomeIcons.slack,
    'brand.figma': FontAwesomeIcons.figma,
    'brand.openai': FontAwesomeIcons.openai,
    'brand.aws': FontAwesomeIcons.aws,
    'brand.cloudflare': FontAwesomeIcons.cloudflare,
    'brand.wordpress': FontAwesomeIcons.wordpress,
    'brand.shopify': FontAwesomeIcons.shopify,
    'brand.ebay': FontAwesomeIcons.ebay,
    'brand.etsy': FontAwesomeIcons.etsy,
    'brand.patreon': FontAwesomeIcons.patreon,
    'brand.medium': FontAwesomeIcons.medium,
    'brand.soundcloud': FontAwesomeIcons.soundcloud,
    'brand.deezer': FontAwesomeIcons.deezer,
    'brand.vimeo': FontAwesomeIcons.vimeo,
    'brand.imdb': FontAwesomeIcons.imdb,
    'brand.chrome': FontAwesomeIcons.chrome,
    'brand.firefox': FontAwesomeIcons.firefox,
  };

  static const fallback = Icons.circle_outlined;

  static IconData resolve(String key) =>
      _exo[key] ?? _ios[key] ?? _brands[key]?.data ?? fallback;

  /// Whether [key] names an icon this build has.
  static bool isKnown(String key) =>
      _exo.containsKey(key) ||
      _ios.containsKey(key) ||
      _brands.containsKey(key);

  /// Every key, Exo's first — `allKeys.first` (`cash`) is the default a new
  /// category starts with.
  static List<String> get allKeys => [
    ..._exo.keys,
    ..._ios.keys,
    ..._brands.keys,
  ];

  /// One library's keys, in browsing order.
  static List<String> keysOf(IconLibrary library) => switch (library) {
    IconLibrary.exo => _exo.keys.toList(growable: false),
    IconLibrary.ios => _ios.keys.toList(growable: false),
    IconLibrary.brands => _brands.keys.toList(growable: false),
  };

  /// The Exo library, section by section.
  static Iterable<(ExoIconSection, List<String>)> get exoSections =>
      _sections.entries.map((e) => (e.key, e.value.keys.toList()));

  /// Which library [key] belongs to.
  static IconLibrary libraryOf(String key) => key.startsWith(_iosPrefix)
      ? IconLibrary.ios
      : key.startsWith(_brandPrefix)
      ? IconLibrary.brands
      : IconLibrary.exo;

  /// The Exo section [key] sits in, or null outside the Exo library.
  static ExoIconSection? sectionOf(String key) {
    for (final e in _sections.entries) {
      if (e.value.containsKey(key)) return e.key;
    }
    return null;
  }

  /// "car_repair" → "Car repair", "brand.google_play" → "Google play" —
  /// the keys are already short, descriptive slugs, so a plain swap reads
  /// fine for search without a label table to keep in sync.
  static String labelOf(String key) {
    final dot = key.indexOf('.');
    final slug = (dot < 0 ? key : key.substring(dot + 1)).replaceAll('_', ' ');
    return slug.isEmpty ? key : slug[0].toUpperCase() + slug.substring(1);
  }

  /// A user's own emoji stored in an icon-key column: `emoji:<glyph>`. Only
  /// categories offer one (`showIconPickerSheet(allowEmoji: true)`). [resolve]
  /// maps it to [fallback] like any unknown key — draw a key that may be an
  /// emoji with `KeyIcon` / `IconWell.forKey`, which render the glyph itself.
  static const _emojiPrefix = 'emoji:';

  /// The emoji encoded in [key], or null when [key] is a plain icon key.
  static String? emojiOf(String? key) =>
      key != null &&
          key.startsWith(_emojiPrefix) &&
          key.length > _emojiPrefix.length
      ? key.substring(_emojiPrefix.length)
      : null;

  static String encodeEmoji(String emoji) => '$_emojiPrefix$emoji';
}
