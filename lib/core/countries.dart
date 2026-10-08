import 'dart:ui' show Locale;

import 'currency.dart';

/// A country the first-run picker offers, and the currency it sets as the
/// parent currency. Only countries whose currency is in [kCurrencies] are
/// listed — the picker's "choose a currency instead" covers the rest.
class Country {
  const Country(
    this.code,
    this.name,
    this.currencyCode, {
    this.aliases = const [],
  });

  /// ISO 3166-1 alpha-2, e.g. `IN`, `US`, `DE`.
  final String code;

  /// Common English name, e.g. `India`.
  final String name;

  /// ISO 4217 code of the currency used day to day, e.g. `INR`, `EUR`.
  final String currencyCode;

  /// Other names people search by — `USA`, `Britain`, `Holland`.
  final List<String> aliases;

  Currency get currency => currencyForCode(currencyCode);

  /// The flag emoji, built from the two regional-indicator letters of [code].
  String get flag => String.fromCharCodes(
    code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41),
  );

  /// Whether [query] (already lower-cased and trimmed) names this country,
  /// its code, or its currency.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final c = currency;
    return name.toLowerCase().contains(query) ||
        code.toLowerCase() == query ||
        currencyCode.toLowerCase().contains(query) ||
        c.name.toLowerCase().contains(query) ||
        aliases.any((a) => a.toLowerCase().contains(query));
  }
}

/// Look a country up by its ISO code; null for one we don't list.
Country? countryForCode(String? code) {
  if (code == null) return null;
  final upper = code.toUpperCase();
  for (final c in kCountries) {
    if (c.code == upper) return c;
  }
  return null;
}

/// The first of the phone's [locales] whose region we list — a suggestion
/// only: plenty of phones run `en_US` wherever they are.
Country? countryForLocales(Iterable<Locale> locales) {
  for (final l in locales) {
    final match = countryForCode(l.countryCode);
    if (match != null) return match;
  }
  return null;
}

/// Alphabetical by [Country.name]; the picker's A–Z headers rely on it.
const List<Country> kCountries = [
  Country('AF', 'Afghanistan', 'AFN'),
  Country('AL', 'Albania', 'ALL'),
  Country('DZ', 'Algeria', 'DZD'),
  Country('AD', 'Andorra', 'EUR'),
  Country('AR', 'Argentina', 'ARS'),
  Country('AM', 'Armenia', 'AMD'),
  Country('AU', 'Australia', 'AUD'),
  Country('AT', 'Austria', 'EUR'),
  Country('AZ', 'Azerbaijan', 'AZN'),
  Country('BH', 'Bahrain', 'BHD'),
  Country('BD', 'Bangladesh', 'BDT'),
  Country('BY', 'Belarus', 'BYN'),
  Country('BE', 'Belgium', 'EUR'),
  Country('BJ', 'Benin', 'XOF'),
  Country('BT', 'Bhutan', 'BTN'),
  Country('BO', 'Bolivia', 'BOB'),
  Country('BA', 'Bosnia and Herzegovina', 'BAM'),
  Country('BW', 'Botswana', 'BWP'),
  Country('BR', 'Brazil', 'BRL'),
  // Adopted the euro on 1 January 2026.
  Country('BG', 'Bulgaria', 'EUR'),
  Country('BF', 'Burkina Faso', 'XOF'),
  Country('KH', 'Cambodia', 'KHR'),
  Country('CM', 'Cameroon', 'XAF'),
  Country('CA', 'Canada', 'CAD'),
  Country('CF', 'Central African Republic', 'XAF'),
  Country('TD', 'Chad', 'XAF'),
  Country('CL', 'Chile', 'CLP'),
  Country('CN', 'China', 'CNY'),
  Country('CO', 'Colombia', 'COP'),
  Country('CG', 'Congo', 'XAF'),
  Country('CR', 'Costa Rica', 'CRC'),
  Country('CI', "Côte d'Ivoire", 'XOF', aliases: ['Ivory Coast']),
  // Adopted the euro in 2023; HRK stays in [kCurrencies] for old settings.
  Country('HR', 'Croatia', 'EUR'),
  Country('CY', 'Cyprus', 'EUR'),
  Country('CZ', 'Czechia', 'CZK', aliases: ['Czech Republic']),
  Country('DK', 'Denmark', 'DKK'),
  Country('DO', 'Dominican Republic', 'DOP'),
  Country('EC', 'Ecuador', 'USD'),
  Country('EG', 'Egypt', 'EGP'),
  Country('SV', 'El Salvador', 'USD'),
  Country('GQ', 'Equatorial Guinea', 'XAF'),
  Country('EE', 'Estonia', 'EUR'),
  Country('ET', 'Ethiopia', 'ETB'),
  Country('FI', 'Finland', 'EUR'),
  Country('FR', 'France', 'EUR'),
  Country('GA', 'Gabon', 'XAF'),
  Country('GE', 'Georgia', 'GEL'),
  Country('DE', 'Germany', 'EUR', aliases: ['Deutschland']),
  Country('GH', 'Ghana', 'GHS'),
  Country('GR', 'Greece', 'EUR'),
  Country('GT', 'Guatemala', 'GTQ'),
  Country('GW', 'Guinea-Bissau', 'XOF'),
  Country('HN', 'Honduras', 'HNL'),
  Country('HK', 'Hong Kong', 'HKD'),
  Country('HU', 'Hungary', 'HUF'),
  Country('IS', 'Iceland', 'ISK'),
  Country('IN', 'India', 'INR', aliases: ['Bharat']),
  Country('ID', 'Indonesia', 'IDR'),
  Country('IR', 'Iran', 'IRR'),
  Country('IQ', 'Iraq', 'IQD'),
  Country('IE', 'Ireland', 'EUR'),
  Country('IL', 'Israel', 'ILS'),
  Country('IT', 'Italy', 'EUR'),
  Country('JM', 'Jamaica', 'JMD'),
  Country('JP', 'Japan', 'JPY'),
  Country('JO', 'Jordan', 'JOD'),
  Country('KZ', 'Kazakhstan', 'KZT'),
  Country('KE', 'Kenya', 'KES'),
  Country('KW', 'Kuwait', 'KWD'),
  Country('LA', 'Laos', 'LAK'),
  Country('LV', 'Latvia', 'EUR'),
  Country('LB', 'Lebanon', 'LBP'),
  Country('LI', 'Liechtenstein', 'CHF'),
  Country('LT', 'Lithuania', 'EUR'),
  Country('LU', 'Luxembourg', 'EUR'),
  Country('MO', 'Macau', 'MOP', aliases: ['Macao']),
  Country('MY', 'Malaysia', 'MYR'),
  Country('MV', 'Maldives', 'MVR'),
  Country('ML', 'Mali', 'XOF'),
  Country('MT', 'Malta', 'EUR'),
  Country('MU', 'Mauritius', 'MUR'),
  Country('MX', 'Mexico', 'MXN'),
  Country('MD', 'Moldova', 'MDL'),
  Country('MC', 'Monaco', 'EUR'),
  Country('MN', 'Mongolia', 'MNT'),
  Country('ME', 'Montenegro', 'EUR'),
  Country('MA', 'Morocco', 'MAD'),
  Country('MM', 'Myanmar', 'MMK', aliases: ['Burma']),
  Country('NP', 'Nepal', 'NPR'),
  Country('NL', 'Netherlands', 'EUR', aliases: ['Holland']),
  Country('NZ', 'New Zealand', 'NZD'),
  Country('NE', 'Niger', 'XOF'),
  Country('NG', 'Nigeria', 'NGN'),
  Country('MK', 'North Macedonia', 'MKD', aliases: ['Macedonia']),
  Country('NO', 'Norway', 'NOK'),
  Country('OM', 'Oman', 'OMR'),
  Country('PK', 'Pakistan', 'PKR'),
  Country('PA', 'Panama', 'PAB'),
  Country('PY', 'Paraguay', 'PYG'),
  Country('PE', 'Peru', 'PEN'),
  Country('PH', 'Philippines', 'PHP'),
  Country('PL', 'Poland', 'PLN'),
  Country('PT', 'Portugal', 'EUR'),
  Country('PR', 'Puerto Rico', 'USD'),
  Country('QA', 'Qatar', 'QAR'),
  Country('RO', 'Romania', 'RON'),
  Country('RU', 'Russia', 'RUB'),
  Country('RW', 'Rwanda', 'RWF'),
  Country('SM', 'San Marino', 'EUR'),
  Country('SA', 'Saudi Arabia', 'SAR', aliases: ['KSA']),
  Country('SN', 'Senegal', 'XOF'),
  Country('RS', 'Serbia', 'RSD'),
  Country('SG', 'Singapore', 'SGD'),
  Country('SK', 'Slovakia', 'EUR'),
  Country('SI', 'Slovenia', 'EUR'),
  Country('ZA', 'South Africa', 'ZAR'),
  Country('KR', 'South Korea', 'KRW', aliases: ['Korea']),
  Country('ES', 'Spain', 'EUR', aliases: ['España']),
  Country('LK', 'Sri Lanka', 'LKR'),
  Country('SE', 'Sweden', 'SEK'),
  Country('CH', 'Switzerland', 'CHF'),
  Country('TW', 'Taiwan', 'TWD'),
  Country('TZ', 'Tanzania', 'TZS'),
  Country('TH', 'Thailand', 'THB'),
  Country('TG', 'Togo', 'XOF'),
  Country('TN', 'Tunisia', 'TND'),
  Country('TR', 'Türkiye', 'TRY', aliases: ['Turkey']),
  Country('UG', 'Uganda', 'UGX'),
  Country('UA', 'Ukraine', 'UAH'),
  Country(
    'AE',
    'United Arab Emirates',
    'AED',
    aliases: ['UAE', 'Dubai', 'Emirates'],
  ),
  Country(
    'GB',
    'United Kingdom',
    'GBP',
    aliases: ['UK', 'Britain', 'England', 'Scotland', 'Wales'],
  ),
  Country('US', 'United States', 'USD', aliases: ['USA', 'America']),
  Country('UY', 'Uruguay', 'UYU'),
  Country('UZ', 'Uzbekistan', 'UZS'),
  Country('VN', 'Vietnam', 'VND'),
  Country('ZM', 'Zambia', 'ZMW'),
];
