# Choice of unlock method + TOTP — design spec

Date: 2026-09-06
Status: implemented
GitHub: #104

## Background

Today the lock screen is a fixed hierarchy: a PIN is always the front door.
A master recovery phrase, if set, is **only** a fallback offered after too
many wrong PINs (`Settings.masterPhraseAttemptThreshold`) — it's never a
front-door method on its own; `_XpencAppState` only decides to lock the app
at all by checking `passcodeHash != null` (`app.dart:264`), so a phrase with
no PIN behind it currently can't lock the app.

Issue #104 asks for two things, confirmed with the reporter across the
thread:
- Let the user **pick** their primary unlock method instead of PIN always
  winning — the reporter specifically wants master password sometimes,
  since a password manager can paste it in with no typing.
- A **TOTP** (Google-Authenticator-style) option too, for situations where
  typing anything on screen is a shoulder-surfing risk (a train, a
  meeting). The reporter was explicit: "OTP only, not PIN + OTP or master
  password + OTP" — these are alternative front doors, not stacked factors.

## Data model

`Settings` gets two new columns (schema v63 → v64):

- `unlockMethod` (`UnlockMethod` enum: `pin` / `masterPhrase` / `totp`,
  default `pin`) — which credential is the active front door. Defaults to
  `pin` so every existing installed carries on exactly as today.
- `totpSecret` (nullable text) — a base32 TOTP secret. Unlike the passcode/
  phrase hashes, this **must** be stored recoverable, not hashed — the
  whole point is recomputing the current code to compare against. This
  isn't a new trust boundary for the app: the entire ledger already lives
  in the same plaintext local SQLite file, so a plaintext secret here
  carries the same "only as safe as the device itself" guarantee everything
  else in `Settings`/`Transactions` already has. The lock screen guards the
  *UI*, not the on-disk file.

`hasUnlockCredential(SettingRow)` (`core/security/unlock_method.dart`) is
the single place that maps `unlockMethod` to "does its credential actually
exist" — `app.dart`'s lock gate and `LockScreen`'s body switch both call it,
so there is exactly one definition of "is the app actually locked right
now," never three copies drifting apart.

## TOTP algorithm

`core/security/totp.dart` wraps the `otp` package:

- `OTP.randomSecret()` — a 10-byte, base32-encoded secret (Google
  Authenticator's own default size).
- Codes are generated/verified with `algorithm: Algorithm.SHA1,
  isGoogle: true` explicitly — mainstream authenticator apps (Google
  Authenticator, Authy, Microsoft Authenticator, …) hard-code SHA1
  regardless of what an `otpauth://` URI's `algorithm` param says, so the
  provisioning URI omits that param entirely and the server side matches
  their behavior rather than the RFC's SHA256 library default.
- `Totp.verify` checks the current 30s step plus one step either side
  (±30s) so a phone with a slightly-off clock, or a code typed right at a
  step boundary, still works — the same tolerance window most TOTP server
  implementations use.
- `otp: 3.1.3` is pinned (not `^3.2.0`) — 3.1.4+ adds a `timezone`
  dependency that conflicts with `flutter_local_notifications`' own pin.
  3.1.3 predates that and has the identical API we use.

## The "lost my phone" problem, and how it's solved for free

A PIN can be reset by whoever holds the device; a lost phrase is written
down somewhere. A lost/uninstalled authenticator app is different — nothing
in the device itself can regenerate a TOTP secret. Making TOTP a firstclass
front door without an escape hatch would risk permanently locking someone
out of their own ledger.

The fix reuses infrastructure that already exists rather than inventing a
new recovery flow: the wrong-attempt-count fallback
(`failedPasscodeAttempts` / `masterPhraseAttemptThreshold`) that today only
protects PIN entry is generalized to protect **whichever method is active**:

```dart
final canFallBackToPhrase = hasMasterPhrase && unlockMethod != UnlockMethod.masterPhrase;
final phraseLocked = canFallBackToPhrase && failedAttempts >= threshold;
```

So: set up a master phrase *and* choose TOTP as your active method, and too
many wrong/missing codes drops you into the exact same phrase-entry screen
that already exists for "too many wrong PINs." No new UI concept, no new
column beyond what already tracks this for PIN. If no phrase is configured,
a lost TOTP device is a hard lockout — the same place a lost PIN with no
phrase already leaves someone today (recoverable only via backup restore).
This is called out explicitly in the TOTP setup screen's warning copy.

`unlockMethod == masterPhrase` has no further fallback in this pass — it
already *is* the fallback mechanism; falling back to itself is a no-op.

## Settings UI

Security section gains an **"Unlock method"** selector (radio list: PIN /
Master password / Authenticator app) above the existing per-method
management blocks:

- Tapping a method that has no credential yet navigates to its setup flow;
  saving there both stores the credential and switches `unlockMethod` to
  it.
- Tapping a method that's already configured just flips `unlockMethod`
  immediately — no re-setup needed to switch back and forth.
- Each method's own management tile (set/change PIN, set/turn off master
  phrase, set up/turn off authenticator app) stays independently visible
  regardless of which one is currently active — configuring a phrase as a
  *fallback* while PIN is active, for instance, still works exactly as it
  does today.

Turning off the authenticator app requires entering a current code first —
same reasoning `MasterPhraseVerifyScreen` already documents for turning off
the phrase: proves whoever is disabling it actually holds it.

## What stays PIN-specific (deliberate, not an oversight)

- **Biometric unlock** stays a shortcut for PIN entry only. Extending it to
  "fingerprint instead of a TOTP code" is a reasonable follow-up but a
  separate change to `local_auth` wiring — out of scope here.
- **"Lock after" (timeout)** and **"Lock screen style"** apply regardless of
  active method — both PIN and TOTP entry reuse the same numeric keypad UI
  (`LockScreenKeypad`, just switched to a 6-digit length for TOTP), and the
  backgrounding timeout is a property of "the app is locked," not of any
  one method. `setPinTimeoutMinutes`'s guard changes from "a PIN is set" to
  `hasUnlockCredential`, so it also works for master-phrase-primary/TOTP-
  primary setups.

## Backup restore

`importAll` already reads `passcodeHash`/`masterPhraseHash` (and biometric)
from the *local* row before wiping, then writes them back after loading the
backup — a backup taken before a passcode/phrase existed must not silently
turn locking off or swap in a stale credential on restore.
`unlockMethod`/`totpSecret` get the identical treatment: whatever the
device is actually locked with survives an import untouched, regardless of
what the backup file itself contains.

## Non-goals (v1)

- No multi-factor combination (PIN *and* TOTP, etc.) — the reporter
  explicitly asked for alternatives, not stacking.
- No re-showing a previously-generated TOTP secret/QR after setup closes —
  matches the master phrase's own "shown once, then gone" precedent.
