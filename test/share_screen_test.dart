import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/platform/outgoing_file.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/share/share_cards.dart';
import 'package:xpenc/features/share/share_flows.dart';
import 'package:xpenc/features/share/share_models.dart';
import 'package:xpenc/features/share/share_pdfs.dart';
import 'package:xpenc/features/share/share_screen.dart';

const _whatsappId = 'com.whatsapp/com.whatsapp.contact.picker.ContactPicker';
const _messagesId =
    'com.google.android.apps.messaging/'
    'com.google.android.apps.messaging.ui.conversationlist.ShareIntentActivity';
const _gmailId =
    'com.google.android.gm/com.google.android.gm.ComposeActivityGmailExternal';
const _instagramId =
    'com.instagram.android/com.instagram.share.handleractivity.ShareHandlerActivity';

const _whatsapp = ShareTarget(
  id: _whatsappId,
  label: 'WhatsApp',
  kind: ShareTargetKind.whatsapp,
);
const _messages = ShareTarget(
  id: _messagesId,
  label: 'Messages',
  kind: ShareTargetKind.messages,
  takesPdf: false,
);
const _gmail = ShareTarget(id: _gmailId, label: 'Gmail');
const _instagram = ShareTarget(
  id: _instagramId,
  label: 'Instagram',
  takesPdf: false,
);

/// A phone with only WhatsApp and Messages to share to, both on the row.
const _defaults = ShareTargets(
  all: [_messages, _whatsapp],
  pinnedIds: [_whatsappId, _messagesId],
);

/// The share screen: Image ⇄ PDF (opening on the last one sent), a
/// scan-to-pay QR for what a person owes, and WhatsApp / Messages straight.
/// Same rules as `smoke_test.dart` — DB work in `runAsync`, unmount at the
/// end — since it pumps against a real database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async {
    OutgoingFile.debugTargets = null;
    OutgoingFile.debugSendTo = null;
    OutgoingFile.debugDeliver = null;
    await db.close();
  });

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  /// Ram owes 500; my UPI ID is set.
  Future<int> ramOwes500({String? phone}) async {
    await db.setMyUpiId('yash@okhdfc');
    await db.setMyUpiName('Yash');
    final id = await db.addPerson('Ram', phone: phone);
    await db.addPersonEntry(
      personId: id,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 10, 2),
      accountId: await cashId(),
    );
    return id;
  }

  group('whatsappJid', () {
    test('keeps an international number, digits only', () {
      expect(
        whatsappJid('+91 98765-43210', currencyCode: 'USD'),
        '919876543210',
      );
      expect(
        whatsappJid('0044 7700 900123', currencyCode: 'INR'),
        '447700900123',
      );
    });

    test('a bare 10-digit number is Indian only when the app is in rupees', () {
      expect(whatsappJid('098765 43210', currencyCode: 'INR'), '919876543210');
      expect(whatsappJid('9876543210', currencyCode: 'INR'), '919876543210');
      expect(whatsappJid('9876543210', currencyCode: 'EUR'), isNull);
    });

    test('nothing for no number or a broken one', () {
      expect(whatsappJid(null, currencyCode: 'INR'), isNull);
      expect(whatsappJid('  ', currencyCode: 'INR'), isNull);
      expect(whatsappJid('+12', currencyCode: 'INR'), isNull);
      expect(whatsappJid('12345', currencyCode: 'INR'), isNull);
    });
  });

  test('PaymentQr: my UPI ID with what is owed, and nothing when nothing '
      'is', () async {
    await db.setMyUpiId('yash@okhdfc');
    await db.setMyUpiName('Yash');
    await db.setMyPaypal('yashp');
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);

    final options = PaymentQr.optionsFor(container, Money.fromRupees(500));
    expect(options.map((o) => o.method), ['UPI', 'PayPal']);
    final upi = Uri.parse(options.first.link);
    expect(upi.scheme, 'upi');
    expect(upi.host, 'pay');
    expect(upi.queryParameters['pa'], 'yash@okhdfc');
    expect(upi.queryParameters['pn'], 'Yash');
    expect(upi.queryParameters['am'], '500.00');
    expect(options.first.payTo, 'Yash');

    expect(PaymentQr.optionsFor(container, const Money.zero()), isEmpty);
    expect(PaymentQr.optionsFor(container, Money.fromRupees(-20)), isEmpty);

    await db.setUpiEnabled(false);
    await container.read(settingsProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      PaymentQr.optionsFor(
        container,
        Money.fromRupees(500),
      ).map((o) => o.method),
      ['PayPal'],
    );
  });

  test('PersonShare.message speaks from the sender', () async {
    final id = await ramOwes500();
    final share = PersonShare(
      person: (await db.watchPersons().first).single,
      owner: const ShareOwner('Yash'),
      entries: await db.watchPersonEntries(id).first,
      balance: Money.fromRupees(500),
    );
    expect(
      share.message(),
      "Hi Ram, here's where we stand: you owe me ₹500.00.",
    );
    final qr = PaymentQr(
      method: 'UPI',
      id: 'yash@okhdfc',
      link: 'upi://pay?pa=yash@okhdfc',
      amount: Money.fromRupees(500),
      hint: 'Scan with any UPI app',
    );
    expect(share.message(qr: qr), endsWith('Scan the QR to pay by UPI.'));
  });

  test('SharePeriod.custom labels with the year only where it differs', () {
    final now = DateTime(2026, 10, 26);
    expect(
      SharePeriod.custom(
        DateTimeRange(start: DateTime(2026, 9, 3), end: DateTime(2026, 10, 12)),
        now,
      ).label,
      '3 Sep – 12 Oct',
    );
    expect(
      SharePeriod.custom(
        DateTimeRange(start: DateTime(2025, 12, 20), end: DateTime(2026, 1, 5)),
        now,
      ).label,
      '20 Dec 2025 – 5 Jan',
    );
  });

  test('the person PDF carries the scan-to-pay QR', () async {
    final id = await ramOwes500();
    final share = PersonShare(
      person: (await db.watchPersons().first).single,
      owner: const ShareOwner('Yash'),
      entries: await db.watchPersonEntries(id).first,
      balance: Money.fromRupees(500),
    );
    final qr = PaymentQr(
      method: 'UPI',
      id: 'yash@okhdfc',
      link: 'upi://pay?pa=yash%40okhdfc&am=500.00',
      amount: Money.fromRupees(500),
      hint: 'Scan with any UPI app',
      payTo: 'Yash',
    );
    final plain = await buildPersonStatementPdf(share, SharePeriod.allTime);
    final withQr = await buildPersonStatementPdf(
      share,
      SharePeriod.allTime,
      qr: qr,
    );
    expect(String.fromCharCodes(withQr.take(5)), '%PDF-');
    expect(withQr.length, greaterThan(plain.length));
  });

  for (final tone in ShareCardTone.values) {
    testWidgets('person card with a QR lays out · ${tone.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final share = (await tester.runAsync(() async {
        final id = await ramOwes500();
        return PersonShare(
          person: (await db.watchPersons().first).single,
          owner: const ShareOwner('Yash'),
          entries: await db.watchPersonEntries(id).first,
          balance: Money.fromRupees(500),
        );
      }))!;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: PersonShareCard(
                  data: share,
                  period: SharePeriod.allTime,
                  tone: tone,
                  qr: PaymentQr(
                    method: 'UPI',
                    id: 'a-very-long-upi-handle-for-testing@okhdfcbank',
                    link: 'upi://pay?pa=yash%40okhdfc&am=500.00',
                    amount: Money.fromRupees(12345678.9),
                    hint: 'Scan with any UPI app',
                    payTo: 'Ramchandra Venkataraman Subramanian',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('SCAN TO PAY'), findsOneWidget);
    });
  }

  group('sharing a person', () {
    Future<void> openShare(WidgetTester tester, int personId) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Consumer(
              builder: (context, ref, _) {
                // The app root keeps settings loaded; so does this.
                ref.watch(settingsProvider);
                final people = ref.watch(personsProvider).valueOrNull ?? [];
                final person = people
                    .where((p) => p.id == personId)
                    .firstOrNull;
                return Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: person == null
                          ? null
                          : () => sharePerson(context, person),
                      child: const Text('Open share'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.tap(find.text('Open share'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// Through the preview's cross-fade: its clock starts on the first
    /// frame after the switch, the old one leaves on the frame after it ends.
    Future<void> crossFade(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('opens on Image with the QR on; WhatsApp gets the PDF and '
        'the message, and PDF is what opens next time', (tester) async {
      final ram = (await tester.runAsync(
        () => ramOwes500(phone: '98765 43210'),
      ))!;
      OutgoingFile.debugTargets = _defaults;
      final sent = <(OutgoingFile, ShareTarget, String?)>[];
      OutgoingFile.debugSendTo = (file, target, text) async {
        sent.add((file, target, text));
        return ShareAppResult.sent;
      };

      await openShare(tester, ram);
      expect(find.text('SCAN TO PAY'), findsOneWidget);
      expect(find.text('UPI QR'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // One payment method: the pill just turns the QR off and on.
      await tester.ensureVisible(find.text('UPI QR'));
      await tester.tap(find.text('UPI QR'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('SCAN TO PAY'), findsNothing);
      await tester.tap(find.text('No QR'));
      await tester.pump(const Duration(milliseconds: 300));

      // The PDF's page preview carries the same QR.
      await tester.tap(find.text('PDF'));
      await crossFade(tester);
      expect(find.text('SCAN TO PAY'), findsOneWidget);
      expect(find.text('UPI · yash@okhdfc'), findsOneWidget);
      expect(find.text('Dark'), findsNothing);

      await tester.tap(find.text('WhatsApp'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      expect(sent, hasLength(1));
      final (file, target, text) = sent.single;
      expect(target.kind, ShareTargetKind.whatsapp);
      expect(file.mimeType, 'application/pdf');
      expect(file.name, endsWith('.pdf'));
      expect(text, contains('you owe me ₹500.00'));
      expect(text, contains('Scan the QR to pay by UPI.'));

      final format = await tester.runAsync(
        () async => (await db.getSettings()).shareFormat,
      );
      expect(format, ShareFormat.pdf);
      await unmount(tester);
    });

    testWidgets('opens on the last format sent; no apps → one Share button', (
      tester,
    ) async {
      final ram = (await tester.runAsync(() async {
        await db.setShareFormat(ShareFormat.pdf);
        return ramOwes500();
      }))!;
      await openShare(tester, ram);
      expect(find.text('Share PDF'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('PDF · A4 · All time'), findsOneWidget);

      await tester.tap(find.text('Image'));
      await crossFade(tester);
      expect(find.text('Share image'), findsOneWidget);
      expect(find.text('SCAN TO PAY'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('no UPI ID yet: a hint where the QR pill would be', (
      tester,
    ) async {
      final ram = (await tester.runAsync(() async {
        final id = await ramOwes500();
        await db.setMyUpiId(null);
        return id;
      }))!;
      await openShare(tester, ram);
      expect(find.text('UPI QR'), findsNothing);
      expect(find.text('No QR'), findsNothing);
      expect(find.textContaining('Add your UPI ID'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('switching Image ⇄ PDF moves nothing: the slider, the pills '
        'and the app row stay put', (tester) async {
      final ram = (await tester.runAsync(ramOwes500))!;
      OutgoingFile.debugTargets = _defaults;
      await openShare(tester, ram);
      // Past the page's own way in.
      await tester.pump(const Duration(seconds: 1));

      // One size on every phone, its labels in the middle of it.
      final slider = tester.getRect(find.byType(ShareFormatSlider));
      expect(slider.width, moreOrLessEquals(232));
      expect(slider.height, moreOrLessEquals(40));
      for (final label in ['Image', 'PDF']) {
        expect(
          tester.getCenter(find.text(label)).dy,
          moreOrLessEquals(slider.center.dy, epsilon: 1),
        );
      }

      Map<String, Rect> layout() => {
        'slider': tester.getRect(find.byType(ShareFormatSlider)),
        'period': tester.getRect(find.byIcon(CupertinoIcons.calendar)),
        'qr': tester.getRect(find.byIcon(CupertinoIcons.qrcode)),
        for (final t in ['WhatsApp', 'Messages', 'More'])
          t: tester.getRect(find.text(t)),
      };
      final onImage = layout();
      final look = tester.getRect(find.byIcon(CupertinoIcons.moon_fill));

      await tester.tap(find.text('PDF'));
      await crossFade(tester);
      expect(layout(), onImage);
      // The look pill stays in its slot, greyed out: a PDF is always light.
      expect(find.text('Dark'), findsNothing);
      expect(
        tester.getRect(find.byIcon(CupertinoIcons.sun_max_fill)).topLeft,
        look.topLeft,
      );

      await tester.tap(find.text('Image'));
      await crossFade(tester);
      expect(layout(), onImage);
      expect(find.text('Dark'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the app row is the user\'s: long-press swaps WhatsApp for '
        'Gmail, Add puts Instagram on, an app that takes no PDF dims, and '
        'the default comes back', (tester) async {
      final ram = (await tester.runAsync(ramOwes500))!;
      OutgoingFile.debugTargets = const ShareTargets(
        all: [_gmail, _instagram, _messages, _whatsapp],
        pinnedIds: [_whatsappId, _messagesId],
      );
      final sent = <ShareTarget>[];
      OutgoingFile.debugSendTo = (file, target, text) async {
        sent.add(target);
        return ShareAppResult.sent;
      };
      Future<void> sheet() async {
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
      }

      List<String> pinned() => OutgoingFile.debugTargets!.pinnedIds;

      await openShare(tester, ram);
      expect(find.text('Add'), findsOneWidget);

      // Swap: WhatsApp's own slot becomes Gmail's.
      await tester.longPress(find.text('WhatsApp'));
      await sheet();
      expect(find.text('Remove from Share'), findsOneWidget);
      expect(find.text('Move right'), findsOneWidget);
      expect(find.text('Move left'), findsNothing);
      await tester.tap(find.text('Gmail'));
      await sheet();
      expect(pinned(), [_gmailId, _messagesId]);
      expect(find.text('WhatsApp'), findsNothing);
      expect(
        tester.getCenter(find.text('Gmail')).dx,
        lessThan(tester.getCenter(find.text('Messages')).dx),
      );

      // Add: one more, at the end.
      await tester.tap(find.text('Add'));
      await sheet();
      await tester.tap(find.text('Instagram'));
      await sheet();
      expect(pinned(), [_gmailId, _messagesId, _instagramId]);

      // Instagram takes no PDF: dimmed, and a tap says so instead of
      // sending.
      await tester.tap(find.text('PDF'));
      await crossFade(tester);
      await tester.tap(find.text('Instagram'));
      await tester.pump();
      expect(find.textContaining("Instagram doesn't take a PDF"), findsOne);
      expect(sent, isEmpty);
      ScaffoldMessenger.of(
        tester.element(find.text('More')),
      ).hideCurrentSnackBar();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Gmail'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump();
      expect(sent.single.id, _gmailId);

      // Move, then back to the default row.
      await tester.longPress(find.text('Instagram'));
      await sheet();
      await tester.tap(find.text('Move left'));
      await sheet();
      expect(pinned(), [_gmailId, _instagramId, _messagesId]);

      await tester.longPress(find.text('Gmail'));
      await sheet();
      await tester.tap(find.text('Back to the default apps'));
      await sheet();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(pinned(), [_whatsappId, _messagesId]);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Gmail'), findsNothing);
      await unmount(tester);
    });
  });
}
