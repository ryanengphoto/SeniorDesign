# USB Hub Operator Console

Local dashboard for monitoring and controlling the hardware-secure USB hub. Runs against a mock device by default — no custom hardware required.

## Structure

| Path | Role |
| --- | --- |
| `backend/` | FastAPI server, WebSocket telemetry, mock hub simulator |
| `frontend/` | Vite + React dashboard |

## Prerequisites

- Python 3.11+
- Node.js 20+ (22 recommended)

## Run locally

From the repo root:

```bash
make -C GUI dev
```

Or from `GUI/`:

```bash
make stop         # free ports if stuck
make dev          # recommended — backend + frontend (one terminal)
make backend      # API only (port 8000)
make frontend     # dashboard only — backend must already be running
```

Open the **dashboard** at [http://localhost:5173](http://localhost:5173) — not port 8000 (API only).

Prototype status: see [`state.md`](state.md).

## Mock demo behavior

- Port 1 starts disconnected; port 0 shows an authorized flash drive.
- ~5 s: port 1 begins enumerating.
- ~8 s: port 1 authorizes as a keyboard.
- ~15 s: port 1 is quarantined for `KEYSTROKE_BURST` unless you isolate it first.

Use **Isolate**, **Restore**, and **Clear fault** on any port to test the control loop.

## API

| Endpoint | Description |
| --- | --- |
| `GET /api/health` | `{"status": "ok", "mode": "mock"}` |
| `WS /ws` | Snapshot on connect, then telemetry @ 10 Hz + events |

Commands (host → backend) over WebSocket:

```json
{ "type": "command", "cmd": "isolate_port", "port": 1 }
{ "type": "command", "cmd": "restore_port", "port": 1 }
{ "type": "command", "cmd": "clear_fault", "port": 1 }
```

## Environment

| Variable | Default | Description |
| --- | --- | --- |
| `HUB_MODE` | `mock` | `mock` or `serial` (serial not implemented yet) |
| `SERIAL_PORT` | `/dev/ttyACM0` | Future MCU serial device path |

## Production build

```bash
cd GUI/frontend && npm run build
```

Serve `frontend/dist/` behind any static host; point WebSocket proxy at the backend on port 8000.
