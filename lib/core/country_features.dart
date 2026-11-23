/// What a country turns on by default — the one place that decides which
/// country-specific features someone sees. Every one of them can still be
/// switched by hand (Settings → Payment methods); these are only the
/// starting point a country pick (onboarding, Settings → Country) applies.
library;

/// Which "pay / request" methods start switched on for a country.
typedef PaymentDefaults = ({
  bool upi,
  bool paypal,
  bool venmo,
  bool cashapp,
  bool revolut,
});

/// Europe's countries where Revolut is offered to everyday users (the EEA,
/// the UK and Switzerland).
const _revolutCountries = {
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', //
  'HU', 'IS', 'IE', 'IT', 'LV', 'LI', 'LT', 'LU', 'MT', 'NL', 'NO', 'PL',
  'PT', 'RO', 'SK', 'SI', 'ES', 'SE', 'GB', 'CH',
};

/// [PaymentDefaults] for the ISO country [code]. UPI is India's; Venmo and
/// Cash App are US-only; Revolut is European. PayPal works almost
/// everywhere except for person-to-person payments inside India.
PaymentDefaults paymentDefaultsFor(String code) {
  final c = code.toUpperCase();
  return (
    upi: c == 'IN',
    paypal: c != 'IN',
    venmo: c == 'US',
    cashapp: c == 'US',
    revolut: _revolutCountries.contains(c),
  );
}

/// India's own tools — the income-tax calculator, UPI's *99#, Tally
/// export and the like — are on for India.
bool isIndia(String? countryCode) => countryCode?.toUpperCase() == 'IN';

/// Countries voice add understands. Its phrases (see `voice_parser.dart`)
/// are Indian English with common Hinglish words, so only India for now.
const voiceAddCountries = {'IN'};

/// The speech-recognition language voice add listens in, per country.
String? voiceLocaleFor(String? countryCode) =>
    switch (countryCode?.toUpperCase()) {
      'IN' => 'en-IN',
      _ => null,
    };
