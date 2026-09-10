#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/daytrace-identity.sh"
OUTPUT_DIR="${DAYTRACE_RELEASE_OUTPUT_DIR:-$HOME/Applications/DayTrace/ReleaseArtifacts}"
APP_PATH="${1:-$OUTPUT_DIR/DayTrace.app}"
OUTPUT_PATH="${2:-$OUTPUT_DIR/DayTrace-local.dmg}"
[[ -d "$APP_PATH" ]] || { echo "DayTrace.app not found: $APP_PATH" >&2; exit 1; }
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$APP_PATH/Contents/Info.plist")" == "$DAYTRACE_PRODUCTION_BUNDLE_ID" ]] || { echo "Unexpected Bundle ID" >&2; exit 1; }
mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -f "$OUTPUT_PATH"
hdiutil create -volname DayTrace -srcfolder "$APP_PATH" -ov -format UDZO "$OUTPUT_PATH"
echo "Created local DMG: $OUTPUT_PATH"
echo "NOT FOR DISTRIBUTION until Developer ID signing, notarization, stapling, and Gatekeeper validation pass."
