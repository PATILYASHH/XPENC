import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/widgets/action_sheet.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/statement_range_picker.dart';
import '../../data/database.dart';
import 'share_cards.dart';
import 'share_files.dart';
import 'share_image_screen.dart';
import 'share_models.dart';
import 'share_pdfs.dart';

/// Every Share button — a transaction, a person, a group — opens the same
/// choice: a structured PDF, or a styled image card.
enum ShareFormat { pdf, image }

Future<ShareFormat?> pickShareFormat(
  BuildContext context, {
  required String title,
}) => showActionSheet<ShareFormat>(
  context: context,
  title: title,
  optionCount: 2,
  options: (sheetContext) => [
    AppListTile(
      leading: const AppIcon(Icons.picture_as_pdf_outlined),
      title: const Text('PDF document'),
      subtitle: const Text('Structured and printable, with every detail.'),
      onTap: () => Navigator.of(sheetContext).pop(ShareFormat.pdf),
    ),
    AppListTile(
      leading: const AppIcon(Icons.image_outlined),
      title: const Text('Image'),
      subtitle: const Text('A styled card, ready for any chat.'),
      onTap: () => Navigator.of(sheetContext).pop(ShareFormat.image),
    ),
  ],
);

/// Share one transaction as a receipt.
Future<void> shareTransaction(BuildContext context, TransactionRow t) async {
  final format = await pickShareFormat(context, title: 'Share transaction');
  if (format == null || !context.mounted) return;
  final data = TransactionShare.resolve(
    ProviderScope.containerOf(context, listen: false),
    t,
  );
  final stem = shareFileStem('${data.typeLabel} ${data.headline}');
  final subject =
      '${data.typeLabel} · ${MoneyFormat.forCurrency(t.amount, data.currency)}';

  if (format == ShareFormat.image) {
    await _openImage(
      context,
      ShareImageScreen(
        title: 'Share transaction',
        fileStem: stem,
        subject: subject,
        secure: t.isNct,
        builder: (tone, _) => TransactionShareCard(data: data, tone: tone),
      ),
    );
    return;
  }
  await _sharePdf(
    context,
    build: () => buildTransactionPdf(data),
    fileStem: stem,
    subject: subject,
  );
}

/// Share a person's ledger: a PDF statement for a period, or a balance card.
Future<void> sharePerson(BuildContext context, PersonRow person) async {
  final format = await pickShareFormat(context, title: 'Share ${person.name}');
  if (format == null || !context.mounted) return;
  final data = await PersonShare.load(
    ProviderScope.containerOf(context, listen: false),
    person,
  );
  if (!context.mounted) return;
  final stem = shareFileStem('${person.name} statement');
  final subject = '${person.name} · statement';

  if (format == ShareFormat.image) {
    await _openImage(
      context,
      ShareImageScreen(
        title: 'Share ${person.name}',
        fileStem: stem,
        subject: subject,
        periods: [
          SharePeriod.allTime,
          SharePeriod.thisMonth(),
          SharePeriod.lastMonth(),
        ],
        builder: (tone, period) =>
            PersonShareCard(data: data, period: period, tone: tone),
      ),
    );
    return;
  }
  final picked = await pickStatementRangeOrAllTime(context);
  if (picked == null || !context.mounted) return;
  await _sharePdf(
    context,
    build: () => buildPersonStatementPdf(data, SharePeriod('', picked.range)),
    fileStem: stem,
    subject: subject,
  );
}

/// Share a group: a PDF statement for a period, or a summary card.
Future<void> shareGroup(BuildContext context, GroupRow group) async {
  final format = await pickShareFormat(context, title: 'Share ${group.name}');
  if (format == null || !context.mounted) return;
  final data = await GroupShare.load(
    ProviderScope.containerOf(context, listen: false),
    group,
  );
  if (!context.mounted) return;
  final stem = shareFileStem('${group.name} group');
  final subject = '${group.name} · group statement';

  if (format == ShareFormat.image) {
    await _openImage(
      context,
      ShareImageScreen(
        title: 'Share ${group.name}',
        fileStem: stem,
        subject: subject,
        periods: [
          SharePeriod.allTime,
          SharePeriod.thisMonth(),
          SharePeriod.lastMonth(),
        ],
        builder: (tone, period) =>
            GroupShareCard(data: data, period: period, tone: tone),
      ),
    );
    return;
  }
  final picked = await pickStatementRangeOrAllTime(context);
  if (picked == null || !context.mounted) return;
  await _sharePdf(
    context,
    build: () => buildGroupStatementPdf(data, SharePeriod('', picked.range)),
    fileStem: stem,
    subject: subject,
  );
}

/// Full screen, above the shell's bottom nav.
Future<void> _openImage(BuildContext context, Widget screen) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => screen));

Future<void> _sharePdf(
  BuildContext context, {
  required Future<Uint8List> Function() build,
  required String fileStem,
  required String subject,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Preparing PDF...')));
  try {
    final file = await writeShareFile(await build(), '$fileStem.pdf');
    messenger.hideCurrentSnackBar();
    await shareFile(file, mimeType: 'application/pdf', subject: subject);
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text("Couldn't create the PDF: $e")));
  }
}
