import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/database.dart';
import '../../data/tables.dart';
import '../money.dart';

/// Local notifications only. Nothing leaves the device.
class NotificationService {
  NotificationService(this._db);

  final AppDatabase _db;
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  static const _budgetChannel = AndroidNotificationChannel(
    'budgets',
    'Budget alerts',
    description: 'Warns when a category nears or passes its limit.',
    importance: Importance.high,
  );

  static const _reminderChannel = AndroidNotificationChannel(
    'reminders',
    'Payment reminders',
    description: 'Reminds you about a planned payment on its due date.',
    importance: Importance.high,
  );

  static const _captureChannel = AndroidNotificationChannel(
    'capture',
    'Detected transactions',
    description: 'A bank message was detected and is waiting for review.',
    importance: Importance.defaultImportance,
  );

  static const _autoChannel = AndroidNotificationChannel(
    'auto',
    'Auto expenses & income',
    description: 'Warns ahead of an auto-post, and confirms once one lands.',
    importance: Importance.high,
  );

  static const _expenseNudgeChannel = AndroidNotificationChannel(
    'expense_nudge',
    'Daily expense reminder',
    description:
        "A daily nudge to log today's spending — not tied to any "
        'specific bill.',
    importance: Importance.defaultImportance,
  );

  static const _quickAddChannel = AndroidNotificationChannel(
    'quick_add',
    'Quick add shortcut',
    description:
        'A standing, silent notification with "Add expense" / "Add '
        'income" buttons.',
    importance: Importance.low,
  );

  static const _quickAddExpenseAction = 'quick_add_expense';
  static const _quickAddIncomeAction = 'quick_add_income';

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      // The app is India-first. Period boundaries and scheduled reminders must
      // agree with the user's wall clock, not UTC.
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        // Neither quick-add action sets `showsUserInterface`, so Android
        // never brings the app to the foreground — the reply is delivered
        // to `_quickAddBackgroundResponse` on its own background isolate.
        // `onDidReceiveNotificationResponse` (foreground) has nothing to
        // handle right now — nothing else in the app defines an action.
        onDidReceiveBackgroundNotificationResponse: _quickAddBackgroundResponse,
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(_budgetChannel);
        await android.createNotificationChannel(_reminderChannel);
        await android.createNotificationChannel(_captureChannel);
        await android.createNotificationChannel(_autoChannel);
        await android.createNotificationChannel(_expenseNudgeChannel);
        await android.createNotificationChannel(_quickAddChannel);
      }
      _ready = true;
    } catch (e, s) {
      // A notification failure must never take the app down.
      debugPrint('NotificationService.init failed: $e\n$s');
    }
  }

  /// Android 13+ requires an explicit runtime grant.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
  }

  NotificationDetails _details(AndroidNotificationChannel c) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          c.id,
          c.name,
          channelDescription: c.description,
          importance: c.importance,
          priority: Priority.high,
        ),
      );

  /// Returns whether the notification was actually delivered. Callers that
  /// "claim" a one-shot alert must release the claim when this returns false,
  /// or the alert is lost for the rest of the period.
  Future<bool> _show(
    int id,
    String title,
    String body,
    AndroidNotificationChannel channel,
  ) async {
    if (!_ready) return false;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(channel),
      );
      return true;
    } catch (e) {
      debugPrint('notification show failed: $e');
      return false;
    }
  }

  // ── Budgets ───────────────────────────────────────────────────────────────

  /// Fires **at most once per category per period per level**, enforced by the
  /// `budget_alerts` table — otherwise every purchase would notify.
  ///
  /// Only expenses count. Transfers and person movements are excluded upstream
  /// by `watchSpendByCategory`, which is what makes these numbers trustworthy.
  Future<void> checkBudgets() async {
    final settings = await _db.getSettings();
    if (!settings.notificationsEnabled) return;

    // Bail out BEFORE claiming anything. `checkBudgets` fires from a provider
    // listener that can run before `init()` completes; claiming an alert we
    // cannot show would silence it for the whole period.
    if (!_ready) return;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(
      now.year,
      now.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    final periodKey = AppDatabase.periodKeyOf(now);

    final budgets = await _db.watchBudgets().first;
    if (budgets.isEmpty) return;
    final spend = await _db.watchSpendByCategory(start, end).first;

    for (final b in budgets) {
      if (b.amount.isZero) continue;
      final spent = spend[b.categoryId] ?? const Money.zero();
      final pct = spent.paise / b.amount.paise;

      final category = await _db.categoryById(b.categoryId);
      if (category == null) continue;

      if (pct > 1.0) {
        await _fireOnce(
          categoryId: b.categoryId,
          periodKey: periodKey,
          level: AlertLevel.overspent,
          id: 100000 + b.categoryId,
          title: 'Overspent on ${category.name}',
          body:
              'You have spent ${MoneyFormat.symbol(spent)} of '
              '${MoneyFormat.symbol(b.amount)}.',
        );
      } else if (pct >= b.alertThresholdPct / 100) {
        await _fireOnce(
          categoryId: b.categoryId,
          periodKey: periodKey,
          level: AlertLevel.threshold,
          id: 200000 + b.categoryId,
          title: '${category.name} budget almost used',
          body:
              '${(pct * 100).round()}% of ${MoneyFormat.symbol(b.amount)} spent.',
        );
      }
    }
  }

  /// Claim the one-shot alert, show it, and **release the claim if the show
  /// failed**. Without the release, a single failed delivery would silence this
  /// alert for the entire period.
  Future<void> _fireOnce({
    required int categoryId,
    required String periodKey,
    required AlertLevel level,
    required int id,
    required String title,
    required String body,
  }) async {
    final fresh = await _db.claimBudgetAlert(
      categoryId: categoryId,
      periodKey: periodKey,
      level: level,
    );
    if (!fresh) return;

    final shown = await _show(id, title, body, _budgetChannel);
    if (!shown) {
      await _db.releaseBudgetAlert(
        categoryId: categoryId,
        periodKey: periodKey,
        level: level,
      );
    }
  }

  // ── Reminders ─────────────────────────────────────────────────────────────

  /// Reschedules every open reminder. Safe to call on every app start.
  Future<void> syncReminders() async {
    if (!_ready) return;
    final settings = await _db.getSettings();
    final all = await _db.watchReminders().first;

    for (final r in all) {
      await _cancel(_reminderId(r.id));
      if (!settings.notificationsEnabled) continue;
      if (r.status != ReminderStatus.open) continue;

      final fireAt = _fireTimeFor(r);
      if (fireAt == null) continue;

      final amount = r.amount == null
          ? ''
          : ' — ${MoneyFormat.symbol(r.amount!)}';
      final verb = r.direction == ReminderDirection.pay ? 'Pay' : 'Collect';

      try {
        await _plugin.zonedSchedule(
          id: _reminderId(r.id),
          title: '$verb: ${r.title}',
          body:
              'Due ${_dayLabel(r.dueDate)}$amount. Nothing has been posted — '
              'confirm it in the app.',
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: _details(_reminderChannel),
          // Inexact avoids needing SCHEDULE_EXACT_ALARM. A bill reminder does
          // not need second precision.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('reminder schedule failed: $e');
      }
    }
  }

  /// When a reminder should actually buzz, or `null` if it is genuinely past.
  ///
  /// `dueDate` is a calendar day, i.e. midnight. Naively firing at
  /// `dueDate - notifyDaysBefore` means a reminder created for **today** has a
  /// fire time in the past and is silently dropped — you would never be told
  /// about the bill due today. Fire it shortly, and prefer a civilised
  /// [_reminderHour] on future days rather than midnight.
  static const _reminderHour = 9;

  static DateTime? _fireTimeFor(ReminderRow r) {
    final now = DateTime.now();
    final day = r.dueDate.subtract(Duration(days: r.notifyDaysBefore));
    final at = DateTime(day.year, day.month, day.day, _reminderHour);

    if (at.isAfter(now)) return at;

    // Fire time already passed. If the due date itself has not, nudge it to
    // just after now so a same-day reminder still arrives.
    final endOfDueDay = DateTime(
      r.dueDate.year,
      r.dueDate.month,
      r.dueDate.day,
      23,
      59,
    );
    if (endOfDueDay.isAfter(now)) {
      return now.add(const Duration(minutes: 1));
    }
    return null; // genuinely overdue — the Calendar shows it instead
  }

  static int _reminderId(int id) => 300000 + id;

  Future<void> _cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      /* already gone */
    }
  }

  Future<void> cancelReminder(int reminderId) =>
      _cancel(_reminderId(reminderId));

  static String _dayLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  // ── Capture ───────────────────────────────────────────────────────────────

  Future<void> notifyDetected(int count) async {
    if (count <= 0) return;
    final settings = await _db.getSettings();
    if (!settings.notificationsEnabled) return;
    await _show(
      400000,
      count == 1 ? '1 transaction detected' : '$count transactions detected',
      'Open the app to review and categorise.',
      _captureChannel,
    );
  }

  // ── Recurring rules (Auto) ────────────────────────────────────────────────

  /// Reschedules the "coming up" alert for every active rule. Safe to call on
  /// every app start/resume, and right after [AppDatabase.runDueRecurringRules]
  /// advances each rule's `nextDueDate` — this always reads that fresh value,
  /// so it never warns about an occurrence that already posted.
  Future<void> syncRecurringNotifications() async {
    if (!_ready) return;
    final settings = await _db.getSettings();
    final rules = await _db.watchRecurringRules().first;

    for (final r in rules) {
      await _cancel(_recurringId(r.id));
      if (!settings.notificationsEnabled || !r.isActive) continue;

      final fireAt = _recurringFireTimeFor(r);
      if (fireAt == null) continue;

      final account = await _db.watchAccount(r.accountId).first;
      final accountName = account?.name ?? 'your account';
      final isExpense = r.kind == CategoryKind.expense;
      final title = isExpense
          ? '${r.name}: auto-pay coming up'
          : '${r.name}: expected soon';
      final body = isExpense
          ? '${MoneyFormat.symbol(r.amount)} will be auto-deducted from '
                '$accountName on ${_dayLabel(r.nextDueDate)}. Keep that much ready.'
          : '${MoneyFormat.symbol(r.amount)} is expected in $accountName '
                'on ${_dayLabel(r.nextDueDate)}.';

      try {
        await _plugin.zonedSchedule(
          id: _recurringId(r.id),
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: _details(_autoChannel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('recurring rule schedule failed: $e');
      }
    }
  }

  /// Mirrors [_fireTimeFor]: a same-day rule (or one whose warning window has
  /// already passed) still fires shortly rather than silently never firing.
  static DateTime? _recurringFireTimeFor(RecurringRuleRow r) {
    final now = DateTime.now();
    final day = r.nextDueDate.subtract(Duration(days: r.notifyDaysBefore));
    final at = DateTime(day.year, day.month, day.day, _reminderHour);

    if (at.isAfter(now)) return at;

    final endOfDueDay = DateTime(
      r.nextDueDate.year,
      r.nextDueDate.month,
      r.nextDueDate.day,
      23,
      59,
    );
    if (endOfDueDay.isAfter(now)) {
      return now.add(const Duration(minutes: 1));
    }
    return null; // the next run of runDueRecurringRules will post it instead
  }

  static int _recurringId(int id) => 600000 + id;

  /// One-shot confirmation after [AppDatabase.runDueRecurringRules] posts
  /// something — nothing about "auto" should ever land in the ledger silently.
  Future<void> notifyAutoPosted(int count) async {
    if (count <= 0) return;
    final settings = await _db.getSettings();
    if (!settings.notificationsEnabled) return;
    await _show(
      500000,
      count == 1
          ? '1 auto-transaction posted'
          : '$count auto-transactions posted',
      'Open Auto to review what was posted.',
      _autoChannel,
    );
  }

  // ── Expense reminder ─────────────────────────────────────────────────────

  static const _expenseNudgeId = 700000;

  /// A daily repeat at the chosen wall-clock time — [DateTimeComponents.time]
  /// is what makes `zonedSchedule` re-fire every day instead of once. Safe to
  /// call on every app start/resume, same as the other `sync*` methods.
  Future<void> syncExpenseReminder() async {
    if (!_ready) return;
    await _cancel(_expenseNudgeId);

    final settings = await _db.getSettings();
    if (!settings.notificationsEnabled || !settings.expenseReminderEnabled) {
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    var fireAt = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      settings.expenseReminderHour,
      settings.expenseReminderMinute,
    );
    if (fireAt.isBefore(now)) {
      fireAt = fireAt.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        id: _expenseNudgeId,
        title: 'Log today\'s spending',
        body: "A minute now beats reconstructing it from memory later.",
        scheduledDate: fireAt,
        notificationDetails: _details(_expenseNudgeChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('expense reminder schedule failed: $e');
    }
  }

  // ── Quick add ─────────────────────────────────────────────────────────────

  static const _quickAddId = 800000;
  static const _quickAddResultId = 810000;

  /// Shows or cancels the standing "Add expense" / "Add income" notification
  /// to match [Settings.notificationQuickAddEnabled]. Safe to call on every
  /// app start/resume and right after the setting changes, same as the
  /// other `sync*` methods.
  ///
  /// Also gated on [Settings.notificationsEnabled] — the master switch is
  /// what requests the Android 13+ runtime permission in the first place
  /// (see [requestPermission]), so a shortcut nobody granted permission for
  /// would just silently fail to show.
  Future<void> syncQuickAddNotification() async {
    if (!_ready) return;
    final settings = await _db.getSettings();
    if (!settings.notificationsEnabled ||
        !settings.notificationQuickAddEnabled) {
      await _cancel(_quickAddId);
      return;
    }

    try {
      await _plugin.show(
        id: _quickAddId,
        title: 'Quick add',
        body: 'Reply with an amount to log an expense or income.',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _quickAddChannel.id,
            _quickAddChannel.name,
            channelDescription: _quickAddChannel.description,
            importance: _quickAddChannel.importance,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
            // A shortcut, not an alert — stays until the setting is turned
            // back off, and a swipe shouldn't quietly disable the feature.
            ongoing: true,
            autoCancel: false,
            actions: const [
              AndroidNotificationAction(
                _quickAddExpenseAction,
                'Add expense',
                cancelNotification: false,
                inputs: [AndroidNotificationActionInput(label: 'Amount')],
              ),
              AndroidNotificationAction(
                _quickAddIncomeAction,
                'Add income',
                cancelNotification: false,
                inputs: [AndroidNotificationActionInput(label: 'Amount')],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('quick add notification failed: $e');
    }
  }
}

/// The other half of quick add: the user typed an amount into the reply
/// field and hit send. Neither action sets `showsUserInterface`, so Android
/// never brings the app to the foreground for this — it hands the reply to
/// a background isolate instead, which is why this has to be a top-level
/// function (`@pragma('vm:entry-point')` is required by
/// flutter_local_notifications for exactly this case), not a method on
/// [NotificationService]. It builds its own tiny, disposable copy of
/// everything it needs rather than reusing the running app's — there isn't
/// a running app instance to reuse, most of the time this fires.
///
/// Posts with no category — there is no UI to pick one from a reply, so it
/// waits to be categorised from the Transactions list, same as any other
/// transaction. This is the one place in the app that posts money without a
/// human looking at the account/category first; seeing that as *not* what
/// you want next is exactly why `Settings > Quick add from notification`
/// exists as an opt-in.
@pragma('vm:entry-point')
void _quickAddBackgroundResponse(NotificationResponse response) {
  unawaited(_handleQuickAddReply(response));
}

Future<void> _handleQuickAddReply(NotificationResponse response) async {
  final type = switch (response.actionId) {
    NotificationService._quickAddExpenseAction => TxType.expense,
    NotificationService._quickAddIncomeAction => TxType.income,
    _ => null,
  };
  if (type == null) return;

  WidgetsFlutterBinding.ensureInitialized();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  Future<void> result(String body) => plugin.show(
    id: NotificationService._quickAddResultId,
    title: 'Quick add',
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationService._quickAddChannel.id,
        NotificationService._quickAddChannel.name,
        channelDescription: NotificationService._quickAddChannel.description,
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
      ),
    ),
  );

  final amount = Money.tryParse(response.input ?? '');
  if (amount == null || !amount.isPositive) {
    await result("Couldn't read that as an amount — nothing was added.");
    return;
  }

  final db = AppDatabase();
  try {
    final accountId = await db.resolveQuickAddAccountId();
    if (accountId == null) {
      await result('No account to post to — nothing was added.');
      return;
    }
    await db.addTransaction(
      type: type,
      amount: amount,
      accountId: accountId,
      date: DateTime.now(),
    );
    final account = await db.watchAccount(accountId).first;
    await result(
      '${type == TxType.expense ? 'Expense' : 'Income'} of '
      '${MoneyFormat.symbol(amount)} added to ${account?.name ?? 'your account'}.',
    );
  } catch (e) {
    await result("Couldn't save that — nothing was added.");
    debugPrint('quick add background insert failed: $e');
  } finally {
    await db.close();
  }
}
