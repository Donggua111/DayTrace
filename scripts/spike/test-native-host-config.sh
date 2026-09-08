#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/daytrace-identity.sh"
EXPECTED_EXTENSION_ID="$DAYTRACE_CHROME_EXTENSION_ID"
STALE_EXTENSION_ID="mmnoopahcchjobiajm""hembdlipkhbjgo"
SERVICE_WORKER="$ROOT_DIR/extension/chrome/service-worker.js"
INSTALLER="$ROOT_DIR/scripts/spike/install-native-host.sh"

grep -Fq "const HOST_NAME = \"$DAYTRACE_NATIVE_HOST_NAME\";" "$SERVICE_WORKER"
grep -Fq 'DAYTRACE_CHROME_EXTENSION_ID=' "$ROOT_DIR/scripts/daytrace-identity.sh"
grep -Fq 'source "$SCRIPT_DIR/../daytrace-identity.sh"' "$INSTALLER"

if rg -n -F "$STALE_EXTENSION_ID" "$ROOT_DIR" \
  --glob '!scripts/spike/test-native-host-config.sh' \
  --glob '!*.xcresult/**' --glob '!DerivedData/**'; then
  echo "Stale DayTrace Chrome extension ID is present in repository configuration." >&2
  exit 1
fi

echo "Native host configuration passed: host name and canonical extension identity are consistent."
