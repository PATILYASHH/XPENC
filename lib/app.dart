import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/app_info.dart';
import 'core/money.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/error_view.dart';
import 'core/widgets/money_text.dart';
import 'data/providers.dart';

class XpencApp extends ConsumerStatefulWidget {
  const XpencApp({super.key});

  @override
  ConsumerState<XpencApp> createState() => _XpencAppState();
}

class _XpencAppState extends ConsumerState<XpencApp>
    with WidgetsBindingObserver {
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

    await _gateOnboarding();
    if (!mounted) return;

    final notifications = ref.read(notificationServiceProvider);
    await notifications.init();
    await notifications.syncReminders();

    // `checkBudgets` no-ops before `init()` completes (it must not claim an
    // alert it cannot deliver). The ledger listener may already have fired by
    // now, so run it once here — the claim table keeps it to one alert.
    await notifications.checkBudgets();

    await _scanMessages();
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
      _scanMessages();
    }
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

  @override
  Widget build(BuildContext context) {
    // Budgets are re-checked whenever the ledger changes. `claimBudgetAlert`
    // makes each alert fire at most once per category, per period, per level.
    ref.listen(allTransactionsProvider, (_, next) {
      if (next.hasValue) {
        ref.read(notificationServiceProvider).checkBudgets();
      }
    });

    final ready = ref.watch(databaseReadyProvider);
    final preset = ref.watch(themePresetProvider);

    // Point the global formatters at the chosen currency before anything paints,
    // and broadcast it via CurrencyScope so every amount reformats the instant
    // it changes — even a screen kept alive on another tab.
    final currency = ref.watch(currencyProvider);
    final showSymbol = ref.watch(showCurrencySymbolProvider);
    MoneyFormat.configure(currency: currency, showSymbol: showSymbol);

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      // A preset that forces one brightness stores the same palette in both
      // slots, so `themeMode` alone decides which of these two is used.
      theme: AppTheme.of(preset.lightPalette),
      darkTheme: AppTheme.of(preset.darkPalette),
      themeMode: preset.mode,
      routerConfig: appRouter,
      // A failed database must never look like "still loading".
      builder: (context, child) => CurrencyScope(
        currency: currency,
        showSymbol: showSymbol,
        child: switch (ready) {
          AsyncError(:final error) => _FatalError(
              error: error,
              onRetry: () => ref.invalidate(databaseReadyProvider),
            ),
          _ => child ?? const SizedBox.shrink(),
        },
      ),
    );
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
