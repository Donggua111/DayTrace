#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <native-host-executable>" >&2
  exit 2
fi

HOST_EXECUTABLE="$1"
[[ -x "$HOST_EXECUTABLE" ]] || { echo "Native host is not executable: $HOST_EXECUTABLE" >&2; exit 1; }

python3 - "$HOST_EXECUTABLE" <<'PY'
import json
import os
import pathlib
import socket
import struct
import subprocess
import sys
import tempfile

host = pathlib.Path(sys.argv[1]).resolve()

def frame(payload):
    body = json.dumps(payload, separators=(",", ":")).encode()
    return struct.pack("<I", len(body)) + body

def read_frame(stream):
    header = stream.read(4)
    if len(header) != 4:
        raise AssertionError("native host did not return a complete response header")
    length = struct.unpack("<I", header)[0]
    body = stream.read(length)
    if len(body) != length:
        raise AssertionError("native host did not return a complete response body")
    return json.loads(body)

with tempfile.TemporaryDirectory(dir="/private/tmp", prefix="dt-host-") as home:
    socket_path = pathlib.Path(home) / "Library/Application Support/DayTrace/Spike/daytrace.sock"
    socket_path.parent.mkdir(parents=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(socket_path))
    server.listen(1)
    server.settimeout(3)

    environment = os.environ.copy()
    environment["HOME"] = home
    process = subprocess.Popen(
        [str(host)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        env=environment,
    )

    valid = {"schemaVersion": 1, "type": "activeDomainChanged", "domain": "chatgpt.com"}
    process.stdin.write(frame(valid))
    process.stdin.flush()
    connection, _ = server.accept()
    forwarded = connection.recv(4096)
    connection.close()
    assert json.loads(forwarded.decode().strip()) == valid, forwarded
    assert read_frame(process.stdout)["accepted"] is True

    forbidden = {**valid, "url": "https://chatgpt.com/private?secret=should-not-cross"}
    process.stdin.write(frame(forbidden))
    process.stdin.flush()
    response = read_frame(process.stdout)
    assert response["accepted"] is False, response

    process.stdin.close()
    process.wait(timeout=3)
    server.close()
    if process.returncode != 0:
        raise AssertionError(process.stderr.read().decode())

print("Native host verification passed: valid sanitized domain forwarded; forbidden URL field rejected.")
PY
