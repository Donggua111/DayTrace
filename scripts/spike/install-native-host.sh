#!/bin/zsh
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <native-host-executable> <unpacked-extension-id>" >&2
  exit 2
fi

HOST_EXECUTABLE="$1"
EXTENSION_ID="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../daytrace-identity.sh"
EXPECTED_EXTENSION_ID="$DAYTRACE_CHROME_EXTENSION_ID"
HOST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
MANIFEST_PATH="$HOST_DIR/$DAYTRACE_NATIVE_HOST_NAME.json"

[[ -x "$HOST_EXECUTABLE" ]] || { echo "Native host is not executable: $HOST_EXECUTABLE" >&2; exit 1; }
[[ "$EXTENSION_ID" != *"/"* && "$EXTENSION_ID" != *":"* ]] || { echo "Invalid extension ID" >&2; exit 1; }
[[ "$EXTENSION_ID" == "$EXPECTED_EXTENSION_ID" ]] || {
  echo "Unexpected DayTrace extension ID: $EXTENSION_ID" >&2
  echo "Expected installed development extension ID: $EXPECTED_EXTENSION_ID" >&2
  exit 1
}

mkdir -p "$HOST_DIR"
chmod 700 "$HOST_DIR"

TEMP_MANIFEST="$(mktemp "$HOST_DIR/.$DAYTRACE_NATIVE_HOST_NAME.XXXXXX")"
trap 'rm -f "$TEMP_MANIFEST"' EXIT

python3 - "$TEMP_MANIFEST" "$HOST_EXECUTABLE" "$EXTENSION_ID" "$DAYTRACE_NATIVE_HOST_NAME" <<'PY'
import json
import pathlib
import sys

path, executable, extension_id, host_name = sys.argv[1:]
payload = {
    "name": host_name,
    "description": "DayTrace Technical Spike native messaging host",
    "path": str(pathlib.Path(executable).resolve()),
    "type": "stdio",
    "allowed_origins": [f"chrome-extension://{extension_id}/"],
}
pathlib.Path(path).write_text(json.dumps(payload, indent=2) + "\n")
PY

chmod 600 "$TEMP_MANIFEST"
mv -f "$TEMP_MANIFEST" "$MANIFEST_PATH"
echo "Installed $MANIFEST_PATH"
