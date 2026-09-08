#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <DayTrace.app-or-dmg>" >&2
  exit 2
fi
ARTIFACT="$1"
PROFILE="${DAYTRACE_NOTARY_PROFILE:-}"
[[ -f "$ARTIFACT" || -d "$ARTIFACT" ]] || { echo "Artifact not found: $ARTIFACT" >&2; exit 1; }
[[ -n "$PROFILE" ]] || { echo "Notarization credentials pending: set DAYTRACE_NOTARY_PROFILE to an existing notarytool Keychain profile." >&2; exit 3; }

xcrun notarytool submit "$ARTIFACT" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$ARTIFACT"
xcrun stapler validate "$ARTIFACT"
echo "Notarization and stapling passed."
