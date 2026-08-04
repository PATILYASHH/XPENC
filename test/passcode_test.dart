import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/security/passcode.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';

/// Guards the passcode lock's core correctness: nothing here touches
/// widgets, only the hashing and the database round-trip a wrong widget
/// wiring would never catch.
void main() {
  group('Passcode hashing', () {
    test('the same PIN and salt always hash the same way', () {
      const salt = 'fixed-salt';
      expect(Passcode.hash('1234', salt), Passcode.hash('1234', salt));
    });

    test('a different PIN hashes differently', () {
      const salt = 'fixed-salt';
      expect(Passcode.hash('1234', salt), isNot(Passcode.hash('4321', salt)));
    });

    test('the same PIN with a different salt hashes differently', () {
      expect(
        Passcode.hash('1234', 'salt-a'),
        isNot(Passcode.hash('1234', 'salt-b')),
      );
    });

    test('generateSalt never repeats', () {
      final salts = {for (var i = 0; i < 20; i++) Passcode.generateSalt()};
      expect(salts, hasLength(20));
    });

    test('verify accepts the right PIN and rejects a wrong one', () {
      final salt = Passcode.generateSalt();
      final hash = Passcode.hash('9137', salt);
      expect(Passcode.verify('9137', salt, hash), isTrue);
      expect(Passcode.verify('0000', salt, hash), isFalse);
    });
  });

  group('AppDatabase passcode round-trip', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('no passcode set by default', () async {
      final settings = await db.getSettings();
      expect(settings.passcodeHash, isNull);
      expect(await db.verifyPasscode('anything'), isFalse);
    });

    test('setPasscode then verifyPasscode with the right PIN', () async {
      await db.setPasscode('4269');
      expect(await db.verifyPasscode('4269'), isTrue);
    });

    test('verifyPasscode rejects a wrong PIN', () async {
      await db.setPasscode('4269');
      expect(await db.verifyPasscode('0000'), isFalse);
    });

    test('the raw PIN is never stored', () async {
      await db.setPasscode('4269');
      final settings = await db.getSettings();
      expect(settings.passcodeHash, isNot(contains('4269')));
      expect(settings.passcodeSalt, isNotNull);
    });

    test('clearPasscode removes it and turns off biometric', () async {
      await db.setPasscode('4269');
      await db.setBiometricEnabled(true);
      expect((await db.getSettings()).biometricEnabled, isTrue);

      await db.clearPasscode();
      final settings = await db.getSettings();
      expect(settings.passcodeHash, isNull);
      expect(settings.passcodeSalt, isNull);
      expect(settings.biometricEnabled, isFalse);
      expect(await db.verifyPasscode('4269'), isFalse);
    });

    test('biometric cannot be enabled without a passcode', () async {
      await db.setBiometricEnabled(true);
      expect((await db.getSettings()).biometricEnabled, isFalse);
    });

    test('changing the passcode invalidates the old one', () async {
      await db.setPasscode('1111');
      await db.setPasscode('2222');
      expect(await db.verifyPasscode('1111'), isFalse);
      expect(await db.verifyPasscode('2222'), isTrue);
    });

    test('hasPasscodeProvider reflects the stored row', () async {
      final container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // Prime the settings stream.
      await container.read(dbProvider).getSettings();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(hasPasscodeProvider), isFalse);

      await db.setPasscode('4269');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(hasPasscodeProvider), isTrue);
    });

    test(
      'a backup restore never silently clears an existing passcode',
      () async {
        await db.setPasscode('4269');
        final backup = await db.exportAll();

        // The backup was taken before removing the passcode is relevant here —
        // simulate importing an *older* backup that predates any passcode ever
        // being set, by stripping the settings passcode fields the way an old
        // export would (it simply wouldn't have them).
        final settingsRows = (backup['settings'] as List)
            .cast<Map<String, dynamic>>();
        for (final row in settingsRows) {
          row.remove('passcode_hash');
          row.remove('passcode_salt');
        }

        await db.importAll(backup);

        expect(await db.verifyPasscode('4269'), isTrue);
      },
    );
  });
}
