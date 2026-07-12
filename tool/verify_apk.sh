#!/usr/bin/env bash
# Gate an APK before it ships.
#
# Why this exists: every unit test overrides `dbProvider` with an in-memory
# `NativeDatabase.memory()`, so nothing ever exercised the real `driftDatabase()`
# path. An APK once shipped without `libsqlite3.so` and crashed on first open
# with "dlopen failed: library libsqlite3.so not found" — every screen stuck on
# a loading spinner. `flutter analyze` and 77 green tests said nothing.
#
# Usage: bash tool/verify_apk.sh [path/to/app.apk]
set -uo pipefail

APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
fail=0

say()  { printf '%s\n' "$*"; }
ok()   { printf '  OK    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; fail=1; }

say "Verifying: $APK"
if [ ! -f "$APK" ]; then
  say "APK not found."
  exit 1
fi

libs=$(unzip -l "$APK" 2>/dev/null | grep -oE 'lib/[^/]+/lib[^ ]*\.so' || true)

# 1. The native SQLite library must be present for every shipped ABI.
abis=$(printf '%s\n' "$libs" | grep -oE 'lib/[^/]+/' | sort -u)
if [ -z "$abis" ]; then
  bad "no native libraries at all"
else
  for abi in $abis; do
    if printf '%s\n' "$libs" | grep -q "^${abi}libsqlite3\.so$"; then
      ok "${abi}libsqlite3.so"
    else
      # Flutter's own libapp/libflutter mark a real code ABI; helper-only ABIs
      # (e.g. shipped by a plugin) don't need sqlite3.
      if printf '%s\n' "$libs" | grep -q "^${abi}libflutter\.so$"; then
        bad "${abi} has libflutter.so but NO libsqlite3.so -> app will crash on DB open"
      fi
    fi
  done
fi

# 2. Flutter engine + compiled Dart must be there.
printf '%s\n' "$libs" | grep -q 'libflutter\.so' && ok "libflutter.so" || bad "libflutter.so missing"
printf '%s\n' "$libs" | grep -q 'libapp\.so'     && ok "libapp.so"     || bad "libapp.so missing (not a release build?)"

# 3. Permissions we rely on / deliberately avoid.
if command -v aapt2 >/dev/null 2>&1 || command -v aapt >/dev/null 2>&1; then
  AAPT=$(command -v aapt2 || command -v aapt)
  perms=$("$AAPT" dump permissions "$APK" 2>/dev/null || true)
  printf '%s' "$perms" | grep -q 'android.permission.READ_SMS' \
    && ok "READ_SMS declared" || bad "READ_SMS missing -> message capture dead"
  if printf '%s' "$perms" | grep -q 'android.permission.RECEIVE_SMS'; then
    bad "RECEIVE_SMS declared -- we deliberately do not use a broadcast receiver"
  else
    ok "RECEIVE_SMS absent (as designed)"
  fi
else
  say "  skip  permission checks (aapt not on PATH)"
fi

size=$(du -m "$APK" | cut -f1)
say ""
say "Size: ${size} MB"

if [ "$fail" -ne 0 ]; then
  say ""
  say "APK VERIFICATION FAILED -- do not ship this build."
  exit 1
fi
say "APK verification passed."
