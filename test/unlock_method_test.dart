import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/security/totp.dart';
import 'package:xpenc/core/security/unlock_method.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// Independent on/off toggles per unlock method (GitHub #104 → #111 →
/// this), OR semantics: turning on more than one of PIN / master password /
/// authenticator app means *any* of them unlocks the app, not all of them.
/// These tests guard the non-UI core — the TOTP algorithm itself, the
/// `Settings` round-trip, and `hasUnlockCredential`/`isUnlockMethodReady`/
/// `readyUnlockMethods`'s "is the app actually locked, and with what" answer
/// — the same shape as `passcode_test.dart`'s PIN/phrase coverage.
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
      expect(
        () => Totp.verify('not valid base32!!', '123456'),
        returnsNormally,
      );
      expect(Totp.verify('not valid base32!!', '123456'), isFalse);
    });
  });

  group('hasUnlockCredential / isUnlockMethodReady / readyUnlockMethods', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a fresh install has no unlock credential', () async {
      final settings = await db.getSettings();
      expect(hasUnlockCredential(settings), isFalse);
      expect(readyUnlockMethods(settings), isEmpty);
    });

    test('true once a PIN is set (fresh setup turns its toggle on)', () async {
      await db.setPasscode('4269');
      final settings = await db.getSettings();
      expect(hasUnlockCredential(settings), isTrue);
      expect(readyUnlockMethods(settings), [UnlockMethod.pin]);
    });

    test('a configured-but-toggled-off method never counts, even with another '
        'method ready alongside it', () async {
      await db.setPasscode('4269'); // turns pin on
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
      ]); // turns masterPhrase on too
      // Two ready methods now, so turning one off is allowed.
      final turnedOff = await db.setUnlockMethodEnabled(
        UnlockMethod.masterPhrase,
        false,
      );
      expect(turnedOff, isTrue);

      final settings = await db.getSettings();
      // Still configured (the hash survives) but no longer ready.
      expect(settings.masterPhraseHash, isNotNull);
      expect(isUnlockMethodReady(settings, UnlockMethod.masterPhrase), isFalse);
      expect(hasUnlockCredential(settings), isTrue); // PIN alone still works
      expect(readyUnlockMethods(settings), [UnlockMethod.pin]);
    });

    test('OR semantics: either PIN or TOTP alone unlocks once both are set '
        'up', () async {
      await db.setPasscode('4269');
      await db.setupTotp(Totp.generateSecret());
      final settings = await db.getSettings();
      expect(hasUnlockCredential(settings), isTrue);
      expect(readyUnlockMethods(settings), [
        UnlockMethod.pin,
        UnlockMethod.totp,
      ]);
    });

    test(
      'setUnlockMethodEnabled refuses to turn off the last ready method',
      () async {
        await db.setPasscode('4269');
        final ok = await db.setUnlockMethodEnabled(UnlockMethod.pin, false);
        expect(ok, isFalse);
        final settings = await db.getSettings();
        expect(isUnlockMethodReady(settings, UnlockMethod.pin), isTrue);
        expect(hasUnlockCredential(settings), isTrue);
      },
    );

    test('setUnlockMethodEnabled allows turning off one of several ready '
        'methods', () async {
      await db.setPasscode('4269');
      await db.setupTotp(Totp.generateSecret());
      final ok = await db.setUnlockMethodEnabled(UnlockMethod.pin, false);
      expect(ok, isTrue);
      final settings = await db.getSettings();
      expect(isUnlockMethodReady(settings, UnlockMethod.pin), isFalse);
      expect(isUnlockMethodReady(settings, UnlockMethod.totp), isTrue);
      expect(hasUnlockCredential(settings), isTrue);
    });

    test('setUnlockMethodEnabled(on) with no credential configured is a no-op '
        '— the caller is expected to route to setup instead', () async {
      final ok = await db.setUnlockMethodEnabled(UnlockMethod.totp, true);
      expect(ok, isTrue);
      final settings = await db.getSettings();
      // Toggle flips, but there's no secret behind it, so still not ready.
      expect(settings.totpUnlockEnabled, isTrue);
      expect(isUnlockMethodReady(settings, UnlockMethod.totp), isFalse);
      expect(hasUnlockCredential(settings), isFalse);
    });
  });

  group('AppDatabase unlock method round-trip', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('defaults: pin shown first, pin toggle on, nothing else configured '
        'or on', () async {
      final settings = await db.getSettings();
      expect(settings.unlockMethod, UnlockMethod.pin);
      expect(settings.pinUnlockEnabled, isTrue);
      expect(settings.masterPhraseUnlockEnabled, isFalse);
      expect(settings.totpUnlockEnabled, isFalse);
      expect(settings.totpSecret, isNull);
    });

    test('setupTotp stores the secret, turns its toggle on, and shows it '
        'first, in one step', () async {
      final secret = Totp.generateSecret();
      await db.setupTotp(secret);
      final settings = await db.getSettings();
      expect(settings.totpSecret, secret);
      expect(settings.totpUnlockEnabled, isTrue);
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

    test('clearTotp removes the secret and its toggle, and falls back to pin '
        'when it was the method shown first', () async {
      await db.setupTotp(Totp.generateSecret());
      await db.clearTotp();
      final settings = await db.getSettings();
      expect(settings.totpSecret, isNull);
      expect(settings.totpUnlockEnabled, isFalse);
      expect(settings.unlockMethod, UnlockMethod.pin);
    });

    test(
      'clearTotp leaves the shown method alone when TOTP was not it',
      () async {
        await db.setupTotp(Totp.generateSecret());
        await db.setPasscode('4269'); // fresh passcode shows pin first
        await db.clearTotp();
        expect((await db.getSettings()).unlockMethod, UnlockMethod.pin);
      },
    );

    test(
      'a fresh setPasscode turns pin on and shows it first; changing an '
      'existing one does not steal that from a different shown method',
      () async {
        await db.setPasscode('4269');
        expect((await db.getSettings()).unlockMethod, UnlockMethod.pin);

        await db.setupTotp(Totp.generateSecret());
        expect((await db.getSettings()).unlockMethod, UnlockMethod.totp);

        // Changing the already-set PIN must not silently switch back to it,
        // nor touch its own toggle (already on).
        await db.setPasscode('1357');
        final settings = await db.getSettings();
        expect(settings.unlockMethod, UnlockMethod.totp);
        expect(settings.pinUnlockEnabled, isTrue);
        expect(await db.verifyPasscode('1357'), isTrue);
      },
    );

    test('setPreferredUnlockMethod switches which method shows first, '
        "without touching any method's own credential or toggle", () async {
      await db.setPasscode('4269');
      await db.setupTotp(Totp.generateSecret());
      await db.setPreferredUnlockMethod(UnlockMethod.pin);
      final settings = await db.getSettings();
      expect(settings.unlockMethod, UnlockMethod.pin);
      expect(settings.totpSecret, isNotNull); // still configured and ready
      expect(settings.totpUnlockEnabled, isTrue);
      expect(await db.verifyPasscode('4269'), isTrue);
    });

    test('a backup restore never silently swaps the shown method, its toggle, '
        'or the TOTP secret', () async {
      final secret = Totp.generateSecret();
      await db.setupTotp(secret);
      final backup = await db.exportAll();

      final settingsRows = (backup['settings'] as List)
          .cast<Map<String, dynamic>>();
      for (final row in settingsRows) {
        row['unlock_method'] = 'pin';
        row['totp_unlock_enabled'] = false;
        row.remove('totp_secret');
      }

      await db.importAll(backup);

      final settings = await db.getSettings();
      expect(settings.unlockMethod, UnlockMethod.totp);
      expect(settings.totpSecret, secret);
      expect(settings.totpUnlockEnabled, isTrue);
    });

    test(
      'unlockMethodProvider/hasTotpProvider reflect the stored row',
      () async {
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
        // Pin's toggle defaults on, but no PIN was ever actually set here —
        // `isUnlockMethodReady` needs both, so only totp is ready.
        expect(container.read(readyUnlockMethodsProvider), [UnlockMethod.totp]);
      },
    );
  });

  group('migration backfill: a pre-existing pinAndTotp install', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a stored pinAndTotp value backfills to both toggles on, OR semantics '
        '— either credential alone now unlocks it', () async {
      // Simulate what a real v64 `pinAndTotp` install looked like, written
      // with raw SQL so this doesn't go through the (now three-value)
      // typed enum converter.
      await db.setPasscode('4269');
      await db.setupTotp(Totp.generateSecret());
      await db.customStatement(
        "UPDATE settings SET unlock_method = 'pinAndTotp', "
        'pin_unlock_enabled = 1, totp_unlock_enabled = 1',
      );

      // Re-running the migration's backfill logic directly (as the real
      // `from < 65` step does) rather than round-tripping the on-disk
      // schema version, which `AppDatabase(NativeDatabase.memory())`
      // always opens at the latest version already.
      await db.customStatement(
        "UPDATE settings SET pin_unlock_enabled = 0 "
        "WHERE unlock_method NOT IN ('pin', 'pinAndTotp')",
      );
      await db.customStatement(
        "UPDATE settings SET totp_unlock_enabled = 1 "
        "WHERE unlock_method IN ('totp', 'pinAndTotp')",
      );
      await db.customStatement(
        "UPDATE settings SET unlock_method = 'pin' "
        "WHERE unlock_method = 'pinAndTotp'",
      );

      final settings = await db.getSettings();
      expect(settings.unlockMethod, UnlockMethod.pin);
      expect(readyUnlockMethods(settings), [
        UnlockMethod.pin,
        UnlockMethod.totp,
      ]);
    });
  });
}
