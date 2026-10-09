import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/platform/platform_features.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/settings/general_settings_screen.dart';
import 'package:xpenc/features/settings/notifications_settings_screen.dart';
import 'package:xpenc/features/settings/quick_actions_settings_screen.dart';
import 'package:xpenc/features/settings/security_privacy_settings_screen.dart';
import 'package:xpenc/features/settings/settings_screen.dart';

/// On iOS, Settings hides what has no native half there yet (see
/// [PlatformFeatures]) instead of offering a switch that does nothing — and
/// Android keeps every one of them.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async {
    PlatformFeatures.debugIsIOS = null;
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    // Tall enough that every list item is built, not just the first screen.
    tester.view.physicalSize = const Size(1080, 15000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  final gated = <String, (Widget, List<String>)>{
    'Settings': (const SettingsScreen(), ['Permissions']),
    'Quick Actions': (
      const QuickActionsSettingsScreen(),
      ['Home screen widgets', 'Screenshot blocking'],
    ),
    'Security & Privacy': (
      const SecurityPrivacySettingsScreen(),
      ['Block screenshots'],
    ),
    'Notifications': (
      const NotificationsSettingsScreen(),
      ['Quick add from notification'],
    ),
    'General': (const GeneralSettingsScreen(), ['OCR corrections']),
  };

  for (final MapEntry(key: name, value: (screen, labels)) in gated.entries) {
    testWidgets('$name shows ${labels.join(', ')} on Android', (tester) async {
      PlatformFeatures.debugIsIOS = false;
      await pump(tester, screen);
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await unmount(tester);
    });

    testWidgets('$name hides ${labels.join(', ')} on iOS', (tester) async {
      PlatformFeatures.debugIsIOS = true;
      await pump(tester, screen);
      for (final label in labels) {
        expect(find.text(label), findsNothing, reason: label);
      }
      await unmount(tester);
    });
  }
}
