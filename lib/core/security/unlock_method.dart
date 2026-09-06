import '../../data/database.dart' show SettingRow;
import '../../data/tables.dart' show UnlockMethod;

/// Whether [method] is actually usable right now — its own on/off toggle is
/// turned on **and** its credential is configured. Both must be true; a
/// toggle with no credential behind it (or a configured credential the user
/// switched off) is not "ready" (GitHub #104 → #111 → independent on/off
/// toggles per method, OR semantics).
bool isUnlockMethodReady(SettingRow settings, UnlockMethod method) =>
    switch (method) {
      UnlockMethod.pin =>
        settings.pinUnlockEnabled && settings.passcodeHash != null,
      UnlockMethod.masterPhrase =>
        settings.masterPhraseUnlockEnabled && settings.masterPhraseHash != null,
      UnlockMethod.totp =>
        settings.totpUnlockEnabled && settings.totpSecret != null,
    };

/// Every method that's ready right now, in [UnlockMethod.values] order —
/// what the lock screen's "try another method" offers alongside whichever
/// one is already showing, and what the Settings on/off toggles must never
/// collectively empty out.
List<UnlockMethod> readyUnlockMethods(SettingRow settings) => UnlockMethod
    .values
    .where((method) => isUnlockMethodReady(settings, method))
    .toList();

/// Whether the app is actually locked right now — true the moment *any*
/// unlock method is ready (GitHub #104's original single-method question,
/// generalized to the OR of however many are turned on). `app.dart`'s lock
/// gate and `LockScreen`'s body switch both call this rather than each
/// keeping their own copy of "which methods matter."
bool hasUnlockCredential(SettingRow settings) =>
    readyUnlockMethods(settings).isNotEmpty;
