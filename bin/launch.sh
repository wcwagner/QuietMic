#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$1"; DEVICE_ID="$2"; BUNDLE_ID="$3"

CONSOLE="$RUN_DIR/console.txt"
LAUNCH_PID_FILE="$RUN_DIR/devicectl.pid"
STOP_ISO="$RUN_DIR/stop.iso"

# Launch app; this process blocks until the on-device app exits (by design).
# We nohup in Makefile; here we just background to capture the PID then wait.
xcrun devicectl device process launch --console --terminate-existing \
  --device "$DEVICE_ID" "$BUNDLE_ID" >> "$CONSOLE" 2>&1 &
child=$!
echo "$child" > "$LAUNCH_PID_FILE"

# When the device process exits, stamp stop time and drop the session lock if it still exists.
wait "$child" || true
date -Iseconds > "$STOP_ISO"
[ -d ".locks/session.lock" ] && rmdir ".locks/session.lock" || true
