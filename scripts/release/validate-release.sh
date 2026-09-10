#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/daytrace-identity.sh"
OUTPUT_DIR="${DAYTRACE_RELEASE_OUTPUT_DIR:-$HOME/Applications/DayTrace/ReleaseArtifacts}"
APP_PATH="${1:-$OUTPUT_DIR/DayTrace.app}"
[[ -d "$APP_PATH" ]] || { echo "DayTrace.app not found: $APP_PATH" >&2; exit 1; }
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$APP_PATH/Contents/Info.plist")" == "$DAYTRACE_PRODUCTION_BUNDLE_ID" ]] || { echo "Unexpected Bundle ID" >&2; exit 1; }
file "$APP_PATH/Contents/MacOS/DayTrace" | grep -q 'arm64' || { echo "App is not arm64" >&2; exit 1; }
if codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null 2>&1; then
  codesign --display --verbose=4 "$APP_PATH" 2>&1 | rg 'Identifier=|TeamIdentifier=|Authority=' || true
  spctl --assess --type execute --verbose "$APP_PATH"
else
  echo "Unsigned local artifact validated structurally; Gatekeeper assessment skipped. NOT FOR DISTRIBUTION."
fi
