# ---- iOS 26 Agent Rails (non-blocking, latest-by-default, archivable) ----
APP_SCHEME      ?= QuietMic
CONFIG          ?= Debug
BUNDLE_ID       ?= com.williamwagner.QuietMic

# In-tree DerivedData so agents never chase Library paths.
DERIVED         ?= .derived
APP_PATH        ?= $(DERIVED)/Build/Products/$(CONFIG)-iphoneos/$(APP_SCHEME).app

# Require an explicit device when possible; fall back to auto-select with a loud echo.
DEVICE_ID       ?=
ifeq ($(strip $(DEVICE_ID)),)
DEVICE_ID       := $(shell xcrun devicectl list devices --hide-default-columns --columns Identifier --filter 'Platform == "iOS" AND State == "connected"' | tail -n +3 | head -n1)
WARN_DEVICE     := $(shell [ -z "$(DEVICE_ID)" ] && echo "NO_DEVICE" || true)
endif

# Session naming: default to 'latest' (overwritten). Use RUN_ID=slug to archive.
RUN_ID          ?= latest
RUN_ROOT        := runs
RUN_DIR         := $(RUN_ROOT)/$(if $(filter $(RUN_ID),latest),latest,archive/$(RUN_ID))

LOCK_DIR        := .locks
LOCK            := $(LOCK_DIR)/session.lock

CONSOLE_LOG     := $(RUN_DIR)/console.txt
SYSLOG_TXT      := $(RUN_DIR)/syslog.txt
AGENT_CONFIG    := $(RUN_DIR)/agent.json
START_ISO       := $(RUN_DIR)/start.iso
STOP_ISO        := $(RUN_DIR)/stop.iso
COLLECT_LOG     := $(RUN_DIR)/collect.log

# Hot-loop build artifacts (always overwritten)
BUILD_OUT       := build
BUILD_RAW_LOG   := $(BUILD_OUT)/_latest.raw.log
BUILD_PRETTY    := $(BUILD_OUT)/_latest.txt
XCRESULT        := $(BUILD_OUT)/_latest.xcresult
XCB             := $(shell command -v xcbeautify 2>/dev/null)

.PHONY: dev start stop status collect guard gen build install preseed tail clean prune build-only test-sim test-device help

dev: guard gen build install preseed start ## Build→install→launch (returns immediately)

guard:
	@mkdir -p $(RUN_DIR) $(LOCK_DIR) $(BUILD_OUT)
	@if [ -n "$(WARN_DEVICE)" ]; then echo "⚠️  auto-selected device: $(DEVICE_ID)"; fi
	@# Check for cooldown period to prevent immediate restart races
	@if [ -f "$(RUN_DIR)/cooldown.iso" ]; then \
		COOLDOWN_TIME=$$(cat "$(RUN_DIR)/cooldown.iso" 2>/dev/null || echo ""); \
		if [ -n "$$COOLDOWN_TIME" ]; then \
			echo "Respecting 2-second cooldown after previous stop..."; \
			sleep 2; \
		fi; \
	fi
	@if [ -d "$(LOCK)" ]; then \
	  if ps -p "$$(cat $(RUN_DIR)/supervisor.pid 2>/dev/null)" >/dev/null 2>&1; then \
	    echo "services already running (lock present)"; exit 1; \
	  else \
	    echo "stale lock found; cleaning"; rmdir "$(LOCK)"; \
	  fi \
	fi
	@mkdir "$(LOCK)"

gen:
	@xcodegen generate --use-cache

build: build-only
build-only:
	@rm -rf $(XCRESULT) $(BUILD_RAW_LOG) $(BUILD_PRETTY)
	xcodebuild \
	  -scheme $(APP_SCHEME) \
	  -configuration $(CONFIG) \
	  -sdk iphoneos \
	  -derivedDataPath $(DERIVED) \
	  -destination 'generic/platform=iOS' \
	  -resultBundlePath $(XCRESULT) \
	  build \
	  | tee $(BUILD_RAW_LOG) \
	  $(if $(XCB),| $(XCB) --quieter,) \
	  | tee $(BUILD_PRETTY)

install: build-only
	xcrun devicectl device install app --device $(DEVICE_ID) "$(APP_PATH)"

preseed:
	@printf '{ "run_id":"%s", "ts":"%s" }\n' "$(RUN_ID)" "$$(date -Iseconds)" > $(AGENT_CONFIG)
	xcrun devicectl device copy to \
	  --device $(DEVICE_ID) \
	  --domain-type appDataContainer \
	  --domain-identifier $(BUNDLE_ID) \
	  --source "$(AGENT_CONFIG)" \
	  --destination "Documents/agent.json"

# Start app in background: write start.iso, start syslog (if available), and launch supervisor.
start:
	@date -Iseconds > $(START_ISO)
	@( command -v cfgutil >/dev/null && cfgutil syslog > $(SYSLOG_TXT) ) & echo $$! > $(RUN_DIR)/syslog.pid || true
	@nohup bash bin/launch.sh "$(RUN_DIR)" "$(DEVICE_ID)" "$(BUNDLE_ID)" > "$(RUN_DIR)/supervisor.out" 2>&1 & echo $$! > "$(RUN_DIR)/supervisor.pid"
	@echo "launching $(BUNDLE_ID) on $(DEVICE_ID)..."
	@# Brief delay to allow early failure detection
	@sleep 3
	@# Check for immediate launch failures
	@if [ -f "$(RUN_DIR)/supervisor.out" ] && grep -q "ERROR:" "$(RUN_DIR)/supervisor.out" 2>/dev/null; then \
		echo "❌ Launch failed:"; \
		cat "$(RUN_DIR)/supervisor.out"; \
		echo "Run 'make status' for diagnostics"; \
		exit 1; \
	elif ps -p "$$(cat $(RUN_DIR)/supervisor.pid 2>/dev/null)" >/dev/null 2>&1; then \
		echo "✅ Launch attempted; supervisor running"; \
		echo "Run 'make status' to verify launch success"; \
	else \
		echo "⚠️  Launch supervisor exited unexpectedly"; \
		echo "Run 'make status' for diagnostics"; \
	fi

# Stop app on device, stop helpers, wait for supervisor to exit, then clear lock
stop:
	@bash bin/stop-app.sh "$(DEVICE_ID)" "$(BUNDLE_ID)" "$(RUN_DIR)" "$(APP_SCHEME)" || true
	-@kill "$$(cat $(RUN_DIR)/syslog.pid 2>/dev/null)" 2>/dev/null || true
	@# Wait for supervisor to finish before clearing lock (prevents race conditions)
	@if [ -f "$(RUN_DIR)/supervisor.pid" ]; then \
		SUP=$$(cat "$(RUN_DIR)/supervisor.pid" 2>/dev/null || echo); \
		if [ -n "$$SUP" ]; then \
			echo "Waiting for supervisor (PID $$SUP) to exit..."; \
			for i in $$(seq 1 20); do \
				ps -p "$$SUP" >/dev/null 2>&1 || break; \
				sleep 0.2; \
			done; \
		fi; \
	fi
	@# Ensure stop.iso is written and add cooldown timestamp
	@[ -f "$(RUN_DIR)/stop.iso" ] || date -Iseconds > "$(RUN_DIR)/stop.iso"
	@date -Iseconds > "$(RUN_DIR)/cooldown.iso"
	@rm -rf "$(LOCK)"

status:
	@echo "Session dir: $(RUN_DIR)"
	@printf "Supervisor: "; if ps -p "$$(cat $(RUN_DIR)/supervisor.pid 2>/dev/null)" >/dev/null 2>&1; then echo "RUNNING"; else echo "STOPPED"; fi
	@printf "Device app: "; \
	if xcrun devicectl device info processes --device "$(DEVICE_ID)" --json-output "$(RUN_DIR)/processes.json" >/dev/null 2>&1; then \
		PID=$$(jq -r --arg APP "$(APP_SCHEME)" '.result.runningProcesses[]|select(.executable|contains($$APP))|.processIdentifier' "$(RUN_DIR)/processes.json" 2>/dev/null); \
		if [ -n "$$PID" ]; then \
			if ps -p "$$(cat $(RUN_DIR)/supervisor.pid 2>/dev/null)" >/dev/null 2>&1; then \
				echo "pid=$$PID (RUNNING)"; \
			else \
				echo "pid=$$PID (UNSUPERVISED)"; \
			fi; \
		else \
			echo "not found"; \
		fi; \
	else \
		echo "device unavailable"; \
	fi
	@# Check for launch failures and show diagnostic
	@if [ -f "$(RUN_DIR)/supervisor.out" ] && grep -q "ERROR:" "$(RUN_DIR)/supervisor.out" 2>/dev/null; then \
		echo "Launch status: FAILED"; \
		if [ -f "$(CONSOLE_LOG)" ] && grep -q "Locked" "$(CONSOLE_LOG)" 2>/dev/null; then \
			echo "Reason: Device is locked"; \
		elif [ -f "$(CONSOLE_LOG)" ] && grep -q "crashed\|terminated" "$(CONSOLE_LOG)" 2>/dev/null; then \
			echo "Reason: App crashed during launch"; \
		else \
			echo "Reason: See console.txt for details"; \
		fi; \
	fi

# Always collect unified logs (passwordless via sudo wrapper), artifacts, and windowed crash/Jetsam for [start, stop|now].
collect:
	@echo "Collecting iOS device logs for $(DEVICE_ID)…"
	@bash bin/probe-ios-logging.sh "$(RUN_DIR)" "$(DEVICE_ID)" || true
	@bash bin/collect-logs.sh "$(RUN_DIR)" "$(DEVICE_ID)" "$(BUNDLE_ID)"

tail:
	@tail -f $(CONSOLE_LOG)

# Remove DerivedData, build, and 'latest'. Archives are kept until pruned.
clean:
	rm -rf $(DERIVED) $(BUILD_OUT) $(RUN_ROOT)/latest $(LOCK_DIR)

# Keep only the most recent N archives (default 10)
prune:
	@N=$${N:-10}; ls -1t $(RUN_ROOT)/archive 2>/dev/null | tail -n +$$((N+1)) | while read d; do rm -rf "$(RUN_ROOT)/archive/$$d"; done || true

help:
	@echo "dev [RUN_ID=latest|slug] [DEVICE_ID=…]  → build/install/launch (background)"
	@echo "stop | status | tail | collect | prune | clean"
	@echo "Default session: runs/latest. With RUN_ID=slug: runs/archive/<slug>."
