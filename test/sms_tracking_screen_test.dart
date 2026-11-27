import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/permissions/app_permissions.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/message_capture/parser/bank_message.dart';
import 'package:xpenc/features/message_capture/parser/message_parser.dart';
import 'package:xpenc/features/message_capture/sms_inbox.dart';
import 'package:xpenc/features/message_capture/sms_tracking_screen.dart';

/// The phone's inbox, filtered by sender code the way SmsChannel.kt's
/// `address LIKE '%CODE%'` does.
class _FakeInbox implements SmsInbox {
  _FakeInbox(
    this.inbox, {
    this.isDeclared = true,
    this.state = PermissionState.granted,
    this.others = const [],
  });

  final List<RawMessage> inbox;
  final bool isDeclared;
  PermissionState state;
  final List<InboxSender> others;
  int asked = 0;

  @override
  Future<bool> declared() async => isDeclared;

  @override
  Future<PermissionState> permission() async => state;

  @override
  Future<PermissionState> requestPermission() async {
    asked++;
    return state = PermissionState.granted;
  }

  @override
  Future<List<RawMessage>> messages({
    required DateTime since,
    required List<String> senders,
    int limit = 500,
    bool newestFirst = false,
  }) async {
    final rows = [
      for (final m in inbox)
        if (m.receivedAt.isAfter(since) &&
            senders.any((s) => m.sender.toUpperCase().contains(s)))
          m,
    ]..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    return (newestFirst ? rows.reversed : rows).take(limit).toList();
  }

  @override
  Future<List<InboxSender>> senders({required DateTime since}) async => others;
}

void main() {
  late AppDatabase db;
  final now = DateTime.now();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  RawMessage sms(String body, String sender, {int hoursAgo = 3}) => RawMessage(
    body: body,
    sender: sender,
    receivedAt: now.subtract(Duration(hours: hoursAgo)),
  );

  final hdfcDebit = sms(
    'Sent Rs.232.00\nFrom HDFC Bank A/C *4821\nTo SHARMA GENERAL STORE\n'
    'On 12/10/26\nRef 629874512365\nNot You?',
    'JD-HDFCBK-S',
  );
  final hdfcOtp = sms(
    '482913 is your OTP for login. Do not share it with anyone. -HDFC Bank',
    'JD-HDFCBK-S',
    hoursAgo: 5,
  );
  final federalDebit = sms(
    'Debited Rs 274.00 from a/c X9115 on 24Nov26 19:33 via UPI to SNAPMINT '
    'FIN. Ref 632819821711.Bal Rs 669.95. -Federal Bank',
    'AX-FEDBNK-S',
    hoursAgo: 8,
  );
  final shop = sms(
    'Rs.199 paid at SWIGGY. Order 7781. Enjoy!',
    'AX-SWIGGY-S',
    hoursAgo: 1,
  );

  Future<_FakeInbox> pump(WidgetTester tester, _FakeInbox inbox) async {
    // Tall enough for the whole page: ListView only builds what's on screen.
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          smsInboxProvider.overrideWithValue(inbox),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SmsTrackingScreen(),
        ),
      ),
    );
    await settle(tester);
    return inbox;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('a build without READ_SMS says so', (tester) async {
    await pump(tester, _FakeInbox(const [], isDeclared: false));
    expect(find.text('Not in this version'), findsOneWidget);
    expect(find.text('Track bank SMS'), findsNothing);
    await unmount(tester);
  });

  testWidgets('shows only the tracked banks\' messages, payments first', (
    tester,
  ) async {
    await pump(tester, _FakeInbox([hdfcDebit, hdfcOtp, federalDebit, shop]));

    expect(find.text('SHARMA GENERAL STORE'), findsOneWidget);
    expect(find.text('SNAPMINT FIN'), findsOneWidget);
    expect(find.textContaining('SWIGGY'), findsNothing,
        reason: 'a shop is not on the bank list');
    // The OTP is counted, not listed, until asked for.
    expect(find.textContaining('OTP for login'), findsNothing);
    expect(find.text('1 skipped — an OTP, offer or balance alert'),
        findsOneWidget);

    await tester.tap(find.text('1 skipped — an OTP, offer or balance alert'));
    await settle(tester);
    expect(find.textContaining('OTP for login'), findsOneWidget);

    // Narrow to one bank.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Federal Bank'));
    await settle(tester);
    expect(find.text('SHARMA GENERAL STORE'), findsNothing);
    expect(find.text('SNAPMINT FIN'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('one message can be added to Review Inbox by hand', (
    tester,
  ) async {
    await pump(tester, _FakeInbox([hdfcDebit]));
    expect(find.text('In inbox'), findsNothing);

    await tester.tap(find.byTooltip('Add to Review Inbox'));
    await settle(tester);

    expect(find.text('In inbox'), findsOneWidget);
    final cards = await tester.runAsync(() => db.watchPendingCards().first);
    expect(cards, hasLength(1));
    expect(cards!.single.parsedMerchant, 'SHARMA GENERAL STORE');
    await unmount(tester);
  });

  testWidgets('switching tracking on asks for SMS, then reads 30 days', (
    tester,
  ) async {
    final inbox = await pump(
      tester,
      _FakeInbox([hdfcDebit, federalDebit], state: PermissionState.denied),
    );
    await tester.tap(find.text('Track bank SMS'));
    // Permission, the scan, then the list reloading: a longer chain.
    await settle(tester, rounds: 12);

    expect(inbox.asked, 1);
    final settings = await tester.runAsync(db.getSettings);
    expect(settings!.messageCaptureEnabled, isTrue);
    final cards = await tester.runAsync(() => db.watchPendingCards().first);
    expect(cards, hasLength(2), reason: 'the first scan reads the last 30 days');
    expect(find.text('2 new payments in Review Inbox'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('another bank found in the inbox can be tracked in one tap', (
    tester,
  ) async {
    final newBank = sms(
      'Rs.500.00 debited from A/c XX7788 to AMAZON PAY on 20-11-26. '
      'Ref no 554433221100. Avl Bal Rs.2,000.00',
      'VM-CANBNK-S',
      hoursAgo: 30,
    );
    await pump(
      tester,
      _FakeInbox(
        [hdfcDebit, newBank],
        others: [
          InboxSender(
            sender: 'VM-CANBNK-S',
            count: 4,
            last: newBank.receivedAt,
            samples: [newBank.body],
          ),
          // Writes often, but never a payment: not suggested.
          InboxSender(
            sender: 'AX-SWIGGY-S',
            count: 12,
            last: now,
            samples: const ['Your order is on the way!'],
          ),
        ],
      ),
    );
    // Section labels are upper-cased.
    expect(find.text('FOUND IN YOUR MESSAGES'), findsOneWidget);
    expect(find.text('VM-CANBNK-S'), findsOneWidget);
    expect(find.text('4 messages · looks like payments'), findsOneWidget);
    expect(find.textContaining('AX-SWIGGY-S'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Track'));
    await settle(tester);

    final rules = await tester.runAsync(() => db.watchSenderRules().first);
    expect(rules!.map((r) => r.senderPattern), contains('CANBNK'));
    expect(find.text('FOUND IN YOUR MESSAGES'), findsNothing);
    expect(find.text('AMAZON PAY'), findsOneWidget,
        reason: 'its messages join the list straight away');
    await unmount(tester);
  });

  testWidgets('a sender can be added by its ID', (tester) async {
    await pump(tester, _FakeInbox(const []));
    await tester.tap(find.text('Add a sender'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('sms-sender-id')), '9876543210');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);
    expect(find.text('Enter the sender ID, like AX-FEDBNK-S'), findsOneWidget,
        reason: "a person's number is never tracked");

    await tester.enterText(find.byKey(const Key('sms-sender-id')), 'ad-ubinbk-s');
    await tester.enterText(find.byKey(const Key('sms-sender-bank')), 'Union Bank');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    final rules = await tester.runAsync(() => db.watchSenderRules().first);
    final union = rules!.firstWhere((r) => r.senderPattern == 'UBINBK');
    expect(union.bankName, 'Union Bank');
    expect(union.enabled, isTrue);
    expect(find.text('Union Bank'), findsOneWidget);
    await unmount(tester);
  });

  test('a card made by hand is a normal pending card', () async {
    final id = await db.ingestMessage(
      hdfcDebit,
      const MessageParser().parse(hdfcDebit) as ParsedMessage,
    );
    final status = await db.captureStatusOf([hdfcDebit]);
    expect(id, isNotNull);
    expect(status.values.single, PendingStatus.pending);
  });
}

/// Lets real futures (the database, the fake inbox) finish between frames —
/// see test/smoke_test.dart: no `pumpAndSettle` with live streams.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    // Moves the fake clock too: drift's transactions wait on timers.
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 400));
}
