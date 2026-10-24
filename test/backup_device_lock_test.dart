import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/security/totp.dart';
import 'package:xpenc/data/database.dart';

/// A backup carries the ledger, never the phone's lock — and the Connector
/// app now uploads backups to GitHub and imports them across phones.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'a backup holds no PIN hash, master phrase hash or TOTP secret',
    () async {
      final secret = Totp.generateSecret();
      await db.setPasscode('424242');
      await db.setMasterPhrase(const ['anchor', 'bear', 'cliff', 'dawn']);
      await db.setupTotp(secret);

      final dump = await db.exportAll();
      final row = (dump['settings'] as List).single as Map<String, dynamic>;
      for (final column in [
        'passcode_hash',
        'passcode_salt',
        'passcode_length',
        'master_phrase_hash',
        'master_phrase_salt',
        'totp_secret',
      ]) {
        expect(row, containsPair(column, isNull), reason: column);
      }
      expect(jsonEncode(dump), isNot(contains(secret)));
    },
  );

  test('importing another phone\'s backup keeps this phone\'s lock — PIN '
      'length included', () async {
    final otherPhone = AppDatabase(NativeDatabase.memory());
    addTearDown(otherPhone.close);
    await otherPhone.setPasscode('1234');
    final dump =
        jsonDecode(jsonEncode(await otherPhone.exportAll()))
            as Map<String, dynamic>;

    await db.setPasscode('424242');
    await db.importAll(dump);

    // The lock screen takes exactly passcodeLength digits: with the other
    // phone's 4, this phone's 6-digit PIN could never be typed.
    expect((await db.getSettings()).passcodeLength, 6);
    expect(await db.verifyPasscode('424242'), isTrue);
  });
}
