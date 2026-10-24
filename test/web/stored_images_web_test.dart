// Run in a browser: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/platform/stored_images.dart';

/// XPENC web keeps receipt and person photos in the browser's IndexedDB —
/// see `stored_images_web.dart`.
void main() {
  test('a photo round-trips through browser storage', () async {
    final bytes = Uint8List.fromList(List.generate(256, (i) => i));

    final ref = await StoredImages.store('receipts', bytes, extension: '.png');
    expect(ref, startsWith('xpenc-web-image:receipts/'));
    expect(ref, endsWith('.png'));
    expect(StoredImages.existsSync(ref), isTrue);
    expect(await StoredImages.read(ref), bytes);

    await StoredImages.delete(ref);
    expect(await StoredImages.read(ref), isNull);
  });

  test('a phone path from an imported backup is simply missing', () async {
    const phonePath = '/data/user/0/com.yash.xpenc/app_flutter/receipts/1.jpg';
    expect(StoredImages.existsSync(phonePath), isFalse);
    expect(await StoredImages.read(phonePath), isNull);
    await expectLater(StoredImages.delete(phonePath), completes);
  });
}
