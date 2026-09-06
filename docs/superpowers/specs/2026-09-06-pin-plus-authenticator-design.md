# PIN + Authenticator (true 2FA) + paste-to-enter — design spec

Date: 2026-09-06
Status: implemented
GitHub: #111

## Background

GitHub #104 gave the lock screen a choice of exactly **one** front door — PIN,
master password, or authenticator app (TOTP) — deliberately *not* a
combination, because that issue's reporter explicitly asked for alternatives,
not stacking (see that spec's "Non-goals").

This issue asks for the opposite for users who want it: a way to require
**both** a PIN and an authenticator code, entered one after the other, for
anyone who wants real two-factor protection rather than a single front door.
It also asks for a "paste" shortcut on the authenticator code entry keypad,
so a code copied from an authenticator app (or a password manager that also
stores TOTP secrets) never needs to be retyped digit by digit.

## Data model

`UnlockMethod` (`data/tables.dart`) gains a fourth case, `pinAndTotp`,
alongside the three GitHub #104 already added. No schema migration is
needed — the column is a plain `TEXT` (`textEnum<UnlockMethod>()`), and
Drift's generated converter maps it off `UnlockMethod.values` at runtime, not
a hardcoded list. Existing rows are unaffected; the new value is only ever
written when a user explicitly opts in.

`hasUnlockCredential` (`core/security/unlock_method.dart`) requires **both**
halves for this case:

```dart
UnlockMethod.pinAndTotp =>
    settings.passcodeHash != null && settings.totpSecret != null,
```

— a half-configured combo (say, the TOTP secret got cleared some other way)
must not read as "locked" on the PIN alone, the same "all or nothing per
method" rule every other case already follows.

## Setting it up: a two-hop wizard, not a single screen

Settings ▸ Security gains a fourth radio row, "PIN + Authenticator", next to
the original three. Tapping it when both halves already exist just switches
`unlockMethod` immediately, same as any other already-configured method.

When one or both halves are missing, there's no dedicated "set up the combo"
screen — it reuses the existing PIN and TOTP setup screens, chained:

- `_selectUnlockMethod` in `settings_screen.dart` routes to whichever setup
  screen is missing its credential, with a `?combine=true` query param:
  `/more/settings/passcode?combine=true` if there's no PIN yet, otherwise
  `/more/settings/totp/setup?combine=true`.
- `SetPasscodeScreen.combineWithTotp` / `TotpSetupScreen.combineWithPin` read
  that flag. On success:
  - If the *other* half is now also configured, it calls
    `setUnlockMethod(UnlockMethod.pinAndTotp)` immediately (overriding
    `setPasscode`/`setupTotp`'s own "activate me alone" default) and pops
    back to Settings.
  - If not, it chains onward with `context.pushReplacement` (not `push`) to
    the other screen, still carrying `combine=true` — `pushReplacement` so
    backing out of that second step lands on Settings, not back on the first
    (already-completed) step.

This means the same two screens serve three purposes (set up PIN alone, set
up TOTP alone, set up either half of the combo) with no new screen to keep in
sync with the other two.

## Unlocking: PIN, then a code — never either alone

`LockScreen` gets a `_PinTotpStep` (`pin` / `totp`) local to the widget,
reset to `pin` every time the screen is freshly mounted (i.e. every re-lock).
`_buildPinBody` and `_buildTotpBody` both take a `combined` flag:

- The PIN step (`combined: true`) uses `_onCombinedPinDigit` /
  `_submitCombinedPin` instead of the plain-PIN handlers. A **correct** PIN
  here only advances `_pinTotpStep` to `totp` — it never calls `onUnlocked`
  and never resets the wrong-attempt counter. A **wrong** PIN increments the
  same shared `failedPasscodeAttempts` counter every method already uses, and
  re-prompts for the PIN.
- The TOTP step (`combined: true`) uses `_onCombinedTotpDigit` /
  `_submitCombinedTotp`. Only a **correct** code here resets the counter and
  calls `onUnlocked` — completing both factors is what actually unlocks.

Reusing the shared `failedPasscodeAttempts` counter (rather than a second,
combo-specific one) means the existing master-phrase fallback
(`masterPhraseAttemptThreshold`) protects the combo exactly the way it
already protects every other method, with no new UI concept.

**Biometric is deliberately withheld on the combined PIN step.** It's
documented (GitHub #104) as a shortcut for PIN entry only; letting a
fingerprint silently skip straight past the PIN step of a two-factor flow
would turn "both factors required" into "just a fingerprint", defeating the
point. `_buildPinBody(combined: true)` passes `extraKey: null` regardless of
`biometricEnabled`.

## Turning either half off

- `clearPasscode` (removing the PIN) now falls back to `totp` when
  `pinAndTotp` was active — the authenticator half still works standalone,
  so there's no reason to leave the app with no unlock method at all.
- `clearTotp` (turning off the authenticator app) already fell back to `pin`
  when `totp` alone was active (GitHub #104); this now also covers
  `pinAndTotp` for the same reason — a `pinAndTotp` setup always has a PIN
  configured (required to activate the combo in the first place), so `pin`
  is always a real, working fallback, never a credential that doesn't exist.
- `TotpVerifyScreen`'s "turned off" snackbar reads "PIN unlock only" instead
  of the generic message when the combo was active, so the user isn't left
  guessing what unlock now actually requires.

## Paste-to-enter (GitHub #111's other ask)

`core/security/paste_code_key.dart` adds:

- `pasteDigitsFromClipboard(onCode)` — reads `Clipboard.getData`, strips
  everything but digits (`RegExp('[^0-9]')`), and calls `onCode` with
  whatever's left. Silently does nothing on an empty/non-numeric clipboard,
  rather than clearing whatever the user already typed.
- `PasteCodeKey` — an `IconButton` (paste icon, "Paste code" tooltip) sized
  for the same bottom-left `extraKey` slot `LockScreenKeypad` already gives
  the PIN pad's biometric shortcut.

Wired into every authenticator-code keypad:

- `LockScreen`'s single-method TOTP body and the combined flow's TOTP step
  (`_onPasteTotp`, dispatching to `_submitTotp` or `_submitCombinedTotp`
  depending which is live).
- `TotpSetupScreen`'s confirm step (`_onPaste`).
- `TotpVerifyScreen` (turning the authenticator off) (`_onPaste`).

Behavior in every case: fill the code field with up to 6 digits from the
clipboard, and if that reaches the full 6, submit immediately — exactly as
if it had been typed key by key. Fewer than 6 just fills in what's there,
leaving the keypad free to finish it. This is deliberately **not** offered on
PIN entry — a PIN is short enough to type and isn't the thing a password
manager or authenticator app hands you pre-copied; the ask was specifically
about not having to read six digits off a phone screen and retype them.

## What stays out of scope

- No other combinations (PIN + phrase, phrase + TOTP, all three at once) —
  #111 asked specifically for PIN + Authenticator; the pattern here
  (`UnlockMethod` gains one case per supported combo, `hasUnlockCredential`
  matches it, `LockScreen` gets a step enum) generalizes if that's ever
  asked for, but isn't built speculatively here.
- The combined PIN step still doesn't offer biometric — see above.
