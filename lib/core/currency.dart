/// A currency the app can display amounts in. Money is always **stored** as an
/// integer number of minor units (hundredths); a currency only changes how that
/// number is *rendered* — its symbol, how many decimals to show, and (via
/// [MoneyFormat]) how digits are grouped.
///
/// [decimalDigits] is a display choice. Storage stays at two places regardless,
/// so switching currency never rewrites the ledger.
class Currency {
  const Currency(this.code, this.symbol, this.name, {this.decimalDigits = 2});

  /// ISO 4217 code, e.g. `INR`, `USD`, `BDT`.
  final String code;

  /// The glyph shown before the amount, e.g. `₹`, `$`, `৳`.
  final String symbol;

  /// Human name for the picker, e.g. `Indian Rupee`.
  final String name;

  /// How many fraction digits to show. Most currencies use 2; yen-like ones 0;
  /// a few Gulf currencies 3.
  final int decimalDigits;
}

/// The out-of-the-box currency. Kept as the default everywhere so nothing has
/// to be configured before the first frame, and so existing users (whose
/// `currencyCode` defaults to `INR`) see no change.
const Currency kDefaultCurrency = Currency('INR', '₹', 'Indian Rupee');

/// Look a currency up by code, falling back to [kDefaultCurrency] for an
/// unknown code (an old backup, a corrupt setting) rather than crashing.
Currency currencyForCode(String? code) {
  if (code == null) return kDefaultCurrency;
  for (final c in kCurrencies) {
    if (c.code == code) return c;
  }
  return kDefaultCurrency;
}

/// A curated, alphabetical-by-name set of world currencies. Not exhaustive, but
/// broad — and easy to extend: add a row and it shows up in the picker. When a
/// user's currency is missing they can still pick the closest and hide the
/// symbol (see the "Show currency symbol" setting).
const List<Currency> kCurrencies = [
  Currency('AFN', '؋', 'Afghan Afghani'),
  Currency('ALL', 'L', 'Albanian Lek'),
  Currency('DZD', 'دج', 'Algerian Dinar'),
  Currency('ARS', r'$', 'Argentine Peso'),
  Currency('AMD', '֏', 'Armenian Dram'),
  Currency('AUD', r'$', 'Australian Dollar'),
  Currency('AZN', '₼', 'Azerbaijani Manat'),
  Currency('BHD', '.د.ب', 'Bahraini Dinar', decimalDigits: 3),
  Currency('BDT', '৳', 'Bangladeshi Taka'),
  Currency('BYN', 'Br', 'Belarusian Ruble'),
  Currency('BOB', 'Bs.', 'Bolivian Boliviano'),
  Currency('BAM', 'KM', 'Bosnia-Herzegovina Mark'),
  Currency('BWP', 'P', 'Botswanan Pula'),
  Currency('BRL', r'R$', 'Brazilian Real'),
  Currency('BGN', 'лв', 'Bulgarian Lev'),
  Currency('KHR', '៛', 'Cambodian Riel'),
  Currency('CAD', r'$', 'Canadian Dollar'),
  Currency('CLP', r'$', 'Chilean Peso', decimalDigits: 0),
  Currency('CNY', '¥', 'Chinese Yuan'),
  Currency('COP', r'$', 'Colombian Peso'),
  Currency('CRC', '₡', 'Costa Rican Colón'),
  Currency('HRK', 'kn', 'Croatian Kuna'),
  Currency('CZK', 'Kč', 'Czech Koruna'),
  Currency('DKK', 'kr', 'Danish Krone'),
  Currency('DOP', r'RD$', 'Dominican Peso'),
  Currency('EGP', 'E£', 'Egyptian Pound'),
  Currency('EUR', '€', 'Euro'),
  Currency('GEL', '₾', 'Georgian Lari'),
  Currency('GHS', '₵', 'Ghanaian Cedi'),
  Currency('GTQ', 'Q', 'Guatemalan Quetzal'),
  Currency('HNL', 'L', 'Honduran Lempira'),
  Currency('HKD', r'HK$', 'Hong Kong Dollar'),
  Currency('HUF', 'Ft', 'Hungarian Forint'),
  Currency('ISK', 'kr', 'Icelandic Króna', decimalDigits: 0),
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('IDR', 'Rp', 'Indonesian Rupiah'),
  Currency('IRR', '﷼', 'Iranian Rial'),
  Currency('IQD', 'ع.د', 'Iraqi Dinar', decimalDigits: 3),
  Currency('ILS', '₪', 'Israeli New Shekel'),
  Currency('JMD', r'J$', 'Jamaican Dollar'),
  Currency('JPY', '¥', 'Japanese Yen', decimalDigits: 0),
  Currency('JOD', 'د.ا', 'Jordanian Dinar', decimalDigits: 3),
  Currency('KZT', '₸', 'Kazakhstani Tenge'),
  Currency('KES', 'KSh', 'Kenyan Shilling'),
  Currency('KWD', 'د.ك', 'Kuwaiti Dinar', decimalDigits: 3),
  Currency('LAK', '₭', 'Lao Kip'),
  Currency('LBP', 'ل.ل', 'Lebanese Pound'),
  Currency('LKR', 'Rs', 'Sri Lankan Rupee'),
  Currency('MOP', r'MOP$', 'Macanese Pataca'),
  Currency('MKD', 'ден', 'Macedonian Denar'),
  Currency('MYR', 'RM', 'Malaysian Ringgit'),
  Currency('MUR', '₨', 'Mauritian Rupee'),
  Currency('MXN', r'$', 'Mexican Peso'),
  Currency('MDL', 'L', 'Moldovan Leu'),
  Currency('MNT', '₮', 'Mongolian Tögrög'),
  Currency('MAD', 'د.م.', 'Moroccan Dirham'),
  Currency('MMK', 'K', 'Myanmar Kyat'),
  Currency('NPR', '₨', 'Nepalese Rupee'),
  Currency('TWD', r'NT$', 'New Taiwan Dollar'),
  Currency('NZD', r'$', 'New Zealand Dollar'),
  Currency('NGN', '₦', 'Nigerian Naira'),
  Currency('NOK', 'kr', 'Norwegian Krone'),
  Currency('OMR', 'ر.ع.', 'Omani Rial', decimalDigits: 3),
  Currency('PKR', '₨', 'Pakistani Rupee'),
  Currency('PAB', 'B/.', 'Panamanian Balboa'),
  Currency('PYG', '₲', 'Paraguayan Guaraní', decimalDigits: 0),
  Currency('PEN', 'S/', 'Peruvian Sol'),
  Currency('PHP', '₱', 'Philippine Peso'),
  Currency('PLN', 'zł', 'Polish Złoty'),
  Currency('QAR', 'ر.ق', 'Qatari Riyal'),
  Currency('RON', 'lei', 'Romanian Leu'),
  Currency('RUB', '₽', 'Russian Ruble'),
  Currency('SAR', 'ر.س', 'Saudi Riyal'),
  Currency('RSD', 'дин.', 'Serbian Dinar'),
  Currency('SGD', r'S$', 'Singapore Dollar'),
  Currency('ZAR', 'R', 'South African Rand'),
  Currency('KRW', '₩', 'South Korean Won', decimalDigits: 0),
  Currency('GBP', '£', 'British Pound'),
  Currency('SEK', 'kr', 'Swedish Krona'),
  Currency('CHF', 'CHF', 'Swiss Franc'),
  Currency('THB', '฿', 'Thai Baht'),
  Currency('TND', 'د.ت', 'Tunisian Dinar', decimalDigits: 3),
  Currency('TRY', '₺', 'Turkish Lira'),
  Currency('UGX', 'USh', 'Ugandan Shilling', decimalDigits: 0),
  Currency('UAH', '₴', 'Ukrainian Hryvnia'),
  Currency('AED', 'د.إ', 'UAE Dirham'),
  Currency('USD', r'$', 'US Dollar'),
  Currency('UYU', r'$U', 'Uruguayan Peso'),
  Currency('UZS', "so'm", 'Uzbekistani Som'),
  Currency('VND', '₫', 'Vietnamese Dong', decimalDigits: 0),
];
