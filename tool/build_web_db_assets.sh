#!/usr/bin/env bash
# The two files the web build's database needs next to index.html:
#
#   web/sqlite3.wasm     SQLite itself, from the sqlite3.dart release that
#                        matches pubspec.lock's `sqlite3` — checksum-pinned.
#   web/drift_worker.js  drift's worker, compiled from the locked drift.
#
# Rerun after bumping either package (and update SQLITE3_SHA256).
#
# Usage: bash tool/build_web_db_assets.sh
set -euo pipefail

SQLITE3_VERSION="2.9.4"
SQLITE3_SHA256="922a76b182b6af69b030c8e2fdd3283ecc8e827248b20e4b1f3f3db170b52117"

locked=$(awk '$0=="  sqlite3:"{f=1} f&&/version:/{gsub(/"/,"",$2); print $2; exit}' pubspec.lock)
if [ "$locked" != "$SQLITE3_VERSION" ]; then
  echo "pubspec.lock has sqlite3 $locked, this script pins $SQLITE3_VERSION." >&2
  echo "Update SQLITE3_VERSION and SQLITE3_SHA256 first." >&2
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -sSfL -o "$tmp/sqlite3.wasm" \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$SQLITE3_VERSION/sqlite3.wasm"
echo "$SQLITE3_SHA256  $tmp/sqlite3.wasm" | sha256sum -c --quiet -
cp "$tmp/sqlite3.wasm" web/sqlite3.wasm

dart compile js -O4 -o web/drift_worker.js tool/web/drift_worker.dart
# dart2js leaves these beside its output; only the worker itself ships.
rm -f web/drift_worker.js.deps web/drift_worker.js.map

echo "web/sqlite3.wasm and web/drift_worker.js are up to date."
