import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/security/totp.dart';
import 'package:xpenc/core/security/unlock_method.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// Choice of unlock method + TOTP (GitHub #104): the design doc is at
/// `docs/superpowers/specs/2026-09-06-unlock-method-choice-design.md`. These
/// tests guard the non-UI core — the TOTP algorithm itself, the
/// `Settings.unlockMethod`/`totpSecret` round-trip, and
/// `hasUnlockCredential`'s single "is the app actually locked right now"
/// answer — the same shape as `passcode_test.dart`'s PIN/phrase coverage.
void main() {
  group('Totp', () {
    test('a code generated for one instant verifies at that instant', () {
      final secret = Totp.generateSecret();
      final now = DateTime.now();
      final code = Totp.codeAt(secret, time: now);
      expect(Totp.verify(secret, code, now: now), isTrue);
    });

    test('verify rejects a wrong code', () {
      final secret = Totp.generateSecret();
      final now = DateTime.now();
      final code = Totp.codeAt(secret, time: now);
      final wrong = code == '000000' ? '111111' : '000000';
      expect(Totp.verify(secret, wrong, now: now), isFalse);
    });

    test('a code from one step earlier or later still verifies (±30s '
        'tolerance)', () {
      final secret = Totp.generateSecret();
      final now = DateTime.now();
      final earlier = Totp.codeAt(
        secret,
        time: now.subtract(const Duration(seconds: 30)),
      );
      final later = Totp.codeAt(
        secret,
        time: now.add(const Duration(seconds: 30)),
      );
      expect(Totp.verify(secret, earlier, now: now), isTrue);
      expect(Totp.verify(secret, later, now: now), isTrue);
    });

    test('a code two steps away is rejected', () {
      final secret = Totp.generateSecret();
      final now = DateTime.now();
      final tooOld = Totp.codeAt(
        secret,
        time: now.subtract(const Duration(seconds: 90)),
      );
      // Only assert rejection if it doesn't coincidentally collide with a
      // code that would verify anyway (astronomically unlikely, but this
      // keeps the test honest rather than flaky).
      if (tooOld != Totp.codeAt(secret, time: now)) {
        expect(Totp.verify(secret, tooOld, now: now), isFalse);
      }
    });

    test('generateSecret never repeats', () {
      final secrets = {for (var i = 0; i < 20; i++) Totp.generateSecret()};
      expect(secrets, hasLength(20));
    });

    test('provisioningUri carries the secret, issuer and 6-digit/30s params '
        'but no algorithm param', () {
      final uri = Totp.provisioningUri('ABCDEFGH', label: 'me@example.com');
      expect(uri, startsWith('otpauth://totp/'));
      expect(uri, contains('secret=ABCDEFGH'));
      expect(uri, contains('issuer=XPENC'));
      expect(uri, contains('digits=6'));
      expect(uri, contains('period=30'));
      expect(uri, isNot(contains('algorithm=')));
    });

    test('verify fails closed on a malformed secret instead of throwing', () {
      expect(() => Totp.verify('not valid base32!!', '123456'), returnsNormally);
      expect(Totp.verify('not valid base32!!', '123456'), isFalse);
    });
  });

  group('hasUnlockCredential', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a fresh install has no unlock credential', () async {
      expect(hasUnlockCredential(await db.getSettings()), isFalse);
    });

    test('true once a PIN is set (the default active method)', () async {
      await db.setPasscode('4269');
      expect(hasUnlockCredential(await db.getSettings()), isTrue);
    });

    test(
      'false for a configured method that is not the active one',
      () async {
        // A phrase alone, with PIN still the (unset) active method, must not
        // read as "locked" — this is exactly the bug the design doc opens
        // with: a phrase with no PIN behind it couldn't lock the app.
        await db.setMasterPhrase(const [
          'anchor',
          'bear',
          'cliff',
          'dawn',
          'ember',
          'falcon',
          'garden',
          'harbor',
          'island',
          'jungle',
        ]);
        // setMasterPhrase activates it, so flip back to pin to exercise the
        // "configured but not active" branch.
        await db.setUnlockMethod(UnlockMethod.pin);
        expect(hasUnlockCredential(await db.getSettings()), isFalse);
      },
    );
  });

  group('AppDatabase unlock method + TOTP round-trip (GitHub #104)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('unlockMethod defaults to pin', () async {
      expect((await db.getSettings()).unlockMethod, UnlockMethod.pin);
      expect((await db.getSettings()).totpSecret, isNull);
    });

    test('setupTotp stores the secret and activates it in one step', () async {
      final secret = Totp.generateSecret();
      await db.setupTotp(secret);
      final settings = await db.getSettings();
      expect(settings.totpSecret, secret);
      expect(settings.unlockMethod, UnlockMethod.totp);
    });

    test('verifyTotp accepts a current code and rejects a wrong one', () async {
      final secret = Totp.generateSecret();
      await db.setupTotp(secret);
      final code = Totp.codeAt(secret);
      expect(await db.verifyTotp(code), isTrue);
      final wrong = code == '000000' ? '111111' : '000000';
      expect(await db.verifyTotp(wrong), isFalse);
    });

    test('verifyTotp is false with no secret configured', () async {
      expect(await db.verifyTotp('123456'), isFalse);
    });

    test('clearTotp removes the secret and falls back to pin when it was '
        'active', () async {
      await db.setupTotp(Totp.generateSecret());
      await db.clearTotp();
      final settings = await db.getSettings();
      expect(settings.totpSecret, isNull);
      expect(settings.unlockMethod, UnlockMethod.pin);
    });

    test(
      'clearTotp leaves the active method alone when TOTP was not it',
      () async {
        await db.setupTotp(Totp.generateSecret());
        await db.setPasscode('4269'); // fresh passcode activates pin
        await db.clearTotp();
        expect((await db.getSettings()).unlockMethod, UnlockMethod.pin);
      },
    );

    test(
      'a fresh setPasscode activates pin; changing an existing one does not '
      'steal activation from a different active method',
      () async {
        await db.setPasscode('4269');
        expect((await db.getSettings()).unlockMethod, UnlockMethod.pin);

        await db.setupTotp(Totp.generateSecret());
        expect((await db.getSettings()).unlockMethod, UnlockMethod.totp);

        // Changing the already-set PIN must not silently switch back to it.
        await db.setPasscode('1357');
        expect((await db.getSettings()).unlockMethod, UnlockMethod.totp);
        expect(await db.verifyPasscode('1357'), isTrue);
      },
    );

    test('setUnlockMethod switches the active method without touching any '
        "method's own credential", () async {
      await db.setPasscode('4269');
      await db.setupTotp(Totp.generateSecret());
      await db.setUnlockMethod(UnlockMethod.pin);
      final settings = await db.getSettings();
      expect(settings.unlockMethod, UnlockMethod.pin);
      expect(settings.totpSecret, isNotNull); // still configured, just unused
      expect(await db.verifyPasscode('4269'), isTrue);
    });

    test(
      'a backup restore never silently swaps the active method or the TOTP '
      'secret',
      () async {
        final secret = Totp.generateSecret();
        await db.setupTotp(secret);
        final backup = await db.exportAll();

        final settingsRows = (backup['settings'] as List)
            .cast<Map<String, dynamic>>();
        for (final row in settingsRows) {
          row['unlock_method'] = 'pin';
          row.remove('totp_secret');
        }

        await db.importAll(backup);

        final settings = await db.getSettings();
        expect(settings.unlockMethod, UnlockMethod.totp);
        expect(settings.totpSecret, secret);
      },
    );

    test('unlockMethodProvider/hasTotpProvider reflect the stored row', () async {
      final container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await container.read(dbProvider).getSettings();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(unlockMethodProvider), UnlockMethod.pin);
      expect(container.read(hasTotpProvider), isFalse);

      await db.setupTotp(Totp.generateSecret());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(unlockMethodProvider), UnlockMethod.totp);
      expect(container.read(hasTotpProvider), isTrue);
      expect(container.read(hasUnlockCredentialProvider), isTrue);
    });
  });
}
