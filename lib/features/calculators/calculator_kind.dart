import 'package:flutter/material.dart';
import '../../core/l10n/l10n.dart';

/// Every calculator in More → Calculators. Each one is a tile in that group
/// and a route at `/more/calculators/<name>`; add a value here and a case in
/// `CalculatorScreen` to ship a new one.
enum CalculatorKind {
  deposit(
    Icons.account_balance_outlined,
    'FD & RD',
    'Fixed & recurring deposit maturity',
  ),
  loan(Icons.request_quote_outlined, 'Loan EMI', 'EMI, interest & schedule'),
  incomeTax(Icons.receipt_outlined, 'Income Tax', 'India, US, UK & Germany'),
  sip(Icons.trending_up_rounded, 'SIP & Lumpsum', 'Mutual fund growth'),
  ppf(Icons.shield_outlined, 'PPF', 'Public Provident Fund maturity'),
  gst(Icons.percent_rounded, 'GST', 'Add or remove GST');

  const CalculatorKind(this.icon, String label, String subtitle) : _label = label, _subtitle = subtitle;

  final IconData icon;
  final String _label;
  String get label => tr(_label);
  final String _subtitle;
  String get subtitle => tr(_subtitle);

  String get route => '/more/calculators/$name';
}
