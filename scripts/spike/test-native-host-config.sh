#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
EXPECTED_EXTENSION_ID="mmnoopahcchjobiajnhembdlipkhbjgo"
STALE_EXTENSION_ID="mmnoopahcchjobiajmhembdlipkhbjgo"
SERVICE_WORKER="$ROOT_DIR/extension/chrome/service-worker.js"
INSTALLER="$ROOT_DIR/scripts/spike/install-native-host.sh"

grep -Fq 'const HOST_NAME = "com.daytrace.spike";' "$SERVICE_WORKER"
grep -Fq "EXPECTED_EXTENSION_ID=\"$EXPECTED_EXTENSION_ID\"" "$INSTALLER"

if rg -n -F "$STALE_EXTENSION_ID" "$ROOT_DIR" \
  --glob '!scripts/spike/test-native-host-config.sh' \
  --glob '!*.xcresult/**' --glob '!DerivedData/**'; then
  echo "Stale DayTrace Chrome extension ID is present in repository configuration." >&2
  exit 1
fi

echo "Native host configuration passed: host name and canonical extension identity are consistent."
