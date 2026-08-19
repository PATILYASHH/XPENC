import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

/// Recognises text in an image, entirely on-device.
///
/// Wraps Tesseract (BSD-3-Clause) via `flutter_tesseract_ocr` — not Google
/// ML Kit, which F-Droid rejects: its trained-model blobs are proprietary
/// even in the no-Play-Services "bundled" form (see GitHub #57). The English
/// model ships as an asset (`assets/tessdata/eng.traineddata`, Apache-2.0
/// from tesseract-ocr/tessdata_fast) so recognition needs no network call.
class OcrService {
  const OcrService();

  /// Returns every line of text Tesseract found in the image at [imagePath],
  /// top-to-bottom as it appears on screen — empty if none.
  Future<String> recognizeText(String imagePath) async {
    final text = await FlutterTesseractOcr.extractText(
      imagePath,
      language: 'eng',
      args: {
        'preserve_interword_spaces': '1',
      },
    );
    return text.trim();
  }
}
