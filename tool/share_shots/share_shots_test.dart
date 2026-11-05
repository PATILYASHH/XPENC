// Renders the share screen to PNGs for a visual check, with the real fonts:
//
//   SHOTS_OUT=<dir> flutter test tool/share_shots/share_shots_test.dart --update-goldens
//
// Lives outside test/ so CI's `flutter test` never runs it.
//
// It fakes the installed apps through OutgoingFile's test hook.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/platform/outgoing_file.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/share/share_cards.dart';
import 'package:xpenc/features/share/share_models.dart';
import 'package:xpenc/features/share/share_pdfs.dart';
import 'package:xpenc/features/share/share_screen.dart';

Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

// WhatsApp, two apps of the phone's own (no icons here: their initials),
// and Messages — which takes no PDF, and dims for one.
const _targets = [
  ShareTarget(
    id: 'com.whatsapp/a',
    label: 'WhatsApp',
    kind: ShareTargetKind.whatsapp,
  ),
  ShareTarget(id: 'com.google.android.gm/a', label: 'Gmail'),
  ShareTarget(id: 'org.telegram.messenger/a', label: 'Telegram'),
  ShareTarget(
    id: 'com.google.android.apps.messaging/a',
    label: 'Messages',
    kind: ShareTargetKind.messages,
    takesPdf: false,
  ),
];

void main() {
  final out = Platform.environment['SHOTS_OUT'];
  setUpAll(_loadFonts);

  // Classic draws in the platform font, which flutter_test doesn't have.
  ThemeData inter(ThemeData t) =>
      t.copyWith(textTheme: t.textTheme.apply(fontFamily: 'Inter'));
  final themes = {
    'light': inter(AppTheme.light),
    'dark': inter(AppTheme.dark),
    'glass': AppTheme.of(
      GlassBackdrop.black.palette,
      ThemeStyle.glass.shape,
      backdrop: GlassBackdrop.black,
    ),
  };

  for (final MapEntry(key: themeName, value: theme) in themes.entries) {
    for (final (pdf, apps) in [
      (false, 'default'),
      (true, 'default'),
      (false, 'none'),
      (true, 'four'),
    ]) {
      final id =
          'share_${themeName}_${pdf ? 'pdf' : 'image'}'
          '${apps == 'default' ? '' : '_$apps'}';
      testWidgets(id, (tester) async {
        if (out == null) {
          markTestSkipped('Set SHOTS_OUT to render.');
          return;
        }
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        OutgoingFile.debugTargets = switch (apps) {
          'none' => null,
          'four' => ShareTargets(
            all: _targets,
            pinnedIds: [for (final t in _targets) t.id],
            customized: true,
          ),
          _ => ShareTargets(
            all: _targets,
            pinnedIds: [_targets.first.id, _targets.last.id],
          ),
        };
        addTearDown(() => OutgoingFile.debugTargets = null);
        final share = (await tester.runAsync(() async {
          if (pdf) await db.setShareFormat(ShareFormat.pdf);
          final cash = (await db.watchAccounts().first)
              .firstWhere((a) => a.type == AccountType.cash)
              .id;
          final id = await db.addPerson('Rahul Sharma', phone: '9876543210');
          for (final (i, amt) in [(1, 1200.0), (4, 300.0), (9, 850.0)]) {
            await db.addPersonEntry(
              personId: id,
              direction: i == 4
                  ? PersonDirection.iOwe
                  : PersonDirection.theyOwe,
              amount: Money.fromRupees(amt),
              date: DateTime(2026, 10, i),
              accountId: cash,
              note: i == 1 ? 'Concert tickets' : null,
            );
          }
          return PersonShare(
            person: (await db.watchPersons().first).single,
            owner: const ShareOwner('Yash'),
            entries: await db.watchPersonEntries(id).first,
            balance: Money.fromRupees(1750),
          );
        }))!;
        final qrs = [
          for (final (m, idText) in [
            ('UPI', 'yash@okhdfc'),
            ('PayPal', 'paypal.me/yashp'),
          ])
            PaymentQr(
              method: m,
              id: idText,
              link: 'upi://pay?pa=yash%40okhdfc&am=1750.00&cu=INR',
              amount: Money.fromRupees(1750),
              hint: 'Scan with any UPI app',
              payTo: 'Yash',
            ),
        ];
        tester.view.physicalSize = const Size(390, 844) * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(
          top: 47 * 3,
          bottom: 34 * 3,
        );
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [dbProvider.overrideWithValue(db)],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: Consumer(
                builder: (context, ref, _) {
                  if (ref.watch(settingsProvider).valueOrNull == null) {
                    return const SizedBox();
                  }
                  return ShareScreen(
                    title: 'Share Rahul Sharma',
                    fileStem: 'xpenc-rahul-sharma-statement-20261027-1015',
                    subject: 'Rahul Sharma · statement',
                    message: (qr) => share.message(qr: qr),
                    periods: [
                      SharePeriod.allTime,
                      SharePeriod.thisMonth(),
                      SharePeriod.lastMonth(),
                    ],
                    payments: qrs,
                    recipientPhone: '9876543210',
                    image: (tone, period, qr) => PersonShareCard(
                      data: share,
                      period: period,
                      tone: tone,
                      qr: qr,
                    ),
                    pdf: (period, qr) =>
                        buildPersonStatementPdf(share, period, qr: qr),
                  );
                },
              ),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 150));
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(Uri.file('$out/$id.png')),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
