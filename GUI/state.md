# GUI prototype state

**Last updated:** 2026-11-20  
**Status:** Flutter operator console — mock for offline demo (`make dev`), serial for hardware (`make windows-serial` / COM). Bench stack (GUI ↔ Black Pill UART ↔ FPGA SPI bring-up) has been verified end-to-end. `mcu_sim` remains a **dummy** UART peer when used.

**Event log:** Unplug after a sticky FPGA threat (e.g. keystroke burst) logs `Device disconnected` only — it does **not** re-emit the threat summary (fabric keeps the threat nibble until clear_fault).

**Run:** `make dev` from `GUI/` → http://127.0.0.1:7357 (mode badge shows `MOCK`). Hardware: `make windows-serial` (or `.\scripts\run_windows_serial.ps1`).

---

## Next steps (triaged 2026-11-18)

### Priority

- [x] Serial / USB-CDC device layer (Tier 1 PTY + `mcu_sim`) and Windows COM host path (`scripts/run_windows_serial.ps1`; WSL `linux-serial` kept)
- [x] MCU UART JSON + SPI bring-up; HID confirm UX (`confirm_hid`); commands for ports 0–3
- [x] End-to-end verified on the bench (GUI ↔ MCU ↔ FPGA)
- [x] **Expand unit tests** — HubService confirm/isolate stale-frame races, dual logging, system-event purge, burst copy; banner Connected/Reconnecting/mock; `make test` works on Windows
- [x] **JSON / UART resilience** — lenient telemetry parse + `TelemetryLineBuffer`; garbage lines/bytes skipped; HubService frame path never tears down UI; CSV import skips corrupt rows; fuzz coverage in `protocol_resilience_test.dart`
- [ ] **Package** native Windows (`make build-windows` / `scripts/build_windows.ps1`) and optionally Linux for demo day — last ship step

### Outstanding (low urgency)

- [ ] Expand mock / `mcu_sim` default scripts for threat codes 1, 3–6 (REPL can already trigger some)

### Stretch (optional)

- [ ] **Configurable HID thresholds from GUI** — leave alone for now; FPGA owns keystroke/cooldown bounds. Only revisit if fabric exposes runtime registers the MCU can write.

### Explicitly not doing

- [x] ~~VID/class allowlist / policy editor~~ — **rejected**; descriptors are spoofable, so auto-trust-by-ID is a risk. Confirm-before-allow (and fabric behavior) stays the model
- [x] ~~Authentication / multi-user~~ — not useful for this console
- [x] ~~Install `make linux` system deps~~ — deferred / not a concern
- [x] ~~Scenario replay UI~~ — unnecessary for this project
- [x] ~~Global system status UI~~ (FPGA reset / rail / hub power) — unnecessary for v1 console
- [x] ~~Settings page~~ — no clear v1 contents; header COM/baud covers runtime needs
- [x] ~~Link Website → operator console~~ — different audiences; console is local, not a public app
- [x] ~~Revive FastAPI `GUI/backend/`~~ — **never**; Flutter/`protocol.dart` is SoT

### Notes on checked items

- **Host commands for all ports:** GUI `HostCommand` + firmware accept `port` 0–3 for isolate/restore/clear/confirm. Mock remains available for offline UI work; serial is the hardware path — not a blocker.

---

## At a glance

| Layer | Status |
| --- | --- |
| Operator dashboard (Flutter) | **Built** — single-page console |
| In-process mock hub | **Built** — default (`HUB_MODE=mock`) |
| Serial UART backend | **Built** — `SerialDevice` + `flutter_libserialport` (desktop only) |
| Dummy MCU peer (`mcu_sim.py`) | **Built** — Tier-1 / Tier-2 test peer; **not** hardware |
| JSON host↔MCU protocol (Dart) | **Built** — `app/lib/protocol.dart` (+ unit tests) |
| Real MCU / carrier integration | **Bench-verified** — UART + SPI bring-up |
| Native Linux desktop launch | **Scaffolded** — optional; not prioritized |
| Windows `.exe` / serial host | **Run path built** — `windows-serial`; **release package** still outstanding |
| Policy / allowlist / auth / FastAPI | **Won't do** — see Next steps |
| Event log persistence | **Built** — Drift SQLite, last 200 **security** events; UART/COM/baud host-link status is not logged (header banner only) |
| Automated tests | Protocol + resilience fuzz + persist + HubService races + banner widgets + serial Tier-1 + `make tier1-check` |

---

## What this is (vs `Website/`)

| | `Website/` | `GUI/` |
| --- | --- | --- |
| Purpose | Public project page for committee / portfolio | Operator console for the device |
| Audience | Visitors | Team / demo / future operators |
| Data | Static copy | Live telemetry + commands |
| Stack | Astro | Flutter (`app/`) |

---

## Architecture (current)

```
Flutter UI (web via make dev, or linux)
    │
    ▼
HubService  ←── HubDevice interface
    │
    ├── MockDevice     (default — HUB_MODE=mock)
    └── SerialDevice   (HUB_MODE=serial, desktop only)
              │
              ▼
         UART / PTY  ←── Black Pill (bench) or mcu_sim.py (dummy)
```

---

## Built and real

These parts are functional prototype code, not placeholders.

### Tooling

- `Makefile` — `make dev`, `make linux`, `make linux-serial`, `make sim-pty`, `make sim-mcu`, `make tier1-check`, `make analyze`, `make test`, …
- `scripts/run_web.sh`, `scripts/mcu_sim.py`, `scripts/tier1_pty_check.py`
- `GUI/.gitignore`, `GUI/README.md`, `GUI/AGENTS.md`

### Flutter app (`app/`)

| Component | File | Notes |
| --- | --- | --- |
| Entry | `lib/main.dart` | `HubService.fromEnvironment()` |
| Device interface | `lib/hub_device.dart` | Shared mock/serial API |
| Factory | `lib/device_factory*.dart` | dart-defines + web stub |
| Protocol models | `lib/protocol.dart` | fromJson/toJson, HostCommand |
| Mock hub | `lib/mock_device.dart` | Scripted demo + jitter |
| Serial hub | `lib/serial_device.dart` | flutter_libserialport @ 115200 8-N-1; auto-reconnect + Retry; telemetry watchdog |
| Hub orchestration | `lib/hub_service.dart` | Poll (mock) or frame stream (serial); loads/saves event log |
| Event log DB | `lib/db/event_log_*.dart` | Drift SQLite — last 200, wall-clock timestamps; clear all / delete one |
| Console shell | `lib/console_shell.dart` | Logo + “Peripheral Interface Security System”; Dashboard / Database nav |
| Dashboard | `lib/dashboard_page.dart`, `lib/widgets/*` | Vertical port rows + sidebar event log |
| Keyboard confirm dialog | `lib/widgets/keyboard_confirm_dialog.dart` | Popup on keyboard detection / pending confirm; replaces per-card button |
| Database viewer | `lib/database_page.dart` | Full event table; sort + port filter; 50-row pages / Show more; Menu → Load / Export / Clear (load is view-only CSV) |

### Protocol (host ↔ device contract)

**MCU → host:** newline-delimited telemetry JSON (`timestamp_ms`, `ports[]`)

**Host → MCU:** `{"type":"command","cmd":"isolate_port"|"restore_port"|"clear_fault"|"confirm_hid","port":0-3}\n`  
(`confirm_hid` → FPGA `Pn_CONTROL[5]`; releases HID-confirm hold. `clear_fault` does not approve.)

**Enums:** port states (`DISCONNECTED`, `AUTHORIZED`, `QUARANTINED`, `MANUAL_BLOCKED` — no `ENUMERATING` on UART); threat codes 0–7 per `Docs/fabric_slop.md` §6

SoT: `GUI/app/lib/protocol.dart` (see also `Docs/firmwmare_slop.md` §4).

---

## Dummy / simulated (not real hardware)

| Source | What is fake |
| --- | --- |
| `MockDevice` | Entire hub — in-process Dart only |
| `mcu_sim.py` | Entire MCU — scripted UART peer; **SERIAL badge does not mean PCB** |
| Port 0 at startup | Hard-coded SanDisk-like flash (`0x0781:0x5583`) |
| Port 1 demo script | Timed HID → `PENDING_HID_CONFIRM`; Confirm keyboard → authorized |
| Current readings | Random ±3 mA jitter on powered ports |
| Isolate / Restore / Clear / Confirm HID (mock/sim) | Local state only — no GPIO / eFuse / MUX / FPGA unless live SPI peer. Isolate only on AUTHORIZED. Clear ≠ HID approve. |

### What the UI implies but is not true yet (mock or mcu_sim)

- Mode badge `SERIAL` / port data — live from **mock** or **mcu_sim**, not the PCB (unless Black Pill UART stub is the peer)
- Threat detection — mock/mcu_sim demo pending HID confirm; other threat codes exist in enum / REPL (`burst`, `hid`) but are not the default script

---

## Tier-1 verification

```bash
make -C GUI analyze          # clean
make -C GUI test             # protocol + widget
make -C GUI tier1-check      # socat + mcu_sim + host cmds
# Manual GUI:
make -C GUI sim-pty
make -C GUI sim-mcu          # other terminal
make -C GUI linux-serial SERIAL_PORT=/tmp/hub_host
```

- [x] `make analyze` clean
- [x] Protocol unit tests + `serial_tier1_test` (SerialDevice ↔ mcu_sim over PTY)
- [x] `make tier1-check` (Python host ↔ mcu_sim over PTY)
- [ ] Manual GUI: `make linux-serial SERIAL_PORT=/tmp/hub_host` with `sim-pty` + `sim-mcu`
- [x] Default mock unchanged (`make dev` / `make linux`)

**Honesty:** Mode badge `SERIAL` against `mcu_sim` / PTY is a **dummy UART peer**, not the carrier PCB, Black Pill, or FPGA.

---

## Tier-2 checklist (FTDI / CP2102)

Same `mcu_sim`, real USB–serial silicon (not PCB). **Prefer Windows native COM** so plugs stay on Windows; WSL/`usbipd` remains optional.

### Host switch

| Path | GUI | Peer |
| --- | --- | --- |
| Windows (default for dongles) | `.\scripts\run_windows_serial.ps1 -Port COMx` | `python scripts\mcu_sim.py --port COMy -i` |
| WSL / Linux | `make linux-serial SERIAL_PORT=/dev/ttyUSB1` | `mcu_sim.py --port /dev/ttyUSB0 -i` (+ `usbipd attach`) |

### Verified / remaining

1. [x] Two CP2102 modules; USB-powered; TX↔RX + GND↔GND (no VCC cross)
2. [x] WSL headless: `tier1_pty_check.py` over `/dev/ttyUSB0`↔`/dev/ttyUSB1` (2026-10-15)
3. [x] Windows scripts: `list_com_ports.ps1`, `run_windows_serial.ps1`, `run_windows_mock.ps1`
4. [ ] Manual GUI on Windows COM (operator) — preferred everyday path
5. [ ] Optional GUI on WSL after `usbipd attach`

Single dongle: open-port smoke / TX–RX loopback only — prefer Tier-1 PTY or dual-dongle for protocol.

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

Update **Next steps** and checkboxes when work lands. Also update when mock / mcu_sim behavior or integration status changes. Never imply real hardware when the peer is `mcu_sim`.
