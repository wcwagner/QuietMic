#!/usr/bin/env bash
set -euo pipefail
DEVICE_ID="$1"; BUNDLE_ID="$2"; RUN_DIR="$3"

# Find PID of our bundle on device, if any, then send SIGTERM. Fall back to SIGKILL if needed.
PID="$(xcrun devicectl device info processes --device "$DEVICE_ID" | awk '/^[0-9]+/ && $0 ~ /'"$BUNDLE_ID"'/ {print $1; exit}')"
if [ -n "$PID" ]; then
  xcrun devicectl device process signal --pid "$PID" --signal SIGTERM --device "$DEVICE_ID" || true
  # small grace
  sleep 1
  xcrun devicectl device info processes --device "$DEVICE_ID" | grep -q "^[[:space:]]*$PID[[:space:]]" && \
    xcrun devicectl device process signal --pid "$PID" --signal SIGKILL --device "$DEVICE_ID" || true
fi

# Give launch supervisor a moment to write stop.iso as devicectl returns.
sleep 1
[ -f "$RUN_DIR/stop.iso" ] || date -Iseconds > "$RUN_DIR/stop.iso"
