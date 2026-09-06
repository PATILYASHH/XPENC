import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/app_info.dart';
import 'core/branding/brand_mark.dart';
import 'core/money.dart';
import 'core/routing/app_router.dart';
import 'core/security/screen_security.dart';
import 'core/security/unlock_method.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/error_view.dart';
import 'core/widgets/money_text.dart';
import 'data/providers.dart';
import 'features/message_capture/parser/bank_message.dart';
import 'features/message_capture/share_intake.dart';
import 'features/security/lock_screen.dart';

class XpencApp extends ConsumerStatefulWidget {
  const XpencApp({super.key});

  @override
  ConsumerState<XpencApp> createState() => _XpencAppState();
}

class _XpencAppState extends ConsumerState<XpencApp>
    with WidgetsBindingObserver {
  /// Whether the current build has seen a real settings row yet — until it
  /// has, we don't know if a passcode is set, so a neutral splash shows
  /// instead of risking a flash of real data before the lock engages.
  bool _passcodeKnown = false;
  bool _locked = false;

  /// When the app was last backgrounded — the anchor a non-zero
  /// [pinTimeoutMinutesProvider] is measured from on the next resume. Null
  /// whenever the app is in the foreground.
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStart());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onStart() async {
    // If the database can't open there is nothing to notify about or scan for.
    final ready = await ref.read(databaseReadyProvider.future).catchError((_) {
      return false;
    });
    if (!ready || !mounted) return;

    // Associate the backup folder right away rather than the first time
    // something is actually backed up — see `BackupService.ensureBackupFolderReady`.
    unawaited(ref.read(backupServiceProvider).ensureBackupFolderReady());

    await _gateOnboarding();
    if (!mounted) return;

    final homeWidget = ref.read(homeWidgetServiceProvider);
    homeWidget.init();
    ref.read(shareIntakeServiceProvider).init(_handleShareResult);
    final netWorth = await ref.read(netWorthProvider.future).catchError((_) {
      return const Money.zero();
    });
    if (!mounted) return;
    await homeWidget.updateBalance(netWorth);
    await homeWidget.updateBudgetSummary(ref.read(widgetBudgetSummaryProvider));
    final monthSummary = ref.read(widgetMonthSummaryProvider);
    await homeWidget.updateMonthSummary(
      monthSummary.income,
      monthSummary.expense,
    );

    final notifications = ref.read(notificationServiceProvider);
    await notifications.init();
    await notifications.syncReminders();
    await notifications.syncCreditCardReminders();
    await notifications.syncExpenseReminder();
    await notifications.syncQuickAddNotification();

    // `checkBudgets` no-ops before `init()` completes (it must not claim an
    // alert it cannot deliver). The ledger listener may already have fired by
    // now, so run it once here — the claim table keeps it to one alert.
    await notifications.checkBudgets();

    await _runRecurring();
    await _scanMessages();
    await _runAutoBackup();
  }

  /// Posts anything due, then reschedules the "coming up" alerts against
  /// whatever `nextDueDate` each rule now has. There is no background
  /// service — like message capture, this only ever runs while the app is
  /// open, so it also runs again on every resume, not just cold start.
  Future<void> _runRecurring() async {
    final posted = await ref.read(dbProvider).runDueRecurringRules();
    if (!mounted) return;
    final notifications = ref.read(notificationServiceProvider);
    await notifications.syncRecurringNotifications();
    // Recomputed fresh from today on every call, so a long-lived session
    // that resumes across a month boundary still points at the right due
    // date, not whatever was true at cold start (GitHub #91).
    await notifications.syncCreditCardReminders();
    if (posted > 0) await notifications.notifyAutoPosted(posted);
  }

  /// Send a first-time user through onboarding before anything else.
  Future<void> _gateOnboarding() async {
    try {
      final settings = await ref.read(dbProvider).getSettings();
      if (!settings.onboarded && mounted) {
        appRouter.go('/onboarding');
      }
    } catch (_) {
      // A settings read failure is already surfaced by databaseReadyProvider.
    }
  }

  /// The spec is "when the user opens the app, they see cards". So we scan on
  /// resume rather than running a background receiver.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeLockAfterTimeout();
      _pausedAt = null;
      _runRecurring();
      _scanMessages();
      _runAutoBackup();
      // Restores the shortcut if the system cleared it under memory
      // pressure while `ongoing: true` normally keeps a swipe from doing so.
      ref.read(notificationServiceProvider).syncQuickAddNotification();
    }
    // `_passcodeKnown` guards a launch race: if the very first backgrounding
    // somehow lands before the initial settings read, there is nothing yet
    // to decide with.
    if (state == AppLifecycleState.paused && _passcodeKnown) {
      _pausedAt = DateTime.now();
      final settingsRow = ref.read(settingsProvider).valueOrNull;
      // Whichever method is active (GitHub #104) — not just a PIN — governs
      // the immediate-lock-on-background decision.
      final hasCredential =
          settingsRow != null && hasUnlockCredential(settingsRow);
      // A zero timeout ("Immediately", the default) locks right here rather
      // than waiting for resume — otherwise the very next resume, however
      // soon, would still show real data for one frame first.
      final immediate =
          (ref.read(settingsProvider).valueOrNull?.pinTimeoutMinutes ?? 0) == 0;
      if (hasCredential && immediate) setState(() => _locked = true);
    }
  }

  /// A non-zero pin timeout defers the lock decision to here, judged against
  /// how long the app actually sat backgrounded — see GitHub #60. The
  /// immediate case is already handled at pause time, above.
  void _maybeLockAfterTimeout() {
    if (_locked || !_passcodeKnown) return;
    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null || !hasUnlockCredential(settings)) return;
    final minutes = settings.pinTimeoutMinutes;
    final pausedAt = _pausedAt;
    if (minutes == 0 || pausedAt == null) return;
    if (DateTime.now().difference(pausedAt) >= Duration(minutes: minutes)) {
      setState(() => _locked = true);
    }
  }

  /// One-time move of pre-existing backups into the new durable folder, then
  /// a due-backup check. Like recurring rules and message capture, there is
  /// no background service — this only ever runs while the app is open, so
  /// it also runs again on every resume, not just cold start.
  Future<void> _runAutoBackup() async {
    final service = ref.read(backupServiceProvider);
    await service.migrateLegacyBackups();
    await service.runAutoBackupIfDue();
  }

  Future<void> _scanMessages() async {
    final result = await ref.read(captureServiceProvider).scan();
    if (!result.didRun) return;

    // Only ping about cards that still need the user. Auto-filled ones already
    // posted and are visible on the dashboard.
    final needsReview = result.ingested - result.autoFilled;
    if (needsReview > 0) {
      await ref.read(notificationServiceProvider).notifyDetected(needsReview);
    }
  }

  /// The user just shared a message into XPENC from another app — see
  /// `ShareIntakeService`. Ingested lands straight in the Review Inbox,
  /// since that is exactly where "filter it and add as expense or income"
  /// already happens; anything else gets a plain-language reason instead of
  /// silently doing nothing with a message the user deliberately picked.
  void _handleShareResult(ShareIntakeResult result) {
    switch (result) {
      case ShareIntakeIngested():
        appRouter.go('/inbox');
      case ShareIntakeDuplicate():
        showAppSnackBar('Already in your Review Inbox');
      case ShareIntakeRejected(:final reason, :final recognizedText):
        showAppSnackBar(
          "Couldn't find a transaction in that message"
          '${_rejectReasonHint(reason)}',
          action: recognizedText == null
              ? null
              : SnackBarAction(
                  label: 'View text',
                  onPressed: () => showRecognizedTextDialog(recognizedText),
                ),
        );
    }
  }

  String _rejectReasonHint(RejectReason reason) => switch (reason) {
    RejectReason.otp => ' — looks like an OTP.',
    RejectReason.promotional => ' — looks promotional.',
    RejectReason.balanceOnly => ' — no transaction, just a balance.',
    RejectReason.declined => ' — the payment was declined.',
    RejectReason.noAmount => ' — no amount found.',
    RejectReason.noDirection || RejectReason.notATransaction => '.',
  };

  @override
  Widget build(BuildContext context) {
    // Budgets are re-checked whenever the ledger changes. `claimBudgetAlert`
    // makes each alert fire at most once per category, per period, per level.
    ref.listen(allTransactionsProvider, (_, next) {
      if (next.hasValue) {
        ref.read(notificationServiceProvider).checkBudgets();
      }
    });
    // Keeps the home-screen widgets live while the app is open — neither
    // has any other way to learn the ledger (or budgets) changed.
    ref.listen(netWorthProvider, (_, next) {
      if (next.hasValue) {
        ref.read(homeWidgetServiceProvider).updateBalance(next.value!);
      }
    });
    ref.listen(widgetBudgetSummaryProvider, (_, next) {
      ref.read(homeWidgetServiceProvider).updateBudgetSummary(next);
    });
    ref.listen(widgetMonthSummaryProvider, (_, next) {
      ref
          .read(homeWidgetServiceProvider)
          .updateMonthSummary(next.income, next.expense);
    });

    final ready = ref.watch(databaseReadyProvider);
    final preset = ref.watch(themePresetProvider);
    final fontFamily = ref.watch(fontFamilyProvider);
    final fontWeightDelta = ref.watch(fontWeightDeltaProvider);
    final fontScalePercent = ref.watch(fontScalePercentProvider);

    // Derived once per app run, the instant settings first loads — not with
    // `setState`, since `ref.watch` below already schedules the rebuild that
    // picks this up; see the doc on `_passcodeKnown`.
    final settingsRow = ref.watch(settingsProvider).valueOrNull;
    if (settingsRow != null && !_passcodeKnown) {
      _passcodeKnown = true;
      _locked = hasUnlockCredential(settingsRow);
    }

    // Point the global formatters at the chosen currency before anything paints,
    // and broadcast it via CurrencyScope so every amount reformats the instant
    // it changes — even a screen kept alive on another tab.
    final currency = ref.watch(currencyProvider);
    final showSymbol = ref.watch(showCurrencySymbolProvider);
    MoneyFormat.configure(currency: currency, showSymbol: showSymbol);
    final hideAmounts = ref.watch(hideAmountsProvider);
    final extraBottomInset = ref.watch(extraBottomInsetProvider);

    // Fire-and-forget: a platform-channel call, not something the frame
    // waits on. ScreenSecurity itself no-ops if nothing actually changed.
    unawaited(ScreenSecurity.apply(ref.watch(preventScreenshotsProvider)));

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      // A preset that forces one brightness stores the same palette in both
      // slots, so `themeMode` alone decides which of these two is used.
      theme: AppTheme.of(
        preset.lightPalette,
        preset.shape,
        fontFamily: fontFamily,
        fontWeightDelta: fontWeightDelta,
      ),
      darkTheme: AppTheme.of(
        preset.darkPalette,
        preset.shape,
        fontFamily: fontFamily,
        fontWeightDelta: fontWeightDelta,
      ),
      themeMode: preset.mode,
      routerConfig: appRouter,
      // A failed database must never look like "still loading".
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          // Applied here rather than baked into the theme's text styles, so
          // it scales every widget's text — third-party ones included — not
          // just the roles `AppTheme` sets a `fontSize` on. `extraBottomInset`
          // (GitHub #78) rides along the same way: added to `padding`/
          // `viewPadding` once, here, so every `SafeArea` in the app — the
          // bottom nav bar, the lock screen's keypad, any bottom sheet —
          // picks up the extra clearance automatically, with no per-screen
          // changes.
          data: mq.copyWith(
            textScaler: TextScaler.linear(fontScalePercent / 100),
            padding: mq.padding.copyWith(
              bottom: mq.padding.bottom + extraBottomInset,
            ),
            viewPadding: mq.viewPadding.copyWith(
              bottom: mq.viewPadding.bottom + extraBottomInset,
            ),
          ),
          child: CurrencyScope(
            currency: currency,
            showSymbol: showSymbol,
            child: AmountVisibilityScope(
              hidden: hideAmounts,
              child: switch (ready) {
                AsyncError(:final error) => _FatalError(
                  error: error,
                  onRetry: () => ref.invalidate(databaseReadyProvider),
                ),
                // The router's subtree stays mounted underneath even while
                // locked — only stacked, opaque `LockScreen` sits on top of
                // it — or every relock (immediate, on every backgrounding)
                // would silently drop whatever the user was in the middle of
                // doing: a half-typed transaction, a scroll position,
                // anything not yet saved.
                AsyncData() =>
                  !_passcodeKnown
                      ? const _LaunchSplash()
                      : Stack(
                          children: [
                            ?child,
                            // Opt-in (GitHub #90) — someone who deliberately
                            // leaves screenshot-blocking off made that choice
                            // on purpose and shouldn't be nagged about it
                            // unless they ask to be. Never over the lock
                            // screen either: nothing sensitive is on it.
                            if (!_locked &&
                                !ref.watch(preventScreenshotsProvider) &&
                                ref.watch(screenshotReminderEnabledProvider))
                              const Positioned(
                                left: 12,
                                bottom: 12,
                                child: _ScreenshotAllowedTag(),
                              ),
                            if (_locked)
                              Positioned.fill(
                                child: LockScreen(
                                  onUnlocked: () =>
                                      setState(() => _locked = false),
                                ),
                              ),
                          ],
                        ),
                _ => child ?? const SizedBox.shrink(),
              },
            ),
          ),
        );
      },
    );
  }
}

/// A small, easy-to-ignore reminder that screenshots aren't blocked right
/// now — opt-in via Settings → Security (GitHub #90), for anyone who wants
/// the nudge after forgetting to turn "Block screenshots" back on. Tapping
/// it jumps straight to that setting.
class _ScreenshotAllowedTag extends StatelessWidget {
  const _ScreenshotAllowedTag();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: GestureDetector(
        onTap: () => appRouter.push('/more/settings'),
        child: Text(
          'Screenshots allowed',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

/// The instant between the database opening and settings' first emission —
/// too short to be a real loading screen, just long enough that showing real
/// content here risks a flash of data before a passcode lock can engage.
class _LaunchSplash extends StatelessWidget {
  const _LaunchSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: BrandMark(size: 56)));
  }
}

class _FatalError extends StatelessWidget {
  const _FatalError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ErrorView(
          title: "Couldn't open your data",
          message:
              'The app could not open its database, so nothing can be shown. '
              'Your saved data is not lost.',
          detail: error.toString(),
          onRetry: onRetry,
        ),
      ),
    );
  }
}
