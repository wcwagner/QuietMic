# QuietMic TODO

## Current Branch
- Branch: `bug/make-collect`
- Status: 1 commit ahead of origin (unpushed)
- Related Issue: #6 "make collect captures no iOS app logs from device"

## Oracle Review Implementation

### ✅ Done
- [x] Create AGENTS.md with workflow documentation

### ✅ Completed (Oracle Quick Wins)

#### 1. Add UIBackgroundModes to Info.plist via XcodeGen
- Modified `project.yml` to include `UIBackgroundModes: ["audio"]`
- Prevents iOS from terminating background audio recording sessions

#### 2. Persistent JSON Logs (Documents/logs/app.jsonl)
- Modified `Logger.swift` to write JSON lines to both stdout AND on-device file
- Updated `collect-logs.sh` to copy persistent log as `app_persistent.jsonl`
- Survives app restarts and UNSUPERVISED scenarios

#### 4. Add `make doctor` Dependency Checks
- New target validates: jq, python3, xcodegen, xcrun
- Checks sudo wrapper configuration
- Verifies iOS device connectivity and trust status
- Run `make doctor` anytime to diagnose environment issues

#### 5. Programmatic AppIntent Launching (INVESTIGATE)
- **Effort:** M (research + implementation)
- **Why:** Enable automated stress testing (`make repro LOOPS=100`)
- **Options to explore:**
  - Shortcuts CLI: `shortcuts run "ShortcutName"`
  - URL schemes: Custom URL → AppIntent
  - XCUITest: UI automation on device
- **Benefit:** Deterministic repro harness for timing/race bugs

### 📋 Medium Priority

- [ ] Archive dSYMs per run (if Jetsam reports become relevant)
- [ ] Add `make run N=10s` one-shot helper (dev → sleep → stop → collect)
- [ ] Tighten unified log predicates (add app subsystem explicitly)
- [ ] Document jq/python3 as required dependencies in AGENTS.md

### ✅ Recently Resolved

**Issue #6: Device log collection** (Commit b249492)
- Problem: `log collect --device-udid` failed with "Device not configured (6)"
- Solution: Switched to `--device-name` in collect-logs.sh
- Result: Now captures 97K+ iOS device log entries including:
  - 443 QuietMic app references
  - SpringBoard/FrontBoard UI system activity
  - RunningBoard process lifecycle
  - audiomxd subsystem logs
- Impact: 100x increase in log data (105MB vs 1MB) with full iOS visibility

### ⏸️ Deferred (Not Needed Yet)

- dSYM symbolication (no crash stacks, only RunningBoard terminations)
- MetricKit integration (overkill for current debugging needs)
- Stress/repro harness (blocked on #5 programmatic launching)

---

## Notes from Oracle Review

**What's Working:**
- Session-based artifact collection ✅
- Time-windowed log correlation ✅
- Non-blocking supervisor pattern ✅
- Agent-friendly deterministic paths ✅

**Key Insight:** Stop adding infra after quick wins. Focus shifts to:
1. Reliable log capture (persistent logs)
2. Environment validation (doctor checks)
3. Repro automation (programmatic AppIntent)

Then: **Use the logs to actually fix the audio session termination bugs.**
