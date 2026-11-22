import 'package:flutter/material.dart';
import '../../core/l10n/l10n.dart';

/// Whether the India-only calculators — India's income tax regimes, GST and
/// PPF, all in rupees — are offered. The app keeps no country, only the
/// parent currency the first-run country step set, so ₹ stands for India.
bool indiaToolsFor(String currencyCode) => currencyCode == 'INR';

/// The headings the Calculations page groups its calculators under.
enum CalculatorSection {
  grow('Save & grow'),
  borrow('Borrow'),
  tax('Tax');

  const CalculatorSection(String label) : _label = label;

  final String _label;
  String get label => tr(_label);
}

/// Every calculator on More → Calculations. Each one is a tile there and a
/// route at `/more/calculators/<name>`; add a value here and a case in
/// `CalculatorScreen` to ship a new one.
enum CalculatorKind {
  deposit(
    Icons.account_balance_outlined,
    'FD & RD',
    'Fixed & recurring deposit maturity',
    CalculatorSection.grow,
  ),
  loan(
    Icons.request_quote_outlined,
    'Loan EMI',
    'EMI, interest & schedule',
    CalculatorSection.borrow,
  ),
  incomeTax(
    Icons.receipt_outlined,
    'Income Tax',
    'India, US, UK & Germany',
    CalculatorSection.tax,
  ),
  sip(
    Icons.trending_up_rounded,
    'SIP & Lumpsum',
    'Mutual fund growth',
    CalculatorSection.grow,
  ),
  ppf(
    Icons.shield_outlined,
    'PPF',
    'Public Provident Fund maturity',
    CalculatorSection.grow,
    indiaOnly: true,
  ),
  gst(
    Icons.percent_rounded,
    'GST',
    'Add or remove GST',
    CalculatorSection.tax,
    indiaOnly: true,
  );

  const CalculatorKind(
    this.icon,
    String label,
    String subtitle,
    this.section, {
    this.indiaOnly = false,
  }) : _label = label,
       _subtitle = subtitle;

  final IconData icon;
  final String _label;
  String get label => tr(_label);
  final String _subtitle;
  String get subtitle => tr(_subtitle);
  final CalculatorSection section;

  /// Shown only where [indiaToolsFor] holds.
  final bool indiaOnly;

  /// [subtitle], minus India where India's tools aren't offered.
  String subtitleFor({required bool india}) =>
      this == incomeTax && !india ? tr('US, UK & Germany') : subtitle;

  String get route => '/more/calculators/$name';

  /// The calculators to offer, in order.
  static List<CalculatorKind> shownFor({required bool india}) => [
    for (final k in values)
      if (india || !k.indiaOnly) k,
  ];
}
