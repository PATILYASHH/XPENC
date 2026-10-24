#!/usr/bin/env bash
# XPENC web, built for xpenc.in/web — with its built-in Connector when
# tool/web/connector.local.json is there (gitignored):
#
#   {
#     "CONNECTOR_AUTH_URL": "https://<project>.supabase.co",
#     "CONNECTOR_ANON_KEY": "<the Connector app's SUPABASE_ANON_KEY>"
#   }
#
# The same Supabase project the Connector app signs in with. Without the
# file the build has no Connector at all — fully offline. Not under web/:
# everything there is copied into the published build.
#
# Then copy build/web (minus .symbols) to website/web/ to deploy it.
#
# Usage: bash tool/build_web.sh
set -euo pipefail

defines=()
if [ -f tool/web/connector.local.json ]; then
  defines=(--dart-define-from-file=tool/web/connector.local.json)
else
  echo "No tool/web/connector.local.json: building without Connector." >&2
fi

rm -rf build/web
# MSYS_NO_PATHCONV: Git Bash would otherwise turn /web/ into a Windows path.
MSYS_NO_PATHCONV=1 flutter build web --release --base-href /web/ "${defines[@]}"

for f in index.html flutter_bootstrap.js main.dart.js sqlite3.wasm \
  drift_worker.js sw.js manifest.json; do
  [ -f "build/web/$f" ] || { echo "build/web/$f is missing" >&2; exit 1; }
done
