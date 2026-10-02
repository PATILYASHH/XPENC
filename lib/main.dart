import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inter ships under the SIL OFL, which asks for its licence to travel
  // with the font — it shows in About → Licences.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Inter'],
      await rootBundle.loadString('assets/fonts/Inter-OFL.txt'),
    );
  });
  // The Glass theme's lens shader. A few milliseconds, and only where the
  // renderer can run it; capped so a slow device never holds up launch —
  // Glass then simply draws without the lens.
  await LiquidGlassShader.load().timeout(
    const Duration(milliseconds: 600),
    onTimeout: () {},
  );
  runApp(const ProviderScope(child: XpencApp()));
}
