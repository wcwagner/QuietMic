#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$1"; DEVICE_ID="$2"; BUNDLE_ID="$3"

START_ISO="$(cat "$RUN_DIR/start.iso" 2>/dev/null || date -Iseconds)"
END_ISO="$(cat "$RUN_DIR/stop.iso"  2>/dev/null || date -Iseconds)"
echo "$END_ISO" > "$RUN_DIR/end.iso"

# Convert ISO 8601 timestamps to format expected by log collect: YYYY-MM-DD HH:MM:SS
START="$(python3 -c "import datetime; print(datetime.datetime.fromisoformat('$START_ISO'.replace('Z','+00:00')).strftime('%Y-%m-%d %H:%M:%S'))" 2>/dev/null || echo "$START_ISO")"
END="$(python3 -c "import datetime; print(datetime.datetime.fromisoformat('$END_ISO'.replace('Z','+00:00')).strftime('%Y-%m-%d %H:%M:%S'))" 2>/dev/null || echo "$END_ISO")"

# Unified log snapshot from the **device** (root required).
# NOTE: log collect supports --device/--device-name/--device-udid and --start|--last|--size.
# Using --device-name since --device-udid has issues on some systems.
# Also: collection must be over USB, not Wi‑Fi, or you'll see "Device not configured (6)".
DEVICE_NAME=$(xcrun devicectl list devices --hide-default-columns --columns Name --filter 'Platform == "iOS" AND State == "connected"' | tail -n +3 | head -n1)
IOS_ARCHIVE="$RUN_DIR/ios.logarchive"
COLLECT_LOG="$RUN_DIR/collect.log"
{
  echo "collect:start=$(date -Iseconds)"
  echo "device_udid=$DEVICE_ID"
  echo "device_name=$DEVICE_NAME"
  echo "window=$START → $END"
  # Keep the archive bounded during tight dev loops.
  sudo /usr/local/sbin/quietmic-log-collect \
    --device-name "$DEVICE_NAME" \
    --start "$START" \
    --size 50m \
    --output "$IOS_ARCHIVE"
  rc=$?
  echo "collect:rc=$rc"
  echo "collect:end=$(date -Iseconds)"
} >>"$COLLECT_LOG" 2>&1 || true

# Handle common failure cases with helpful diagnostics for the agent.
if [ ! -d "$IOS_ARCHIVE" ]; then
  if grep -q "Device not configured (6)" "$COLLECT_LOG"; then
    echo "⚠️  iOS device log snapshot failed: Device not configured (6)" | tee -a "$COLLECT_LOG"
    echo "Hints: ensure USB (not Wi‑Fi), device is trusted/paired, Developer Mode is enabled." | tee -a "$COLLECT_LOG"
    echo "You can quickly verify by opening Console.app and confirming the device streams logs." | tee -a "$COLLECT_LOG"
  else
    echo "⚠️  iOS device log snapshot failed; see $COLLECT_LOG" | tee -a "$COLLECT_LOG"
  fi
  # Fall back to previous behavior (Mac snapshot) so the pipeline still produces something.
  sudo /usr/local/sbin/quietmic-log-collect --last 10m --output "$RUN_DIR/mac.logarchive" >>"$COLLECT_LOG" 2>&1 || true
  IOS_ARCHIVE="$RUN_DIR/mac.logarchive"
fi
# Convert timestamps back to proper format for log show (which expects YYYY-MM-DD HH:MM:SS)
SHOW_START="$(python3 -c "import datetime; print(datetime.datetime.fromisoformat('$START_ISO'.replace('Z','+00:00')).strftime('%Y-%m-%d %H:%M:%S'))" 2>/dev/null || echo "$START_ISO")"
SHOW_END="$(python3 -c "import datetime; print(datetime.datetime.fromisoformat('$END_ISO'.replace('Z','+00:00')).strftime('%Y-%m-%d %H:%M:%S'))" 2>/dev/null || echo "$END_ISO")"

/usr/bin/log show --archive "$IOS_ARCHIVE" --style ndjson --info --debug \
  --start "$SHOW_START" --end "$SHOW_END" \
  --predicate 'subsystem IN {"AVFAudio","com.apple.audio","com.apple.runningboard","com.apple.activitykit"} OR process IN {"mediaserverd","audiomxd","SpringBoard","backboardd","assertiond","diagnosticd"} OR eventMessage CONTAINS[c] "Jetsam" OR processImagePath CONTAINS[c] "'"$BUNDLE_ID"'"' > "$RUN_DIR/unified.jsonl"

# App artifacts
mkdir -p "$RUN_DIR/artifacts"
xcrun devicectl device copy from --device "$DEVICE_ID" \
  --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
  --source "Documents" --destination "$RUN_DIR/artifacts" || true

# Prefer on-device persistent log if available (survives app restarts)
DEVICE_LOG="$RUN_DIR/artifacts/logs/app.jsonl"
if [ -f "$DEVICE_LOG" ] && [ -s "$DEVICE_LOG" ]; then
  echo "Using persistent on-device log (survives restarts)" >> "$COLLECT_LOG"
  cp "$DEVICE_LOG" "$RUN_DIR/app_persistent.jsonl"
fi

# Crash/Jetsam only for this window (filename timestamp filter)
mkdir -p "$RUN_DIR/systemCrashLogs"
LIST="$RUN_DIR/crash.list.txt"
xcrun devicectl device info files --device "$DEVICE_ID" --domain-type systemCrashLogs > "$LIST" || true
python3 - "$LIST" "$START_ISO" "$END_ISO" > "$RUN_DIR/crash.to_copy.txt" <<'PY'
import sys,re,datetime
src, start_s, end_s = sys.argv[1], sys.argv[2], sys.argv[3]
start = datetime.datetime.fromisoformat(start_s.replace('Z','+00:00'))
end   = datetime.datetime.fromisoformat(end_s.replace('Z','+00:00'))
pat=re.compile(r'(?:^|/)(?P<name>(?:JetsamEvent|panic-full|LowMemory|SpinDump|.*?)-(?P<stamp>\d{4}-\d{2}-\d{2}-\d{6}))(?:\.\w+)?$')
for line in open(src,encoding="utf-8",errors="ignore"):
    s=line.strip(); m=pat.search(s)
    if m:
        ts=datetime.datetime.strptime(m.group('stamp'),'%Y-%m-%d-%H%M%S').replace(tzinfo=start.tzinfo)
        if start <= ts <= end: print(s)
PY
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  xcrun devicectl device copy from --device "$DEVICE_ID" \
     --domain-type systemCrashLogs --source "$rel" \
     --destination "$RUN_DIR/systemCrashLogs" || true
done < "$RUN_DIR/crash.to_copy.txt"

# Tiny summary for the agent
python3 - "$RUN_DIR" <<'PY' > "$RUN_DIR/summary.json"
import os,json,glob,sys
d=sys.argv[1]
def size(p):
    try: return os.path.getsize(p)
    except: return 0
print(json.dumps({
  "start": open(os.path.join(d,'start.iso')).read().strip() if os.path.exists(os.path.join(d,'start.iso')) else None,
  "end":   open(os.path.join(d,'end.iso')).read().strip() if os.path.exists(os.path.join(d,'end.iso')) else None,
  "console_bytes": size(os.path.join(d,'console.txt')),
  "unified_jsonl_bytes": size(os.path.join(d,'unified.jsonl')),
  "crash_files": len(glob.glob(os.path.join(d,'systemCrashLogs','*'))),
  "artifacts": os.listdir(os.path.join(d,'artifacts')) if os.path.isdir(os.path.join(d,'artifacts')) else []
}, indent=2))
PY
