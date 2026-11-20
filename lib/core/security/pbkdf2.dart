import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 (RFC 8018) with a 32-byte output — one block, which
/// is what an AES-256 key needs.
///
/// A general HMAC re-hashes the 64-byte key pads on every call, four SHA-256
/// compressions per round. Here the pads' states are computed once and every
/// round after the first is exactly two compressions over fixed-size blocks,
/// with no allocation — around three times faster than pointycastle's
/// `PBKDF2KeyDerivator`, which matters at 600,000 rounds (backup encryption,
/// GitHub #41). `test/pbkdf2_test.dart` holds it to the published test
/// vectors and to pointycastle's output.
Uint8List pbkdf2HmacSha256(List<int> password, List<int> salt, int rounds) {
  if (rounds < 1) throw ArgumentError.value(rounds, 'rounds');

  // HMAC key: hashed when longer than a block, then zero-padded to 64 bytes.
  final keyBytes = Uint8List(64)
    ..setAll(
      0,
      password.length > 64 ? sha256.convert(password).bytes : password,
    );
  final block = Uint32List(16);
  final w = Uint32List(64);

  Uint32List padState(int fill) {
    for (var i = 0; i < 16; i++) {
      block[i] = (_word(keyBytes, i * 4)) ^ fill;
    }
    final state = Uint32List.fromList(_h0);
    _compress(state, block, w);
    return state;
  }

  final inner = padState(0x36363636);
  final outer = padState(0x5c5c5c5c);

  // U1 = HMAC(P, S || INT(1)): salt is any length, so the general HMAC.
  final u1 = Hmac(sha256, password).convert([...salt, 0, 0, 0, 1]).bytes;
  final u = Uint32List(8);
  for (var i = 0; i < 8; i++) {
    u[i] = _word(u1, i * 4);
  }
  final t = Uint32List.fromList(u);
  final state = Uint32List(8);

  for (var r = 1; r < rounds; r++) {
    // Inner: H(ipad || U) — U is 32 bytes, so one padded block, 768 bits.
    state.setAll(0, inner);
    _fillDigestBlock(block, u);
    _compress(state, block, w);
    // Outer: H(opad || inner digest), the same shape.
    _fillDigestBlock(block, state);
    state.setAll(0, outer);
    _compress(state, block, w);
    for (var i = 0; i < 8; i++) {
      u[i] = state[i];
      t[i] ^= state[i];
    }
  }

  final out = Uint8List(32);
  for (var i = 0; i < 8; i++) {
    final v = t[i];
    out[i * 4] = v >> 24;
    out[i * 4 + 1] = (v >> 16) & 0xff;
    out[i * 4 + 2] = (v >> 8) & 0xff;
    out[i * 4 + 3] = v & 0xff;
  }
  return out;
}

int _word(List<int> b, int o) =>
    ((b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]) & _mask;

/// A 32-byte digest as the second block of a message whose first block was
/// a 64-byte pad: the digest, the 0x80 end marker, zeros, and the length.
void _fillDigestBlock(Uint32List block, Uint32List digest) {
  for (var i = 0; i < 8; i++) {
    block[i] = digest[i];
  }
  block[8] = 0x80000000;
  for (var i = 9; i < 15; i++) {
    block[i] = 0;
  }
  block[15] = (64 + 32) * 8;
}

const _mask = 0xffffffff;

const _h0 = <int>[
  0x6a09e667,
  0xbb67ae85,
  0x3c6ef372,
  0xa54ff53a,
  0x510e527f,
  0x9b05688c,
  0x1f83d9ab,
  0x5be0cd19,
];

final _k = Uint32List.fromList(const [
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x682e6ff3,
  0x748f82ee,
  0x78a5636f,
  0x84c87814,
  0x8cc70208,
  0x90befffa,
  0xa4506ceb,
  0xbef9a3f7,
  0xc67178f2,
]);

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

/// One SHA-256 compression of [block] into [state] (FIPS 180-4, 6.2.2).
void _compress(Uint32List state, Uint32List block, Uint32List w) {
  for (var i = 0; i < 16; i++) {
    w[i] = block[i];
  }
  for (var i = 16; i < 64; i++) {
    final x = w[i - 15], y = w[i - 2];
    final s0 = _rotr(x, 7) ^ _rotr(x, 18) ^ (x >> 3);
    final s1 = _rotr(y, 17) ^ _rotr(y, 19) ^ (y >> 10);
    w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _mask;
  }
  var a = state[0], b = state[1], c = state[2], d = state[3];
  var e = state[4], f = state[5], g = state[6], h = state[7];
  for (var i = 0; i < 64; i++) {
    final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
    final ch = (e & f) ^ (~e & g & _mask);
    final t1 = (h + s1 + ch + _k[i] + w[i]) & _mask;
    final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
    final maj = (a & b) ^ (a & c) ^ (b & c);
    final t2 = (s0 + maj) & _mask;
    h = g;
    g = f;
    f = e;
    e = (d + t1) & _mask;
    d = c;
    c = b;
    b = a;
    a = (t1 + t2) & _mask;
  }
  state[0] = (state[0] + a) & _mask;
  state[1] = (state[1] + b) & _mask;
  state[2] = (state[2] + c) & _mask;
  state[3] = (state[3] + d) & _mask;
  state[4] = (state[4] + e) & _mask;
  state[5] = (state[5] + f) & _mask;
  state[6] = (state[6] + g) & _mask;
  state[7] = (state[7] + h) & _mask;
}
