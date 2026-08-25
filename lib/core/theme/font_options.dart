/// The font families the Font settings screen offers.
///
/// Kept to a short, deliberately offline list — [manrope] and [sora] are the
/// two faces already bundled with the app (see `ThemeShape`); [serif] and
/// [monospace] are generic family names the platform resolves to whatever it
/// ships (Noto Serif / Droid Sans Mono on Android), so no extra asset is
/// needed for them either. [system] means "don't override" — each theme
/// keeps using its own `ThemeShape.displayFontFamily`/`bodyFontFamily`.
enum AppFontFamily {
  system('Default', null, 'Matches your theme'),
  manrope('Manrope', 'Manrope', 'Rounded and friendly'),
  sora('Sora', 'Sora', 'Geometric and confident'),
  serif('Serif', 'serif', 'Classic, with small strokes'),
  monospace('Monospace', 'monospace', 'Fixed-width, every letter the same');

  const AppFontFamily(this.label, this.family, this.description);

  final String label;

  /// The actual `fontFamily` string to hand Flutter, or null to leave every
  /// text style's family untouched.
  final String? family;

  final String description;

  /// Unknown or missing names fall back to [system], so a bad write can
  /// never brick the app — same convention as `ThemePreset.fromName`.
  static AppFontFamily fromName(String? name) {
    if (name == null) return AppFontFamily.system;
    return AppFontFamily.values.firstWhere(
      (f) => f.name == name,
      orElse: () => AppFontFamily.system,
    );
  }
}
