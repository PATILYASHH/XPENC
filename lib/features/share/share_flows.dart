import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'share_cards.dart';
import 'share_files.dart';
import 'share_models.dart';
import 'share_pdfs.dart';
import 'share_screen.dart';

// Every Share button — a transaction, a person, a group, a mode — opens the
// same [ShareScreen]: an image card or a structured PDF, previewed, then
// straight to WhatsApp / Messages or the share sheet.

/// Share one transaction as a receipt.
Future<void> shareTransaction(BuildContext context, TransactionRow t) {
  final data = TransactionShare.resolve(
    ProviderScope.containerOf(context, listen: false),
    t,
  );
  return _open(
    context,
    ShareScreen(
      title: 'Share transaction',
      fileStem: shareFileStem('${data.typeLabel} ${data.headline}'),
      subject:
          '${data.typeLabel} · ${MoneyFormat.forCurrency(t.amount, data.currency)}',
      secure: t.isNct,
      image: (tone, _, _) => TransactionShareCard(data: data, tone: tone),
      pdf: (_, _) => buildTransactionPdf(data),
    ),
  );
}

/// Share a person's ledger — a balance card or a PDF statement for a
/// period — with a code to pay what they owe.
Future<void> sharePerson(BuildContext context, PersonRow person) async {
  final ref = ProviderScope.containerOf(context, listen: false);
  final data = await PersonShare.load(ref, person);
  if (!context.mounted) return;
  final payments = PaymentQr.optionsFor(ref, data.balance);
  final anyMethodOn =
      ref.read(upiEnabledProvider) ||
      ref.read(paypalEnabledProvider) ||
      ref.read(venmoEnabledProvider) ||
      ref.read(cashappEnabledProvider) ||
      ref.read(revolutEnabledProvider);
  await _open(
    context,
    ShareScreen(
      title: 'Share ${person.name}',
      fileStem: shareFileStem('${person.name} statement'),
      subject: '${person.name} · statement',
      message: (qr) => data.message(qr: qr),
      periods: _ledgerPeriods(),
      payments: payments,
      paymentsHint: payments.isEmpty && data.balance.isPositive && anyMethodOn
          ? 'Add your UPI ID in Settings → Persons to put a scan-to-pay QR '
                'on this.'
          : null,
      recipientPhone: person.phone,
      image: (tone, period, qr) =>
          PersonShareCard(data: data, period: period, tone: tone, qr: qr),
      pdf: (period, qr) => buildPersonStatementPdf(data, period, qr: qr),
    ),
  );
}

/// Share a group: a summary card or a PDF statement for a period.
Future<void> shareGroup(BuildContext context, GroupRow group) async {
  final data = await GroupShare.load(
    ProviderScope.containerOf(context, listen: false),
    group,
  );
  if (!context.mounted) return;
  await _open(
    context,
    ShareScreen(
      title: 'Share ${group.name}',
      fileStem: shareFileStem('${group.name} group'),
      subject: '${group.name} · group statement',
      periods: _ledgerPeriods(),
      image: (tone, period, _) =>
          GroupShareCard(data: data, period: period, tone: tone),
      pdf: (period, _) => buildGroupStatementPdf(data, period),
    ),
  );
}

List<SharePeriod> _ledgerPeriods() => [
  SharePeriod.allTime,
  SharePeriod.thisMonth(),
  SharePeriod.lastMonth(),
];

/// Full screen, above the shell's bottom nav.
Future<void> _open(BuildContext context, Widget screen) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => screen));

/// Share a mode (a trip): its summary as an image card or a PDF report.
Future<void> shareMode(BuildContext context, ModeShare data) => _open(
  context,
  ShareScreen(
    title: 'Share ${data.name}',
    fileStem: shareFileStem('${data.name} summary'),
    subject: '${data.name} · ${MoneyFormat.symbol(data.spent)} spent',
    image: (tone, _, _) => ModeShareCard(data: data, tone: tone),
    pdf: (_, _) => buildModeSummaryPdf(data),
  ),
);
