# GUI prototype state

**Last updated:** 2026-09-01  
**Status:** Software-only prototype — dashboard and API are real; all hub data is simulated.

**Run:** `make dev` from `GUI/` → dashboard at http://localhost:5173 (mode badge shows `MOCK`).

---

## Next steps (work in this order)

### Priority — hardware integration

- [ ] Implement `SerialDevice` in `backend/src/serial_device.py` (USB-CDC/UART, newline-delimited JSON)
- [ ] MCU firmware speaking the same JSON contract (`Docs/firmwmare_slop.md`)
- [ ] Wire real telemetry: INA219 `vbus_mv` / `current_ma`, FPGA descriptor fields over SPI
- [ ] Forward host commands (`isolate_port`, `restore_port`, `clear_fault`) to MCU → FPGA
- [ ] Verify end-to-end: `HUB_MODE=serial` with hardware on the bench
- [ ] Production WebSocket URL / reverse-proxy config for non-dev deploy (`useHubSocket.ts`)

### Recommended — quality and demo

- [ ] Add unit or integration tests (protocol parsing, mock commands, WebSocket smoke test)
- [ ] Human-readable USB class names in port cards (hex only today)
- [ ] Expand mock or serial path to surface threat codes 1, 3–6 (only 2 and 7 demoed today)
- [ ] Persistent event log export (file/DB)

### Deferred (out of current v1 scope)

- [ ] Policy editor (VID/class whitelist UI)
- [ ] Scenario replay UI / recorded demo files
- [ ] Configurable HID thresholds from GUI
- [ ] Authentication / multi-user access
- [ ] Global system status UI (FPGA reset, external 5 V, hub power mode)
- [ ] Settings page
- [ ] Link from `Website/` to operator console (if desired publicly)

---

## At a glance

| Layer | Status |
| --- | --- |
| Operator dashboard (React) | **Built** — single-page console |
| Host backend (FastAPI + WebSocket) | **Built** — bridges UI to device layer |
| JSON host↔MCU protocol | **Defined** — models in `backend/src/protocol.py` |
| Mock hub simulator | **Built** — default data source |
| Real MCU / serial integration | **Not built** — stub only |
| Policy editor, scenario replay | **Not built** — out of v1 scope |
| Automated tests | **Not built** |

---

## What this is (vs `Website/`)

| | `Website/` | `GUI/` |
| --- | --- | --- |
| Purpose | Public project page for committee / portfolio | Operator console for the device |
| Audience | Visitors | Team / demo / future operators |
| Data | Static copy | Live telemetry + commands |
| Stack | Astro | Vite + React + FastAPI |

---

## Architecture (current)

```
Browser (localhost:5173)
    │  WebSocket /ws  (proxied by Vite in dev)
    ▼
FastAPI backend (localhost:8000)
    │  HubService
    ▼
MockDevice  ←── default (HUB_MODE=mock)
SerialDevice ←── stub (HUB_MODE=serial, not implemented)
```

In production intent, `SerialDevice` would read newline-delimited JSON from the STM32 USB-CDC/UART link described in `Docs/firmwmare_slop.md`. The frontend would not change.

---

## Built and real

These parts are functional prototype code, not placeholders.

### Tooling

- `Makefile` — `make dev`, `make backend`, `make frontend`, `make install`, `make stop`
- `GUI/.gitignore` — Python venv, egg-info, `node_modules`, `dist`, etc.
- `GUI/README.md`, `GUI/AGENTS.md` — run instructions and agent conventions

### Backend (`backend/`)

| Component | File | Notes |
| --- | --- | --- |
| HTTP health | `src/main.py` | `GET /api/health` → `{"status":"ok","mode":"mock"}` |
| WebSocket API | `src/main.py` | `WS /ws` — snapshot on connect, telemetry @ 10 Hz, command handling |
| Protocol models | `src/protocol.py` | Pydantic types for telemetry, events, commands, threat codes 0–7 |
| Hub orchestration | `src/hub_service.py` | Event ring buffer (200), change detection, command routing |
| CORS | `src/main.py` | Allows `localhost:5173` |

### Frontend (`frontend/`)

| Component | File | Notes |
| --- | --- | --- |
| Dashboard layout | `src/App.tsx` | Header, 2×2 port grid, event log panel |
| WebSocket client | `src/hooks/useHubSocket.ts` | Connect, reconnect with backoff, snapshot/telemetry/events |
| Port cards | `src/components/PortCard.tsx` | State, VID/PID, classes, VBUS, current, actions |
| Threat display | `src/components/ThreatBadge.tsx` | Shown when `threat_code > 0` |
| Event log | `src/components/EventLog.tsx` | Scrollable log, pause-on-hover |
| Connection banner | `src/components/ConnectionBanner.tsx` | Connected dot + mode badge |
| Types | `src/types/protocol.ts` | Mirrors backend protocol |
| Styling | `src/styles/global.css` | Dark theme aligned with `Website/` palette |
| Dev proxy | `vite.config.ts` | Proxies `/api` and `/ws` to port 8000 |
| Production build | `npm run build` | Outputs `frontend/dist/` |

### Protocol (host ↔ device contract)

Defined in code and used end-to-end in mock mode:

**MCU → host:** `telemetry`, `event`, `snapshot` (backend extension for UI on connect)

**Host → MCU:** `isolate_port`, `restore_port`, `clear_fault`

**Enums:** port states (`DISCONNECTED` … `MANUAL_BLOCKED`); threat codes 0–7 per `Docs/fabric_slop.md` §6

---

## Dummy / simulated (not real hardware)

Everything below is **in-memory fiction** when `HUB_MODE=mock` (the default).

### MockDevice (`backend/src/mock_device.py`)

| Behavior | How it is faked |
| --- | --- |
| Port 0 at startup | Hard-coded SanDisk-like flash drive (`0x0781:0x5583`, storage class `0x08`, ~5 V, ~42 mA) |
| Ports 2–3 | Disconnected, zero readings |
| Port 1 demo script | Timed sequence: ~5 s enumerate → ~8 s keyboard → ~15 s `KEYSTROKE_BURST` quarantine |
| Current readings | Random ±3 mA jitter on powered ports |
| Timestamps | `time.monotonic()` since mock start, not MCU timer |
| Isolate / Restore / Clear | Updates Python dataclass only — no GPIO, eFuse, or MUX |
| VID/PID on restore | Always sets Logitech keyboard IDs (not prior device) |

### What the UI implies but is not true yet

- “Live telemetry from the hub management plane” — live from the **mock**, not the PCB
- VBUS/current — plausible numbers, not INA219 readings
- Threat detection — only port 1 scripted `KEYSTROKE_BURST`; other codes exist in enum but are not triggered

---

## Stubs and placeholders

| Item | Location | Status |
| --- | --- | --- |
| Serial/MCU backend | `backend/src/serial_device.py` | `start()` raises `NotImplementedError` |
| Serial command path | `hub_service.py` | Raises if device is `SerialDevice` |
| `HUB_MODE=serial` | env var | Selects stub; does not work |
| `SERIAL_PORT` | env var | Default `/dev/ttyACM0`; unused |
| Frontend empty state | `App.tsx` `EMPTY_PORTS` | Zeros until first WebSocket snapshot |
| Production WebSocket URL | `useHubSocket.ts` | Hard-coded when not in Vite dev |

---

## Threat code coverage

| Code | Name | In mock demo? | In UI? |
| --- | --- | --- | --- |
| 0 | `NO_FAULT` | Yes | Yes |
| 1 | `UNAUTHORIZED_HID` | No | Yes (badge if set) |
| 2 | `KEYSTROKE_BURST` | Yes (port 1 @ ~15 s) | Yes |
| 3 | `COOLDOWN_BURST` | No | Yes (badge if set) |
| 4 | `DESCRIPTOR_OVERFLOW` | No | Yes (badge if set) |
| 5 | `CRC_TOKEN_FAULT` | No | Yes (badge if set) |
| 6 | `BIT_STUFF_ERROR` | No | Yes (badge if set) |
| 7 | `MANUAL_HOST_KILL` | Yes (Isolate button) | Yes |

---

## Verification (manual)

- [x] `make dev` starts backend then frontend
- [x] Dashboard at :5173 shows 4 ports and `MOCK` badge
- [x] Event log fills during port 1 demo and on manual isolate
- [x] Isolate / Restore / Clear change port display
- [x] `npm run build` succeeds
- [ ] `HUB_MODE=serial` with real MCU
- [ ] End-to-end with FPGA + hub hardware

---

## Related docs

| Doc | Contents |
| --- | --- |
| `GUI/README.md` | How to run |
| `GUI/AGENTS.md` | Make targets for agents |
| `Docs/firmwmare_slop.md` | MCU role and JSON telemetry sketch |
| `Docs/fabric_slop.md` | FPGA threat codes and register map |
| `Docs/init_specs.md` | Project requirements |

---

## Maintenance

Update **Next steps** and checkboxes when work lands. Also update when mock behavior or integration status changes.
