/// Everything the app knows about itself and who made it.
///
/// [version] and [buildNumber] mirror the `version:` line in `pubspec.yaml`.
/// They are constants rather than a `package_info_plus` lookup on purpose: that
/// plugin answers over a platform channel, which means every widget test that
/// renders the About screen would need a mock, and the value would be
/// unavailable in a pure Dart test. `test/branding_test.dart` parses the
/// pubspec and fails the build if these ever drift out of sync — which buys the
/// same guarantee as the plugin, for no dependency and no mocking.
class AppInfo {
  const AppInfo._();

  static const name = 'XPENC';
  static const tagline = 'Money, tracked honestly.';

  /// Shown under the wordmark on the About screen.
  static const description =
      'Offline-first personal finance. Your ledger, budgets and dues live '
      'on this device — nothing is ever uploaded.';

  // ── Version ────────────────────────────────────────────────────────────────
  static const version = '1.1.1';
  static const buildNumber = 3;

  /// `1.0.0 (build 1)` — the string a bug report should quote.
  static const versionLabel = '$version (build $buildNumber)';

  // ── Developer ──────────────────────────────────────────────────────────────
  static const developer = 'Yash Patil';
  static const developerRole = 'Design & engineering';

  static const githubHandle = 'PATILYASHH';
  static const githubUrl = 'https://github.com/PATILYASHH';

  static const linkedinHandle = 'patilyasshh';
  static const linkedinUrl = 'https://www.linkedin.com/in/patilyasshh/';

  // ── Project ────────────────────────────────────────────────────────────────
  /// Where this build's source lives.
  static const repoUrl = 'https://github.com/PATILYASHH/XPENC';

  /// The project website — features, downloads, FAQ.
  static const websiteUrl = 'https://getxpenc.vercel.app';

  /// New issue with a template picker (bug / feature / bank support).
  static const issuesUrl = '$repoUrl/issues/new/choose';

  /// Latest published APKs + SHA-256 checksums.
  static const releasesUrl = '$repoUrl/releases/latest';

  static const licenseName = 'MIT License';
  static const licenseUrl = '$repoUrl/blob/master/LICENSE';

  static const copyright = '© 2026 Yash Patil';
}
