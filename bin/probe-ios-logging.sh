#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$1"; DEVICE_ID="$2"
OUT="$RUN_DIR/_probe.logarchive"
DEVICE_NAME=$(xcrun devicectl list devices --hide-default-columns --columns Name --filter 'Platform == "iOS" AND State == "connected"' | tail -n +3 | head -n1)
sudo /usr/local/sbin/quietmic-log-collect --device-name "$DEVICE_NAME" --last 30s --output "$OUT" >/dev/null 2>&1 || {
  echo "probe: failed (see requirements: USB, trusted/paired, Developer Mode)" ; exit 1 ; }
LINES=$( /usr/bin/log show --archive "$OUT" --last 30s --style syslog 2>/dev/null | wc -l | tr -d ' ' )
[ "$LINES" -gt 0 ] && echo "probe: ok ($LINES lines)" || { echo "probe: empty"; exit 2; }