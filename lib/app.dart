import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/app_info.dart';
import 'core/branding/brand_mark.dart';
import 'core/layout/desktop.dart';
import 'core/money.dart';
import 'core/platform/browser_storage.dart';
import 'core/routing/app_router.dart';
import 'core/security/screen_security.dart';
import 'core/security/unlock_method.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_preset.dart';
import 'core/week_start.dart';
import 'core/widgets/app_surfaces.dart';
import 'core/widgets/error_view.dart';
import 'core/widgets/money_text.dart';
import 'data/modes_db.dart';
import 'data/providers.dart';
import 'core/connector/connector_platform.dart';
import 'core/connector/inbox/connector_inbox.dart' show PendingBackup;
import 'core/platform/platform_features.dart';
import 'features/connector/connector_controller.dart';
import 'features/connector/connector_inbox_runner.dart';
import 'features/message_capture/parser/bank_message.dart';
import 'features/message_capture/share_intake.dart';
import 'features/settings/language_pack_intake.dart';
import 'core/l10n/language_pack.dart';
import 'core/l10n/pack_store.dart';
import 'features/persons/shared_entries.dart';
import 'features/security/lock_screen.dart';
import 'core/l10n/l10n.dart';

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

  /// The interface language whose table is loaded (GitHub #191) — null
  /// until the first one is, which keeps the splash up so nothing paints
  /// in English first and then switches.
  String? _language;

  /// The language being loaded right now, so a rebuild mid-load doesn't
  /// start a second load — and [_languageLoad], that load.
  String? _loadingLanguage;
  Future<void>? _languageLoad;

  /// Loads [code]'s table when it isn't the one showing. After a switch
  /// (not the first load) every widget redraws — `tr` is read at build
  /// time, and not every widget would rebuild on its own. Completes once
  /// [code] is the language showing.
  Future<void> _ensureLanguage(String code) {
    if (code == _language) return Future.value();
    if (code == _loadingLanguage) return _languageLoad ?? Future.value();
    _loadingLanguage = code;
    return _languageLoad = L10n.load(code).then((_) {
      if (!mounted || _loadingLanguage != code) return;
      final switched = _language != null;
      setState(() {
        _language = code;
        _loadingLanguage = null;
      });
      if (switched) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => rebuildAllWidgets(),
        );
      }
    });
  }

  /// Following the phone's language, a change to it in the phone's
  /// settings shows up the next time XPENC is opened.
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted) setState(() {});
  }

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
    await _checkConnectorInbox();
    if (!mounted) return;
    // After the inbox: a backup taken in may have brought shared entries
    // the merge should see. Quiet when there's no Connector.
    if (PlatformFeatures.connectorFriendsApp) {
      ref
          .read(sharedEntriesProvider.notifier)
          .onResume()
          .catchError((Object _) {})
          .ignore();
    }

    final homeWidget = ref.read(homeWidgetServiceProvider);
    homeWidget.init();
    ref
        .read(shareIntakeServiceProvider)
        .init(_handleShareResult, onFile: _handleOpenedFile);
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
    // A planned mode (a trip) starts on its first day and ends after its
    // last — checked on the same launch/resume beat.
    final db = ref.read(dbProvider);
    final sync = await db.syncModeSchedule(DateTime.now());
    for (final id in sync.ended) {
      final mode = await db.modeById(id);
      if (mode == null) continue;
      showAppSnackBar(
        tr('{0} has ended', [mode.name]),
        action: SnackBarAction(
          label: tr('Summary'),
          onPressed: () => appRouter.push('/mode/$id/summary'),
        ),
      );
    }
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
      } else {
        // Only once there's a ledger worth keeping — Firefox asks the user,
        // and a prompt before the first screen explains nothing.
        unawaited(requestPersistentStorage());
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
      // A backup Connector pulled meanwhile goes in first, so recurring
      // rules and the auto-backup work on the data that's current.
      _checkConnectorInbox().whenComplete(() {
        if (!mounted) return;
        _runRecurring();
        _scanMessages();
        _runAutoBackup();
      });
      // Entries friends shared (and answers to this phone's), through
      // Connector — read again, and Connector asked for a fresh round.
      if (PlatformFeatures.connectorFriendsApp) {
        ref
            .read(sharedEntriesProvider.notifier)
            .onResume()
            .catchError((Object _) {})
            .ignore();
      }
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

  /// A backup "Not now" was said to, this session — not asked about again
  /// until it changes or the app restarts.
  String? _dismissedInboxSha;

  /// Asked for while locked: asked once unlocked instead.
  PendingBackup? _askWhenUnlocked;

  /// Takes in a backup the Connector app pulled from another device — by
  /// itself when nothing here can be lost, after asking otherwise (see
  /// `ConnectorInboxRunner`). Android only; quiet when there's nothing.
  Future<void> _checkConnectorInbox() async {
    if (!PlatformFeatures.connectorHandoff) return;
    try {
      final settings = await ref.read(dbProvider).getSettings();
      if (!settings.onboarded) return;
      final runner = ref.read(connectorInboxRunnerProvider);
      switch (await runner.check(dismissedSha: _dismissedInboxSha)) {
        case InboxApplied(:final backup):
          announceTakenIn(backup);
        case InboxNeedsAnswer(:final backup):
          if (_locked) {
            _askWhenUnlocked = backup;
          } else {
            await _answerInbox(backup);
          }
        case InboxNothing():
          break;
      }
    } catch (e) {
      showAppSnackBar(tr("Couldn't take in Connector's backup: {0}", [e]));
    }
  }

  Future<void> _answerInbox(PendingBackup backup) async {
    if (!await askToTakeIn(backup)) {
      _dismissedInboxSha = backup.sha;
      return;
    }
    try {
      await ref.read(connectorInboxRunnerProvider).apply(backup);
      announceTakenIn(backup);
    } catch (e) {
      showAppSnackBar(tr("Couldn't take in the backup: {0}", [e]));
    }
  }

  void _unlocked() {
    setState(() => _locked = false);
    final waiting = _askWhenUnlocked;
    _askWhenUnlocked = null;
    if (waiting != null) _answerInbox(waiting);
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

  /// The "new event" trigger for [AutoBackupFrequency.onChange] (GitHub
  /// #132): fires on every ledger add, edit or delete. Marks the change,
  /// then leaves the actual due-or-not call to `runAutoBackupIfDue` — the
  /// same cooldown check `_runAutoBackup` uses on start/resume — so several
  /// changes inside the cooldown window coalesce into the one backup taken
  /// once it elapses, and every other schedule (which this never marks as
  /// pending) simply no-ops here.
  Future<void> _onLedgerChanged() async {
    final db = ref.read(dbProvider);
    await db.markLedgerChanged();
    await ref.read(backupServiceProvider).runAutoBackupIfDue();
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
      case ShareIntakeReading():
        showAppSnackBar(tr('Reading it with Local AI…'));
      case ShareIntakeIngested():
        appRouter.go('/inbox');
      case ShareIntakeDuplicate():
        showAppSnackBar(tr('Already in your Review Inbox'));
      case ShareIntakeRejected(:final reason, :final recognizedText):
        showAppSnackBar(
          tr(
            "Couldn't find a transaction in that message"
            '{0}',
            [_rejectReasonHint(reason)],
          ),
          action: recognizedText == null
              ? null
              : SnackBarAction(
                  label: tr('View text'),
                  onPressed: () => showRecognizedTextDialog(recognizedText),
                ),
        );
    }
  }

  /// A JSON file the user opened with XPENC — normally a language pack
  /// downloaded from xpenc.in/languages (GitHub #191).
  Future<void> _handleOpenedFile(String path) async {
    switch (await readOpenedFile(path)) {
      case OpenedLanguagePack(:final pack):
        await _useLanguagePack(pack);
      case OpenedOtherFile(:final message):
        showAppSnackBar(message);
    }
  }

  /// Opening a pack is asking for that language: install it and switch the
  /// whole app to it, with an Undo back to what was showing.
  Future<void> _useLanguagePack(LanguagePack pack) async {
    if (!LanguagePackStore.supported) return;
    final db = ref.read(dbProvider);
    final before = ref.read(settingsProvider).valueOrNull?.languageCode;
    try {
      await LanguagePackStore.install(pack);
    } catch (e) {
      showAppSnackBar(tr("Couldn't save the language pack: {0}", [e]));
      return;
    }
    await db.setLanguageCode(pack.code);
    if (!mounted) return;
    if (_language == pack.code) {
      // Already showing (a newer pack of the same language): its table
      // changed underneath it.
      await L10n.load(pack.code);
      WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllWidgets());
    } else {
      await _ensureLanguage(pack.code);
    }
    if (!mounted) return;
    // A dialog, not a SnackBar: this came from outside the app (a file
    // opened from Downloads), so say plainly that it worked — in the new
    // language. Under the lock screen it waits there until the user unlocks.
    final rootContext = appRootContext;
    if (rootContext == null || !rootContext.mounted) {
      showAppSnackBar(tr('XPENC is now in {0}.', [pack.nativeName]));
      return;
    }
    final coverage = pack.coverage;
    final undo = await showAppDialog<bool>(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        key: const Key('language-pack-installed'),
        icon: const Icon(Icons.check_circle_rounded, size: 40),
        title: Text(tr('XPENC is now in {0}.', [pack.nativeName])),
        content: Text(
          [
            tr('{0} translated strings.', [pack.strings.length]),
            if (coverage != null && coverage < 95)
              tr(
                'This pack translates about {0}% of XPENC so far — the rest '
                'stays in English.',
                [coverage],
              ),
            tr('To change it, open Settings → General → Language.'),
          ].join('\n\n'),
        ),
        actions: [
          if (before != pack.code)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Tr('Undo'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Tr('OK'),
          ),
        ],
      ),
    );
    if (undo == true) await db.setLanguageCode(before);
  }

  String _rejectReasonHint(RejectReason reason) => switch (reason) {
    RejectReason.otp => tr(' — looks like an OTP.'),
    RejectReason.promotional => tr(' — looks promotional.'),
    RejectReason.balanceOnly => tr(' — no transaction, just a balance.'),
    RejectReason.declined => tr(' — the payment was declined.'),
    RejectReason.noAmount => tr(' — no amount found.'),
    RejectReason.noDirection || RejectReason.notATransaction => '.',
  };

  @override
  Widget build(BuildContext context) {
    // Budgets are re-checked whenever the ledger changes. `claimBudgetAlert`
    // makes each alert fire at most once per category, per period, per level.
    ref.listen(allTransactionsProvider, (_, next) {
      if (next.hasValue) {
        ref.read(notificationServiceProvider).checkBudgets();
        ref.read(notificationServiceProvider).checkModeAlerts();
        _onLedgerChanged();
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

    // XPENC web's built-in Connector syncs while the app is open — once the
    // user has turned it on. Listened to, not watched: its every tick
    // shouldn't rebuild the app.
    if (connectorPlatform != null) ref.listen(connectorProvider, (_, _) {});

    final ready = ref.watch(databaseReadyProvider);
    final choice = ref.watch(themeChoiceProvider);
    final glassBackdrop = choice.style.shape.isGlass
        ? ThemeChoice.glassBackdrop
        : null;
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
    if (settingsRow != null) {
      _ensureLanguage(L10n.resolve(settingsRow.languageCode));
    }

    // Point the global formatters at the chosen currency before anything paints,
    // and broadcast it via CurrencyScope so every amount reformats the instant
    // it changes — even a screen kept alive on another tab.
    final currency = ref.watch(currencyProvider);
    final showSymbol = ref.watch(showCurrencySymbolProvider);
    MoneyFormat.configure(currency: currency, showSymbol: showSymbol);
    final hideAmounts = ref.watch(hideAmountsProvider);
    final extraBottomInset = ref.watch(extraBottomInsetProvider);

    // A custom currency's symbol or name changed: every amount and picker
    // drawn with it must redraw, even ones that wouldn't rebuild on their
    // own — same as a colour change below.
    ref.listen(customCurrenciesProvider, (prev, next) {
      if (prev?.hasValue ?? false) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => rebuildAllWidgets(),
        );
      }
    });

    // Settings → Colours (GitHub #156). The money colours are plain statics
    // read at build time, so a change must reach widgets that otherwise
    // wouldn't rebuild (const ones, screens kept alive on another tab) —
    // after this frame, every element is marked to rebuild once.
    final colors = ref.watch(moneyColorChoiceProvider);
    Color? colorOf(int? argb) => argb == null ? null : Color(argb);
    final colorsChanged =
        AppColors.configure(
          income: colorOf(colors.income),
          expense: colorOf(colors.expense),
          transfer: colorOf(colors.transfer),
          person: colorOf(colors.person),
        ) |
        TxIconStyle.configure(colors.iconMode, colorOf(colors.iconColor));
    if (colorsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllWidgets());
    }

    // Fire-and-forget: a platform-channel call, not something the frame
    // waits on. ScreenSecurity itself no-ops if nothing actually changed.
    unawaited(ScreenSecurity.apply(ref.watch(preventScreenshotsProvider)));

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      // Every date picker's first column (GitHub #166).
      localizationsDelegates: [
        WeekStartLocalizationsDelegate(
          ref.watch(weekStartProvider),
          language: _language ?? 'en',
        ),
      ],
      // A style that only exists in one brightness (Glass) stores the same
      // palette in both slots, so `themeMode` alone decides.
      // Glass's palette comes from its background, in both slots;
      // `themeMode` (light or dark, by that background) picks the slot.
      theme: AppTheme.of(
        glassBackdrop?.palette ?? choice.style.lightPalette,
        choice.style.shape,
        fontFamily: fontFamily,
        fontWeightDelta: fontWeightDelta,
        backdrop: glassBackdrop,
      ),
      darkTheme: AppTheme.of(
        glassBackdrop?.palette ?? choice.style.darkPalette,
        choice.style.shape,
        fontFamily: fontFamily,
        fontWeightDelta: fontWeightDelta,
        backdrop: glassBackdrop,
      ),
      themeMode: choice.effectiveMode,
      // Glass scrolls like iOS: rubber-band bounce, no Android stretch glow.
      scrollBehavior: choice.style.shape.isGlass
          ? const _GlassScrollBehavior()
          : null,
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
          // Arabic and other right-to-left packs mirror the layout. Set
          // here, over the router, so pages, dialogs and sheets all follow.
          child: Directionality(
            textDirection: L10n.textDirection(_language ?? 'en'),
            child: L10nScope(
              code: _language ?? 'en',
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
                          : _language == null
                          ? const _LaunchSplash()
                          : Stack(
                              children: [
                                // On a PC-sized screen, a sidebar beside every
                                // page — see `DesktopFrame`.
                                if (child != null) DesktopFrame(child: child),
                                // Opt-in (GitHub #90) — someone who deliberately
                                // leaves screenshot-blocking off made that choice
                                // on purpose and shouldn't be nagged about it
                                // unless they ask to be. Never over the lock
                                // screen either: nothing sensitive is on it.
                                if (!_locked &&
                                    !ref.watch(preventScreenshotsProvider) &&
                                    ref.watch(
                                      screenshotReminderEnabledProvider,
                                    ))
                                  const Positioned(
                                    right: 12,
                                    bottom: 84,
                                    child: _ScreenshotAllowedTag(),
                                  ),
                                if (_locked)
                                  Positioned.fill(
                                    // `LockScreen` sits here as a sibling of the
                                    // routed `child` above, not a descendant of
                                    // it — the app's real `Navigator` lives
                                    // inside `child`, built by go_router, so
                                    // `LockScreen`'s own context would otherwise
                                    // have no `Navigator` ancestor at all. That
                                    // silently broke "Try another method"'s
                                    // `showModalBottomSheet` (GitHub #127): it
                                    // threw on tap with no visible feedback,
                                    // since only 2+ ready unlock methods ever
                                    // show that button in the first place. A
                                    // small nested `Navigator` — never touched by
                                    // the app's own routing — gives it one.
                                    // `HeroControllerScope.none`: a bare
                                    // `Navigator` otherwise inherits the
                                    // ambient `HeroController` `MaterialApp
                                    // .router` provides, which throws once two
                                    // Navigators (this one and go_router's,
                                    // inside `child`) end up sharing it.
                                    child: HeroControllerScope.none(
                                      child: Navigator(
                                        onGenerateRoute: (_) =>
                                            MaterialPageRoute(
                                              builder: (_) => LockScreen(
                                                onUnlocked: _unlocked,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    _ => child ?? const SizedBox.shrink(),
                  },
                ),
              ),
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
        child: Tr(
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
    // Outside the router, so no route paints Glass's wallpaper behind it.
    return const PageBackdrop(
      child: Scaffold(body: Center(child: BrandMark(size: 56))),
    );
  }
}

class _FatalError extends StatelessWidget {
  const _FatalError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PageBackdrop(
      child: Scaffold(
        body: SafeArea(
          child: ErrorView(
            title: tr("Couldn't open your data"),
            message: tr(
              'The app could not open its database, so nothing can be shown. '
              'Your saved data is not lost.',
            ),
            detail: error.toString(),
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}

/// iOS scrolling for the Glass theme: bounce at the ends instead of
/// Android's stretch, everywhere a scroll view doesn't pick its own physics.
class _GlassScrollBehavior extends MaterialScrollBehavior {
  const _GlassScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
