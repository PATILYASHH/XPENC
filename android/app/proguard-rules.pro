# google_mlkit_text_recognition's native code references the Chinese/
# Devanagari/Japanese/Korean script recognizer classes from a single shared
# code path, but this app only ever requests TextRecognitionScript.latin
# (see message_capture/ocr_service.dart) and only depends on the Latin
# recognizer artifact — the other four are optional and deliberately not
# pulled in (see GitHub #25). R8 can't see that they're unreachable at
# runtime, so without this it fails release builds with "Missing class".
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
