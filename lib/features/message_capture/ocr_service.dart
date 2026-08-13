import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Recognises text in an image, entirely on-device.
///
/// Wraps ML Kit's *bundled* Latin text recognizer — the model is statically
/// linked into the app at build time (`com.google.mlkit:text-recognition`,
/// not `play-services-mlkit-text-recognition`), so this needs no Google Play
/// Services at runtime, no extra Android permission, and no network call.
/// See GitHub #25 and the dependency note in `pubspec.yaml`.
class OcrService {
  const OcrService();

  /// Returns every line of text ML Kit found in the image at [imagePath],
  /// top-to-bottom as it appears on screen — empty if none.
  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
