import 'package:flutter/foundation.dart';
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
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(_budgetChannel);
        await android.createNotificationChannel(_reminderChannel);
        await android.createNotificationChannel(_captureChannel);
      }
      _ready = true;
    } catch (e, s) {
      // A notification failure must never take the app down.
      debugPrint('NotificationService.init failed: $e\n$s');
    }
  }

  /// Android 13+ requires an explicit runtime grant.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
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
  Future<bool> _show(int id, String title, String body,
      AndroidNotificationChannel channel) async {
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
    final end = DateTime(now.year, now.month + 1)
        .subtract(const Duration(milliseconds: 1));
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
          body: 'You have spent ${MoneyFormat.symbol(spent)} of '
              '${MoneyFormat.symbol(b.amount)}.',
        );
      } else if (pct >= b.alertThresholdPct / 100) {
        await _fireOnce(
          categoryId: b.categoryId,
          periodKey: periodKey,
          level: AlertLevel.threshold,
          id: 200000 + b.categoryId,
          title: '${category.name} budget almost used',
          body: '${(pct * 100).round()}% of ${MoneyFormat.symbol(b.amount)} spent.',
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

      final amount =
          r.amount == null ? '' : ' — ${MoneyFormat.symbol(r.amount!)}';
      final verb = r.direction == ReminderDirection.pay ? 'Pay' : 'Collect';

      try {
        await _plugin.zonedSchedule(
          id: _reminderId(r.id),
          title: '$verb: ${r.title}',
          body: 'Due ${_dayLabel(r.dueDate)}$amount. Nothing has been posted — '
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
    } catch (_) {/* already gone */}
  }

  Future<void> cancelReminder(int reminderId) => _cancel(_reminderId(reminderId));

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
}
