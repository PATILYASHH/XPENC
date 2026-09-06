import '../../data/database.dart' show SettingRow;
import '../../data/tables.dart' show UnlockMethod;

/// Whether the credential [SettingRow.unlockMethod] currently points at is
/// actually configured (GitHub #104). The single place that decides "is the
/// app really locked right now" — `app.dart`'s lock gate and `LockScreen`'s
/// body switch both call this rather than each keeping their own copy of
/// "which nullable column matters for which method."
bool hasUnlockCredential(SettingRow settings) =>
    switch (settings.unlockMethod) {
      UnlockMethod.pin => settings.passcodeHash != null,
      UnlockMethod.masterPhrase => settings.masterPhraseHash != null,
      UnlockMethod.totp => settings.totpSecret != null,
    };
