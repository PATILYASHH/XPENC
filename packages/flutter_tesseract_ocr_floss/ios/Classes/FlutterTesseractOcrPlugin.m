#import "FlutterTesseractOcrPlugin.h"
#import <flutter_tesseract_ocr/flutter_tesseract_ocr-Swift.h>

@implementation FlutterTesseractOcrPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterTesseractOcrPlugin registerWithRegistrar:registrar];
}
@end
