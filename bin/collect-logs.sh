#!/usr/bin/env bash
set -euo pipefail
RUN_DIR="$1"; DEVICE_ID="$2"; BUNDLE_ID="$3"

START="$(cat "$RUN_DIR/start.iso" 2>/dev/null || date -Iseconds)"
END="$(cat "$RUN_DIR/stop.iso"  2>/dev/null || date -Iseconds)"
echo "$END" > "$RUN_DIR/end.iso"

# Unified log snapshot (root required) + small NDJSON export of relevant subsystems/processes.
# Uses secure sudo wrapper for passwordless log collection
sudo /usr/local/sbin/quietmic-log-collect --device-udid "$DEVICE_ID" --start "$START" --end "$END" --output "$RUN_DIR/device.logarchive"
log show --archive "$RUN_DIR/device.logarchive" --style ndjson --info --debug \
  --predicate 'subsystem IN {"AVFAudio","com.apple.runningboard","com.apple.activitykit"} \
               OR process IN {"mediaserverd","SpringBoard","backboardd","assertiond","diagnosticd"} \
               OR eventMessage CONTAINS[c] "Jetsam" \
               OR processImagePath CONTAINS[c] "'"$BUNDLE_ID"'"' > "$RUN_DIR/unified.jsonl"

# App artifacts
mkdir -p "$RUN_DIR/artifacts"
xcrun devicectl device copy from --device "$DEVICE_ID" \
  --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
  --source "Documents" --destination "$RUN_DIR/artifacts" || true

# Crash/Jetsam only for this window (filename timestamp filter)
mkdir -p "$RUN_DIR/systemCrashLogs"
LIST="$RUN_DIR/crash.list.txt"
xcrun devicectl device info files --device "$DEVICE_ID" --domain-type systemCrashLogs > "$LIST" || true
python3 - "$LIST" "$START" "$END" > "$RUN_DIR/crash.to_copy.txt" <<'PY'
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
python3 - <<'PY' > "$RUN_DIR/summary.json"
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
"$RUN_DIR"
