#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/daytrace-identity.sh"
OUTPUT_DIR="${DAYTRACE_RELEASE_OUTPUT_DIR:-$HOME/Applications/DayTrace/ReleaseArtifacts}"
DERIVED_DATA="/private/tmp/DayTraceReleaseBuild"
APP_OUTPUT="$OUTPUT_DIR/$DAYTRACE_PRODUCT_NAME.app"
ALLOW_UNSIGNED=""
if [[ "${1:-}" == "--allow-unsigned" ]]; then ALLOW_UNSIGNED="--allow-unsigned"; shift; fi
[[ $# -eq 0 ]] || { echo "usage: $0 [--allow-unsigned]" >&2; exit 2; }

rm -rf "$DERIVED_DATA" "$APP_OUTPUT" "$OUTPUT_DIR/release-manifest.json"
mkdir -p "$OUTPUT_DIR"
SIGNING_SETTING="YES"
[[ -n "$ALLOW_UNSIGNED" ]] && SIGNING_SETTING="NO"

xcodebuild \
  -project "$ROOT_DIR/app/DayTraceSpike/DayTrace.xcodeproj" \
  -scheme DayTrace \
  -configuration Release \
  -sdk macosx \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  CODE_SIGNING_ALLOWED="$SIGNING_SETTING"

xcodebuild \
  -project "$ROOT_DIR/app/DayTraceSpike/DayTrace.xcodeproj" \
  -scheme DayTraceNativeHost \
  -configuration Release \
  -sdk macosx \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  CODE_SIGNING_ALLOWED="$SIGNING_SETTING"

BUILT_APP="$DERIVED_DATA/Build/Products/Release/$DAYTRACE_PRODUCT_NAME.app"
BUILT_NATIVE_HOST="$DERIVED_DATA/Build/Products/Release/DayTraceNativeHost"
[[ -d "$BUILT_APP" ]] || { echo "Release app product missing" >&2; exit 1; }
[[ -x "$BUILT_NATIVE_HOST" ]] || { echo "Release native host product missing or not executable" >&2; exit 1; }
ditto --norsrc --noextattr "$BUILT_APP" "$APP_OUTPUT"
ditto --norsrc --noextattr "$BUILT_NATIVE_HOST" "$OUTPUT_DIR/DayTraceNativeHost"

strip_fileprovider_metadata() {
  local target="$1"
  xattr -d com.apple.FinderInfo "$target" >/dev/null 2>&1 || true
  xattr -d 'com.apple.fileprovider.fpfs#P' "$target" >/dev/null 2>&1 || true
}

strip_fileprovider_metadata "$APP_OUTPUT"
strip_fileprovider_metadata "$OUTPUT_DIR/DayTraceNativeHost"

BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$APP_OUTPUT/Contents/Info.plist")"
MARKETING_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$APP_OUTPUT/Contents/Info.plist")"
BUILD_VERSION="$(plutil -extract CFBundleVersion raw -o - "$APP_OUTPUT/Contents/Info.plist")"
ARCHITECTURE="$(file "$APP_OUTPUT/Contents/MacOS/DayTrace")"
print -r -- "$ARCHITECTURE" | grep -q 'arm64' || { echo "Release app is not arm64" >&2; exit 1; }
NATIVE_HOST_ARCHITECTURE="$(file "$OUTPUT_DIR/DayTraceNativeHost")"
print -r -- "$NATIVE_HOST_ARCHITECTURE" | grep -q 'arm64' || { echo "Release native host is not arm64" >&2; exit 1; }

SIGNED="false"
TEAM_IDENTIFIER=""
if codesign --verify --deep --strict --verbose=2 "$APP_OUTPUT" >/dev/null 2>&1; then
  SIGNED="true"
  SIGNING_DETAILS="$(codesign -dv --verbose=4 "$APP_OUTPUT" 2>&1 || true)"
  TEAM_IDENTIFIER="$(print -r -- "$SIGNING_DETAILS" | sed -n 's/^TeamIdentifier=//p' | head -1)"
fi

NATIVE_HOST_CODESIGN_STATUS="unsigned"
if codesign --verify --strict --verbose=2 "$OUTPUT_DIR/DayTraceNativeHost" >/dev/null 2>&1; then
  NATIVE_HOST_SIGNING_DETAILS="$(codesign -dv --verbose=4 "$OUTPUT_DIR/DayTraceNativeHost" 2>&1 || true)"
  if print -r -- "$NATIVE_HOST_SIGNING_DETAILS" | rg -q '^Authority='; then
    NATIVE_HOST_CODESIGN_STATUS="signed"
  else
    NATIVE_HOST_CODESIGN_STATUS="adhoc"
  fi
fi

GIT_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$OUTPUT_DIR/release-manifest.json" "$MARKETING_VERSION" "$BUILD_VERSION" "$BUNDLE_ID" "$GIT_COMMIT" "$TEAM_IDENTIFIER" "$SIGNED" "$CREATED_AT" "$DAYTRACE_NATIVE_HOST_NAME" "$DAYTRACE_CHROME_EXTENSION_ID" "$NATIVE_HOST_CODESIGN_STATUS" <<'PY'
import json
import pathlib
import sys

path, version, build, bundle_id, commit, team, signed, created_at, native_host, extension_id, native_host_codesign = sys.argv[1:]
payload = {
    "product": "DayTrace",
    "version": version,
    "build": build,
    "bundleID": bundle_id,
    "gitCommit": commit,
    "architecture": "arm64",
    "nativeHostArtifact": "DayTraceNativeHost",
    "nativeHostCodesignStatus": native_host_codesign,
    "codesignStatus": "verified" if signed == "true" else "unsigned",
    "teamIdentifier": team or None,
    "nativeHostName": native_host,
    "chromeExtensionID": extension_id,
    "notarizationStatus": "not-run",
    "createdAt": created_at,
}
pathlib.Path(path).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
PY

if [[ "$SIGNED" == "true" ]]; then
  echo "Release artifact ready: $APP_OUTPUT"
else
  echo "Release artifact built unsigned: NOT FOR DISTRIBUTION"
fi
echo "Release manifest: $OUTPUT_DIR/release-manifest.json"
