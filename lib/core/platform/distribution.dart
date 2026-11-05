import 'package:flutter/foundation.dart';

/// Where this build is headed — `--dart-define=XPENC_DIST=...`:
///
/// - `play`: the Play AAB (docs/playstore/release-checklist.md).
/// - `github`: the release and beta APKs, the iOS builds, XPENC web
///   (.github/workflows, tool/build_web.sh).
/// - unset: F-Droid's own build. Its recipe (docs/fdroid) passes nothing,
///   and new versions copy the last recipe's build lines — so unset has to
///   be the F-Droid-safe answer, and an unmarked local build is one too.
abstract final class Distribution {
  static const _dist = String.fromEnvironment('XPENC_DIST');

  /// Pretends to be (or not to be) a Play/GitHub build — for tests.
  @visibleForTesting
  static bool? debugPromotesConectr;

  /// Whether XPENC may point people at CONECTR, which isn't open source.
  /// Never in F-Droid's build: promoting non-free software earns a listing
  /// F-Droid's NonFreeAdd anti-feature. What works *with* CONECTR once it's
  /// installed (friends, backups coming in, "Tell Connector") stays on
  /// everywhere: that only answers an app the user already has.
  static bool get promotesConectr =>
      debugPromotesConectr ?? (_dist == 'play' || _dist == 'github');
}
