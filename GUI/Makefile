# Operator console — run from GUI/ (make dev) or repo root (make -C GUI dev).
# All paths are relative to this directory.

BACKEND_DIR := backend
FRONTEND_DIR := frontend
VENV := $(BACKEND_DIR)/.venv
VENV_BIN := $(VENV)/bin
PYTHON := $(VENV_BIN)/python
PIP := $(VENV_BIN)/pip
UVICORN := $(VENV_BIN)/uvicorn

BACKEND_PORT ?= 8000
FRONTEND_PORT ?= 5173
BACKEND_URL := http://127.0.0.1:$(BACKEND_PORT)

.PHONY: help dev backend frontend install install-backend install-frontend build stop wait-backend require-backend

.DEFAULT_GOAL := help

help:
	@echo "USB Hub operator console (GUI/)"
	@echo ""
	@echo "  make dev              Install deps, start backend, then frontend"
	@echo "  make backend          Backend only  → $(BACKEND_URL)"
	@echo "  make frontend         Frontend only → http://localhost:$(FRONTEND_PORT) (backend must already run)"
	@echo "  make install          Install backend + frontend dependencies"
	@echo "  make install-backend  Python venv + pip install -e backend/"
	@echo "  make install-frontend npm install in frontend/"
	@echo "  make build            Production build (frontend/dist/)"
	@echo "  make stop             Stop processes on ports $(BACKEND_PORT) and $(FRONTEND_PORT)"
	@echo ""
	@echo "Open the dashboard at http://localhost:$(FRONTEND_PORT) (not the backend port)."

$(VENV_BIN)/python:
	cd $(BACKEND_DIR) && python3 -m venv .venv

install-backend: $(VENV_BIN)/python
	$(PIP) install -e ./$(BACKEND_DIR)

install-frontend:
	cd $(FRONTEND_DIR) && npm install

install: install-backend install-frontend

wait-backend:
	@echo "Waiting for backend at $(BACKEND_URL)/api/health ..."
	@ok=0; \
	for i in $$(seq 1 60); do \
		if curl -sf "$(BACKEND_URL)/api/health" >/dev/null 2>&1; then \
			ok=1; \
			break; \
		fi; \
		sleep 0.25; \
	done; \
	if [ "$$ok" != "1" ]; then \
		echo "ERROR: Backend did not become ready on port $(BACKEND_PORT)." >&2; \
		exit 1; \
	fi; \
	echo "Backend ready."

require-backend:
	@curl -sf "$(BACKEND_URL)/api/health" >/dev/null 2>&1 || { \
		echo "ERROR: Backend is not running on port $(BACKEND_PORT)." >&2; \
		echo "  Use 'make dev' (both), or run 'make backend' in another terminal first." >&2; \
		exit 1; \
	}

backend: install-backend
	cd $(BACKEND_DIR) && $(UVICORN) src.main:app --reload --port $(BACKEND_PORT)

frontend: install-frontend require-backend
	cd $(FRONTEND_DIR) && npm run dev -- --port $(FRONTEND_PORT)

# Start backend in background, wait until healthy, then run frontend in foreground.
# Ctrl+C stops both.
dev: install
	@set -e; \
	cd $(BACKEND_DIR) && $(UVICORN) src.main:app --reload --port $(BACKEND_PORT) & \
	backend_pid=$$!; \
	trap 'kill $$backend_pid 2>/dev/null || true' INT TERM EXIT; \
	$(MAKE) wait-backend; \
	cd $(FRONTEND_DIR) && npm run dev -- --port $(FRONTEND_PORT); \
	wait $$backend_pid 2>/dev/null || true

build: install-frontend
	cd $(FRONTEND_DIR) && npm run build

stop:
	-fuser -k $(BACKEND_PORT)/tcp $(FRONTEND_PORT)/tcp 2>/dev/null
