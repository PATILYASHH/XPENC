import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import '../../core/security/pbkdf2.dart';

/// Encrypted backups (GitHub #41): what an encrypted backup file looks like,
/// and how it's sealed and opened.
///
/// An encrypted backup is still a `.json` file under the same
/// `DDMMYYXPENCEBACKUP.json` name — a small JSON envelope around the
/// ciphertext — so everything that only moves backup files around (the
/// backup list, retention, Share, Connector, which treats a backup as opaque
/// bytes) carries on unchanged. Only opening one needs the key:
///
/// ```json
/// {
///   "xpenc": "encrypted-backup", "version": 1,
///   "cipher": "AES-256-GCM", "kdf": "PBKDF2-HMAC-SHA256",
///   "iterations": 600000, "salt": "…", "nonce": "…", "data": "…"
/// }
/// ```
///
/// `data` is the compact backup JSON, AES-256-GCM encrypted, with the 16-byte
/// tag on the end. The header fields are bound in as associated data, so
/// editing any of them (a lower iteration count, say) fails authentication
/// exactly like a wrong password does.
///
/// One field is left out of that on purpose: `"lockedWith":
/// "recovery-phrase"` on a backup locked with the master recovery phrase
/// (GitHub #210), so a restore asks for the 10 words rather than a
/// password. It only picks which prompt shows; the key still has to be
/// right. Leaving it unbound means XPENC from before #210 still opens such
/// a backup, given the words typed as the password.
///
/// The key comes from the backup password through PBKDF2-HMAC-SHA256 at
/// OWASP's 600,000 iterations. Deriving it is the slow part (about a second
/// on a phone), so it happens only when a password is set or typed — never
/// per backup: a phone keeps the derived key ([BackupKey]) and seals every
/// backup with it under a fresh random nonce.
abstract final class BackupCrypto {
  static const marker = 'encrypted-backup';
  static const version = 1;
  static const cipher = 'AES-256-GCM';
  static const kdf = 'PBKDF2-HMAC-SHA256';

  /// OWASP's 2023 figure for PBKDF2-HMAC-SHA256.
  static const defaultIterations = 600000;

  /// Shortest backup password accepted. Encrypted backups may end up
  /// somewhere public (GitHub, through Connector), where a short password
  /// is guessed offline however slow each guess is made.
  static const minPasswordLength = 8;

  /// The header's `lockedWith` for a backup locked with the master recovery
  /// phrase (GitHub #210).
  static const lockedWithRecoveryPhrase = 'recovery-phrase';

  static const _saltBytes = 16;
  static const _nonceBytes = 12;
  static const _tagBits = 128;

  static final _random = Random.secure();

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _random.nextInt(256)));

  /// The password a recovery phrase stands for: its words, lowercase, one
  /// space apart, the same form the lock screen hashes. So the phrase
  /// opens its backups however it's typed, here or in an XPENC from before
  /// #210 that only knows passwords.
  static String phrasePassword(List<String> words) => words.join(' ');

  /// A new key for [password]: fresh salt, derived off the UI thread.
  /// [phraseHash] is set when [password] is the master recovery phrase.
  static Future<BackupKey> newKey(
    String password, {
    int iterations = defaultIterations,
    String? phraseHash,
  }) => deriveKey(
    password,
    _randomBytes(_saltBytes),
    iterations,
    phraseHash: phraseHash,
  );

  /// The key [password] gives with [salt] and [iterations] — what opening a
  /// backup made elsewhere takes. Runs in a background isolate on a phone;
  /// on the web, where there's none, inline.
  static Future<BackupKey> deriveKey(
    String password,
    Uint8List salt,
    int iterations, {
    String? phraseHash,
  }) async {
    final key = await compute(_derive, (password, salt, iterations));
    return BackupKey(
      salt: salt,
      iterations: iterations,
      key: key,
      phraseHash: phraseHash,
    );
  }

  static Uint8List _derive((String, Uint8List, int) args) {
    final (password, salt, iterations) = args;
    return pbkdf2HmacSha256(utf8.encode(password), salt, iterations);
  }

  /// [backupJson] as an encrypted backup's text, sealed with [key].
  static String seal(String backupJson, BackupKey key) {
    final nonce = _randomBytes(_nonceBytes);
    final header = <String, Object>{
      'xpenc': marker,
      'version': version,
      'cipher': cipher,
      'kdf': kdf,
      'iterations': key.iterations,
      'salt': base64Encode(key.salt),
    };
    final gcm = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key.key),
          _tagBits,
          nonce,
          _associatedData(header),
        ),
      );
    final data = gcm.process(Uint8List.fromList(utf8.encode(backupJson)));
    return const JsonEncoder.withIndent('  ').convert({
      ...header,
      if (key.fromRecoveryPhrase) 'lockedWith': lockedWithRecoveryPhrase,
      'nonce': base64Encode(nonce),
      'data': base64Encode(data),
    });
  }

  /// The header as associated data: a fixed field order, so the bytes don't
  /// depend on how a JSON encoder happened to order the keys.
  static Uint8List _associatedData(Map<String, Object?> header) =>
      Uint8List.fromList(
        utf8.encode(
          [
            header['xpenc'],
            header['version'],
            header['cipher'],
            header['kdf'],
            header['iterations'],
            header['salt'],
          ].join('|'),
        ),
      );
}

/// A backup key: the 32 bytes AES-256 uses, plus the salt and iteration
/// count that produced them from the password — which is how a sealed
/// backup names the key it needs, without saying anything about it.
@immutable
class BackupKey {
  const BackupKey({
    required this.salt,
    required this.iterations,
    required this.key,
    this.phraseHash,
  });

  final Uint8List salt;
  final int iterations;
  final Uint8List key;

  /// For a key made from the master recovery phrase (GitHub #210): that
  /// phrase's `Settings.masterPhraseHash`, the same salted hash the lock
  /// screen checks. It tells whether backups are still locked with the
  /// phrase set up now, or one since turned off or replaced. Null for a
  /// password.
  final String? phraseHash;

  bool get fromRecoveryPhrase => phraseHash != null;

  /// Whether this key is the one [backup] was sealed with — same salt and
  /// iteration count means the same password gives the same key.
  bool opens(EncryptedBackup backup) =>
      iterations == backup.iterations && listEquals(salt, backup.salt);

  Map<String, Object> toJson() => {
    'salt': base64Encode(salt),
    'iterations': iterations,
    'key': base64Encode(key),
    'phraseHash': ?phraseHash,
  };

  static BackupKey? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final key = base64Decode(json['key'] as String);
      if (key.length != 32) return null;
      final phraseHash = json['phraseHash'];
      return BackupKey(
        salt: base64Decode(json['salt'] as String),
        iterations: (json['iterations'] as num).toInt(),
        key: key,
        phraseHash: phraseHash is String ? phraseHash : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The key, or the password, didn't open the backup.
class BackupDecryptError implements Exception {
  const BackupDecryptError();
  @override
  String toString() => 'Wrong password';
}

/// An encrypted backup file, parsed — not yet opened.
class EncryptedBackup {
  EncryptedBackup._(
    this._header,
    this.salt,
    this.iterations,
    this._nonce,
    this._data,
  );

  final Map<String, Object?> _header;
  final Uint8List salt;
  final int iterations;
  final Uint8List _nonce;
  final Uint8List _data;

  /// Locked with the master recovery phrase (GitHub #210), so a restore
  /// asks for the 10 words. Only a hint (see [BackupCrypto]).
  bool get lockedWithRecoveryPhrase =>
      _header['lockedWith'] == BackupCrypto.lockedWithRecoveryPhrase;

  /// [decoded] (a backup file's parsed JSON) as an encrypted backup, or null
  /// when it's a plain one. Throws [FormatException] when it's marked
  /// encrypted but can't be one this version of XPENC opens.
  static EncryptedBackup? tryParse(Object? decoded) {
    if (decoded is! Map || decoded['xpenc'] != BackupCrypto.marker) {
      return null;
    }
    final version = decoded['version'];
    if (version is! int || version > BackupCrypto.version) {
      throw const FormatException(
        'That backup was encrypted by a newer XPENC. Update XPENC to '
        'restore it.',
      );
    }
    try {
      if (decoded['cipher'] != BackupCrypto.cipher ||
          decoded['kdf'] != BackupCrypto.kdf) {
        throw const FormatException();
      }
      final iterations = (decoded['iterations'] as num).toInt();
      // A tampered count is caught by the tag anyway; this stops a silly
      // one from hanging the phone before it gets that far.
      if (iterations < 1000 || iterations > 10000000) {
        throw const FormatException();
      }
      return EncryptedBackup._(
        Map<String, Object?>.from(decoded),
        base64Decode(decoded['salt'] as String),
        iterations,
        base64Decode(decoded['nonce'] as String),
        base64Decode(decoded['data'] as String),
      );
    } catch (_) {
      throw const FormatException('That encrypted backup is damaged.');
    }
  }

  /// The backup's JSON, opened with [key]. Throws [BackupDecryptError] when
  /// [key] isn't its key — or the file was changed since it was sealed.
  String open(BackupKey key) {
    try {
      final gcm = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(
            KeyParameter(key.key),
            BackupCrypto._tagBits,
            _nonce,
            BackupCrypto._associatedData(_header),
          ),
        );
      return utf8.decode(gcm.process(_data));
    } catch (_) {
      throw const BackupDecryptError();
    }
  }

  /// Opens it with [password]: derives the key (slow, see [BackupCrypto]),
  /// then [open]s — both off the UI thread on a phone. Returns the JSON and
  /// the key, for remembering. Throws [BackupDecryptError] on a wrong
  /// password.
  Future<(String, BackupKey)> openWithPassword(String password) =>
      compute(_openWithPassword, (this, password));

  static (String, BackupKey) _openWithPassword((EncryptedBackup, String) args) {
    final (backup, password) = args;
    final key = BackupKey(
      salt: backup.salt,
      iterations: backup.iterations,
      key: BackupCrypto._derive((password, backup.salt, backup.iterations)),
    );
    return (backup.open(key), key);
  }
}
