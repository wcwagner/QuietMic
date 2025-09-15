#!/usr/bin/env bash
set -euo pipefail
DEVICE_ID="$1"; BUNDLE_ID="$2"; RUN_DIR="$3"; APP_SCHEME="$4"

# Helper function to get PID using JSON parsing for reliability
get_app_pid() {
    if xcrun devicectl device info processes --device "$DEVICE_ID" --json-output "$RUN_DIR/processes.json" >/dev/null 2>&1; then
        jq -r --arg APP "$APP_SCHEME" '.result.runningProcesses[]|select(.executable|contains($APP))|.processIdentifier' \
           "$RUN_DIR/processes.json" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Find PID of our bundle on device using JSON-based detection
PID="$(get_app_pid)"
if [ -n "$PID" ]; then
    echo "Found app PID: $PID, sending SIGTERM..."
    xcrun devicectl device process signal --pid "$PID" --signal SIGTERM --device "$DEVICE_ID" || true

    # Wait for graceful termination (up to 4 seconds)
    for i in $(seq 1 20); do
        CUR_PID="$(get_app_pid)"
        [ -z "$CUR_PID" ] && break
        sleep 0.2
    done

    # Escalate to SIGKILL if still running
    CUR_PID="$(get_app_pid)"
    if [ -n "$CUR_PID" ]; then
        echo "App still running, escalating to SIGKILL..."
        xcrun devicectl device process signal --pid "$PID" --signal SIGKILL --device "$DEVICE_ID" || true
    fi
else
    echo "App not found on device (already stopped or not running)"
fi

# Give launch supervisor a moment to write stop.iso as devicectl returns.
sleep 1
[ -f "$RUN_DIR/stop.iso" ] || date -Iseconds > "$RUN_DIR/stop.iso"
