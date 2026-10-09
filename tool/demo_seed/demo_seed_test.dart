// Writes the demo ledger (demo_ledger.dart) to a SQLite file that can be
// pushed onto an emulator:
//
//   DEMO_OUT=build/demo flutter test tool/demo_seed/demo_seed_test.dart
//   adb push build/demo/money_manager.sqlite /data/local/tmp/
//   adb shell run-as com.yash.xpenc cp /data/local/tmp/money_manager.sqlite app_flutter/
//
// Lives outside test/ so CI's `flutter test` never runs it.
//
// NEVER push the result onto a phone with real data — it replaces the
// app's whole database.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/database.dart';

import 'demo_ledger.dart';

void main() {
  final outDir = Platform.environment['DEMO_OUT'];

  test('seed demo ledger', () async {
    if (outDir == null) {
      markTestSkipped('Set DEMO_OUT to write the demo database.');
      return;
    }
    for (final theme in ['light', 'dark']) {
      final dir = Directory('$outDir/$theme')..createSync(recursive: true);
      final file = File('${dir.path}/money_manager.sqlite');
      if (file.existsSync()) file.deleteSync();
      final db = AppDatabase(NativeDatabase(file));
      await seedDemoLedger(db, theme: theme);
      await db.close();
      // ignore: avoid_print
      print('wrote ${file.path}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
