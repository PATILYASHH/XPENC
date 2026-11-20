import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:xpenc/core/security/pbkdf2.dart';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _reference(List<int> password, List<int> salt, int rounds) =>
    (PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
          ..init(Pbkdf2Parameters(Uint8List.fromList(salt), rounds, 32)))
        .process(Uint8List.fromList(password));

/// The backup key derivation (GitHub #41) is hand-optimised, so it's held
/// to the published PBKDF2-HMAC-SHA256 vectors and to pointycastle.
void main() {
  final password = utf8.encode('password');
  final salt = utf8.encode('salt');

  test('matches the published PBKDF2-HMAC-SHA256 vectors', () {
    expect(
      _hex(pbkdf2HmacSha256(password, salt, 1)),
      '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
    );
    expect(
      _hex(pbkdf2HmacSha256(password, salt, 2)),
      'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
    );
    expect(
      _hex(pbkdf2HmacSha256(password, salt, 4096)),
      'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
    );
  });

  test('agrees with pointycastle on every key and salt length', () {
    final random = Random(41);
    List<int> bytes(int n) => List.generate(n, (_) => random.nextInt(256));
    // Around the 64-byte block edge, where a long key is hashed first.
    for (final keyLength in [0, 1, 31, 55, 63, 64, 65, 100, 200]) {
      for (final saltLength in [0, 16, 55, 56, 64, 120]) {
        final p = bytes(keyLength);
        final s = bytes(saltLength);
        expect(
          pbkdf2HmacSha256(p, s, 37),
          _reference(p, s, 37),
          reason: 'key $keyLength, salt $saltLength',
        );
      }
    }
    final unicode = utf8.encode('पासवर्ड € 🔐 пароль');
    expect(
      pbkdf2HmacSha256(unicode, salt, 1000),
      _reference(unicode, salt, 1000),
    );
  });

  test('refuses zero rounds', () {
    expect(() => pbkdf2HmacSha256(password, salt, 0), throwsArgumentError);
  });
}
