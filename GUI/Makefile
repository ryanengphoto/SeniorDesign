# Operator console — Flutter app in app/
# Run from GUI/ (make dev) or repo root (make -C GUI dev).
# Prototype on Linux/web; Windows .exe is a release packaging target (build on Windows).

APP_DIR := app
FLUTTER ?= $(HOME)/flutter/bin/flutter
WEB_PORT ?= 7357
WEB_HOST ?= 127.0.0.1
LINUX_RELEASE_BIN := $(APP_DIR)/build/linux/x64/release/bundle/hub_console
LINUX_DEBUG_BIN := $(APP_DIR)/build/linux/x64/debug/bundle/hub_console

# Tier-1 serial bring-up (PTY + mcu_sim — NOT real PCB hardware)
SERIAL_PORT ?= /tmp/hub_host
MCU_SIM_PORT ?= /tmp/hub_mcu
SERIAL_BAUD ?= 115200
HUB_MODE ?= serial
PYTHON ?= python3
SOCAT_PID_FILE := /tmp/hub_socat.pid
MCU_SIM_PID_FILE := /tmp/hub_mcu_sim.pid

export PATH := $(HOME)/flutter/bin:$(HOME)/.local/bin:$(PATH)

.PHONY: help dev linux run-linux web windows install analyze test test-serial \
	build build-web build-linux build-windows stop doctor \
	linux-serial sim-pty sim-mcu sim-mcu-i ensure-pty stop-sim tier1-check

.DEFAULT_GOAL := help

help:
	@echo "USB Hub operator console (Flutter — GUI/)"
	@echo ""
	@echo "  Prototype (Linux / WSL):"
	@echo "  make dev            Launch mock console (web) at http://$(WEB_HOST):$(WEB_PORT)"
	@echo "  make web            Same as make dev"
	@echo "  make linux          Build+run native Linux desktop (debug, mock)"
	@echo "  make run-linux      Run an already-built Linux binary (release, else debug)"
	@echo ""
	@echo "  Tier-1 serial (PTY + mcu_sim — dummy peer, not PCB):"
	@echo "  make sim-pty        Start socat PTY pair (/tmp/hub_mcu ↔ /tmp/hub_host)"
	@echo "  make sim-mcu        Run mcu_sim.py on $(MCU_SIM_PORT) (timed demo)"
	@echo "  make sim-mcu-i      Interactive mcu_sim REPL (trigger burst/isolate yourself)"
	@echo "  make linux-serial   Flutter linux with HUB_MODE=serial SERIAL_PORT=$(SERIAL_PORT)"
	@echo "  make tier1-check    Automated PTY protocol check (socat + mcu_sim)"
	@echo "  make stop-sim       Stop background socat / mcu_sim from make sim-pty"
	@echo ""
	@echo "  Release packages:"
	@echo "  make build-web      Web → app/build/web/  (portable in any browser)"
	@echo "  make build-linux    Linux release → app/build/linux/.../release/bundle/"
	@echo "  make build-windows  Windows .exe  → app/build/windows/.../Release/"
	@echo "                      (must run on Windows with Visual Studio + Flutter)"
	@echo "  make build          Alias for build-web"
	@echo "  make windows        Alias for build-windows"
	@echo ""
	@echo "  Quality:"
	@echo "  make install        flutter pub get"
	@echo "  make analyze        Static analysis"
	@echo "  make test           Unit + widget + serial Tier-1 tests"
	@echo "  make test-serial    SerialDevice PTY test only (needs linux build lib)"
	@echo "  make stop           Stop process on port $(WEB_PORT)"
	@echo "  make doctor         flutter doctor"
	@echo ""
	@echo "Prerequisite: Flutter SDK at \$$HOME/flutter (or set FLUTTER=...)."
	@echo "Default HUB_MODE=mock — not real hub hardware."

install:
	cd $(APP_DIR) && $(FLUTTER) pub get

doctor:
	$(FLUTTER) doctor

analyze: install
	cd $(APP_DIR) && $(FLUTTER) analyze

# Bundle lib path for flutter_libserialport in `flutter test` (PTY uses dart:io fallback too).
SERIAL_LIB_DIR := $(APP_DIR)/build/linux/x64/debug/bundle/lib

test: install
	@if [ -f "$(SERIAL_LIB_DIR)/libserialport.so" ]; then \
		cd $(APP_DIR) && LD_LIBRARY_PATH="$(CURDIR)/$(SERIAL_LIB_DIR):$${LD_LIBRARY_PATH:-}" $(FLUTTER) test; \
	else \
		echo "NOTE: No linux bundle lib yet — building debug linux for libserialport.so"; \
		cd $(APP_DIR) && $(FLUTTER) build linux --debug; \
		cd $(APP_DIR) && LD_LIBRARY_PATH="$(CURDIR)/$(SERIAL_LIB_DIR):$${LD_LIBRARY_PATH:-}" $(FLUTTER) test; \
	fi

test-serial: install
	@if [ ! -f "$(SERIAL_LIB_DIR)/libserialport.so" ]; then \
		cd $(APP_DIR) && $(FLUTTER) build linux --debug; \
	fi
	cd $(APP_DIR) && LD_LIBRARY_PATH="$(CURDIR)/$(SERIAL_LIB_DIR):$${LD_LIBRARY_PATH:-}" \
		$(FLUTTER) test test/serial_tier1_test.dart

# One-command mock preview: Flutter web-server + open browser when possible.
dev web: install
	@bash scripts/run_web.sh $(WEB_HOST) $(WEB_PORT)

linux: install
	cd $(APP_DIR) && $(FLUTTER) run -d linux

# Native Linux + UART backend. Peer is often mcu_sim over PTY — still not PCB.
linux-serial: install
	cd $(APP_DIR) && $(FLUTTER) run -d linux \
		--dart-define=HUB_MODE=$(HUB_MODE) \
		--dart-define=SERIAL_PORT=$(SERIAL_PORT) \
		--dart-define=SERIAL_BAUD=$(SERIAL_BAUD)

# Background PTY pair for Tier-1 (socat if present, else scripts/pty_pair.py).
sim-pty:
	@if [ -f "$(SOCAT_PID_FILE)" ] && kill -0 $$(cat "$(SOCAT_PID_FILE)") 2>/dev/null; then \
		echo "PTY bridge already running (pid $$(cat $(SOCAT_PID_FILE)))"; \
	else \
		rm -f "$(MCU_SIM_PORT)" "$(SERIAL_PORT)"; \
		if command -v socat >/dev/null; then \
			socat -d -d PTY,link=$(MCU_SIM_PORT),raw,echo=0 \
				PTY,link=$(SERIAL_PORT),raw,echo=0 \
				> /tmp/hub_socat.log 2>&1 & echo $$! > "$(SOCAT_PID_FILE)"; \
			echo "PTY pair via socat: $(MCU_SIM_PORT) ↔ $(SERIAL_PORT)"; \
		else \
			chmod +x scripts/pty_pair.py 2>/dev/null || true; \
			$(PYTHON) scripts/pty_pair.py \
				--mcu-link $(MCU_SIM_PORT) --host-link $(SERIAL_PORT) \
				> /tmp/hub_socat.log 2>&1 & echo $$! > "$(SOCAT_PID_FILE)"; \
			echo "PTY pair via pty_pair.py (socat not installed): $(MCU_SIM_PORT) ↔ $(SERIAL_PORT)"; \
		fi; \
		sleep 0.4; \
		echo "pid $$(cat $(SOCAT_PID_FILE)) — mcu_sim is a DUMMY peer (not PCB)."; \
	fi

ensure-pty:
	@if [ ! -e "$(MCU_SIM_PORT)" ] || [ ! -e "$(SERIAL_PORT)" ]; then \
		echo "PTY links missing — starting sim-pty ($(MCU_SIM_PORT) ↔ $(SERIAL_PORT))"; \
		$(MAKE) sim-pty; \
	fi
	@if [ ! -e "$(MCU_SIM_PORT)" ]; then \
		echo "ERROR: $(MCU_SIM_PORT) still missing. Check /tmp/hub_socat.log" >&2; \
		exit 1; \
	fi

# Timed demo. Starts sim-pty automatically if /tmp/hub_mcu is missing.
sim-mcu: ensure-pty
	@chmod +x scripts/mcu_sim.py 2>/dev/null || true
	$(PYTHON) scripts/mcu_sim.py --port $(MCU_SIM_PORT) --baud $(SERIAL_BAUD)

# Interactive REPL — you trigger events; timed script off by default.
sim-mcu-i: ensure-pty
	@chmod +x scripts/mcu_sim.py 2>/dev/null || true
	$(PYTHON) scripts/mcu_sim.py --port $(MCU_SIM_PORT) --baud $(SERIAL_BAUD) -i

# Headless protocol check: PTY + mcu_sim + host read/write (no Flutter GUI).
tier1-check: stop-sim
	@$(MAKE) sim-pty
	@$(PYTHON) scripts/tier1_pty_check.py \
		--host-port $(SERIAL_PORT) \
		--mcu-port $(MCU_SIM_PORT) \
		--baud $(SERIAL_BAUD)
	@$(MAKE) stop-sim

stop-sim:
	@# Only kill via pid files — avoid `pkill -f` (matches this recipe's shell).
	@if [ -f "$(MCU_SIM_PID_FILE)" ]; then \
		kill $$(cat "$(MCU_SIM_PID_FILE)") 2>/dev/null || true; \
		rm -f "$(MCU_SIM_PID_FILE)"; \
	fi
	@if [ -f "$(SOCAT_PID_FILE)" ]; then \
		kill $$(cat "$(SOCAT_PID_FILE)") 2>/dev/null || true; \
		rm -f "$(SOCAT_PID_FILE)"; \
	fi
	@rm -f "$(MCU_SIM_PORT)" "$(SERIAL_PORT)"
	@echo "Stopped Tier-1 sim processes (if any)."

# Launch a previously built Linux desktop binary without recompiling.
# Prefers release; falls back to debug (from `make linux`).
run-linux:
	@if [ -x "$(LINUX_RELEASE_BIN)" ]; then \
		echo "Running release: $(LINUX_RELEASE_BIN)"; \
		cd "$(dir $(LINUX_RELEASE_BIN))" && ./hub_console; \
	elif [ -x "$(LINUX_DEBUG_BIN)" ]; then \
		echo "Running debug: $(LINUX_DEBUG_BIN)"; \
		echo "(No release build yet — use 'make build-linux' for one.)"; \
		cd "$(dir $(LINUX_DEBUG_BIN))" && ./hub_console; \
	else \
		printf '%s\n' \
		  "ERROR: No Linux build found." \
		  "  make linux         # build+run debug" \
		  "  make build-linux   # build release, then make run-linux" \
		  >&2; \
		exit 1; \
	fi

# --- Release builds ---

build build-web: install
	cd $(APP_DIR) && $(FLUTTER) build web --release
	@echo "Web build: $(APP_DIR)/build/web/"

build-linux: install
	cd $(APP_DIR) && $(FLUTTER) build linux --release
	@echo "Linux bundle: $(APP_DIR)/build/linux/x64/release/bundle/"

# Windows cannot be cross-compiled from Linux/WSL. Fail fast with instructions.
windows build-windows: install
	@uname_s=$$(uname -s 2>/dev/null || echo unknown); \
	case "$$uname_s" in \
	  MINGW*|MSYS*|CYGWIN*|Windows_NT) \
	    cd $(APP_DIR) && $(FLUTTER) build windows --release; \
	    echo "Windows Release folder: $(APP_DIR)/build/windows/x64/runner/Release/"; \
	    echo "Zip that whole folder for a portable demo (exe + DLLs)."; \
	    ;; \
	  *) \
	    printf '%s\n' \
	      "ERROR: Windows .exe must be built on a Windows host (not $$uname_s / WSL)." \
	      "" \
	      "On Windows (PowerShell), with Flutter + Visual Studio Desktop C++ workload:" \
	      "  cd GUI/app" \
	      "  flutter pub get" \
	      "  flutter build windows --release" \
	      "" \
	      "Or from GUI/:  .\\scripts\\build_windows.ps1" \
	      "Output: app/build/windows/x64/runner/Release/  (zip the whole folder)" \
	      >&2; \
	    exit 1; \
	    ;; \
	esac

stop:
	-fuser -k $(WEB_PORT)/tcp 2>/dev/null
