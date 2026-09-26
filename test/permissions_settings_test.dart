import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/permissions/app_permissions.dart';
import 'package:xpenc/features/settings/permissions_settings_screen.dart';

const _channel = MethodChannel('xpenc/permissions');

void main() {
  late Map<String, String> granted;
  late List<MethodCall> calls;

  setUp(() {
    granted = {
      AppPermission.notifications.androidName: 'granted',
      AppPermission.camera.androidName: 'denied',
      AppPermission.contacts.androidName: 'blocked',
    };
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'status':
              return {
                for (final n in (call.arguments as List).cast<String>())
                  n: granted[n],
              };
            case 'request':
              final name = call.arguments as String;
              if (granted[name] == 'denied') granted[name] = 'granted';
              return granted[name];
            case 'openSettings':
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PermissionsSettingsScreen()),
    );
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester, String title) => tester
      .widget<SwitchListTile>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(SwitchListTile),
        ),
      )
      .value;

  testWidgets('shows each permission with its current state', (tester) async {
    await pump(tester);
    expect(switchOn(tester, 'Notifications'), isTrue);
    expect(switchOn(tester, 'Camera'), isFalse);
    expect(switchOn(tester, 'Contacts'), isFalse);
    // The trust section — what XPENC never asks for.
    await tester.scrollUntilVisible(find.text('Internet'), 200);
    expect(find.text('Internet'), findsOneWidget);
  });

  testWidgets('turning one on asks Android', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(
      calls.any(
        (c) =>
            c.method == 'request' &&
            c.arguments == AppPermission.camera.androidName,
      ),
      isTrue,
    );
    expect(switchOn(tester, 'Camera'), isTrue);
  });

  testWidgets('a blocked permission sends the user to system settings', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Allow in system settings'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'openSettings'), isTrue);
  });

  testWidgets('turning one off explains it happens in system settings', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Turn off in system settings'), findsOneWidget);
    // Cancel leaves everything alone.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls.any((c) => c.method == 'openSettings'), isFalse);
    expect(switchOn(tester, 'Notifications'), isTrue);
  });

  testWidgets('no Android host: switches are disabled, nothing throws', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await pump(tester);
    expect(tester.takeException(), isNull);
    final tile = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('Camera'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(tile.onChanged, isNull);
  });
}
