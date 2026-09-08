#!/bin/zsh
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <DayTrace.app> <DayTraceNativeHost> [--allow-unsigned]" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/daytrace-identity.sh"
APP_SOURCE="$(cd "$1" && pwd)"
HOST_SOURCE="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
ALLOW_UNSIGNED="${3:-}"
APP_DEST="$HOME/Applications/$DAYTRACE_PRODUCT_NAME.app"
HOST_DEST="$HOME/$DAYTRACE_NATIVE_HOST_RELATIVE_PATH"

[[ -d "$APP_SOURCE" && -f "$APP_SOURCE/Contents/Info.plist" ]] || { echo "DayTrace.app is invalid: $APP_SOURCE" >&2; exit 1; }
[[ -x "$APP_SOURCE/Contents/MacOS/DayTrace" ]] || { echo "DayTrace executable is missing or not executable" >&2; exit 1; }
[[ -x "$HOST_SOURCE" ]] || { echo "Native host is missing or not executable: $HOST_SOURCE" >&2; exit 1; }

BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$APP_SOURCE/Contents/Info.plist")"
[[ "$BUNDLE_ID" == "$DAYTRACE_DEVELOPMENT_BUNDLE_ID" || ( -n "$DAYTRACE_PRODUCTION_BUNDLE_ID" && "$BUNDLE_ID" == "$DAYTRACE_PRODUCTION_BUNDLE_ID" ) ]] || {
  echo "Unexpected DayTrace Bundle ID: $BUNDLE_ID" >&2
  exit 1
}

SIGNING_DETAILS="$(codesign -dv --verbose=4 "$APP_SOURCE" 2>&1 || true)"
if ! codesign --verify --deep --strict --verbose=2 "$APP_SOURCE" >/dev/null 2>&1; then
  [[ "$ALLOW_UNSIGNED" == "--allow-unsigned" ]] || {
    echo "DayTrace.app is not a verified signed Development build; pass --allow-unsigned only for non-TCC automation installs." >&2
    exit 1
  }
elif ! print -r -- "$SIGNING_DETAILS" | grep -q 'Authority=Apple Development' && [[ "$ALLOW_UNSIGNED" != "--allow-unsigned" ]]; then
  echo "DayTrace.app is signed, but not with Apple Development; refusing a TCC runtime install." >&2
  exit 1
fi

mkdir -p "$HOME/Applications"
STAGING_DIR="$(mktemp -d "$HOME/Applications/.DayTrace-install.XXXXXX")"
cleanup() { rm -rf "$STAGING_DIR"; }
trap cleanup EXIT
ditto "$APP_SOURCE" "$STAGING_DIR/$DAYTRACE_PRODUCT_NAME.app"

PREVIOUS_APP=""
if [[ -e "$APP_DEST" ]]; then
  PREVIOUS_APP="$HOME/Applications/.DayTrace.previous.$(date +%Y%m%d-%H%M%S)"
  mv "$APP_DEST" "$PREVIOUS_APP"
fi
if ! mv "$STAGING_DIR/$DAYTRACE_PRODUCT_NAME.app" "$APP_DEST"; then
  [[ -n "$PREVIOUS_APP" && -e "$PREVIOUS_APP" ]] && mv "$PREVIOUS_APP" "$APP_DEST"
  exit 1
fi

HOST_DIR="$(dirname "$HOST_DEST")"
mkdir -p "$HOST_DIR"
chmod 700 "$HOST_DIR"
HOST_TEMP="$(mktemp "$HOST_DIR/.DayTraceNativeHost.XXXXXX")"
trap 'rm -f "$HOST_TEMP"; cleanup' EXIT
ditto "$HOST_SOURCE" "$HOST_TEMP"
chmod 700 "$HOST_TEMP"
mv -f "$HOST_TEMP" "$HOST_DEST"

"$ROOT_DIR/scripts/spike/install-native-host.sh" "$HOST_DEST" "$DAYTRACE_CHROME_EXTENSION_ID"
echo "Installed $APP_DEST"
echo "Native Host: $HOST_DEST"
if [[ -n "$PREVIOUS_APP" ]]; then
  echo "Previous app retained for rollback: $PREVIOUS_APP"
fi
