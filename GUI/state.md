# GUI prototype state

**Last updated:** 2026-11-16  
**Status:** Software prototype — Flutter operator console with mock (default), Tier-1 PTY serial, and Tier-2 dual-CP2102 serial via WSL **or** Windows COM (`mcu_sim`). Serial against `mcu_sim` is **not** real PCB / MCU / FPGA hardware. Firmware SPI bring-up can surface live port0 HID pending/confirm when Cmod is programmed.

**Run:** `make dev` from `GUI/` → http://127.0.0.1:7357 (mode badge shows `MOCK`).

---

## Next steps (work in this order)

### Priority — hardware integration

- [x] Serial / USB-CDC device layer in Dart (newline-delimited JSON per `Docs/firmwmare_slop.md`) — Tier 1 via PTY + `mcu_sim`
- [x] **Tier 2:** Dual CP2102 cross-wire + same `mcu_sim` (headless on WSL 2026-10-15)
- [x] **Windows serial host path:** `scripts/run_windows_serial.ps1` + COM ports (keeps WSL `linux-serial` / usbipd path)
- [x] MCU firmware UART stub speaking the same JSON contract (`Firmware/` PlatformIO / Black Pill; mock local state only — see `Firmware/README.md`)
- [x] Stub GUI demo parity: port 1 → `PENDING_HID_CONFIRM`@5s + Confirm keyboard (`confirm_hid`); verified Windows serial on COM3 historically (`uart_smoke.py`)
- [x] HID confirm-before-allow UX: `PENDING_HID_CONFIRM` + `confirm_hid` modal popup dialog (clean 3-button port card without taking up card space) across protocol / mock / mcu_sim / firmware
- [x] MCU SPI bring-up bridge (`Firmware/` `fpga_bridge` + `FPGA_SPI_BRINGUP`) — port0 status/VID/PID/class over SPI; clear/manual via `P0_CONTROL` (bench verify with programmed Cmod)
- [x] Dropped power telemetry: INA219 / vbus_mv / current_ma removed from JSON and protocol models
- [ ] Forward host commands for all ports + full policy; drop mock dual-mode once default
- [ ] Verify end-to-end with hardware on the bench
- [ ] Package native Linux (`make build-linux`) and Windows (`make build-windows` on a Windows host / `scripts/build_windows.ps1`) for demo day

### Recommended — quality and demo

- [x] Serial reconnect — auto backoff + Retry; unplug/power-loss must not crash commands
- [x] Runtime COM / serial port picker in console header (no app restart)
- [ ] Expand unit tests beyond protocol + smoke widget test
- [x] Human-readable USB device identification and names in port cards (VID/PID lookup table in `usb_names.dart`)
- [ ] Expand mock / mcu_sim to surface threat codes 1, 3–6 (only 2 and 7 demoed today)
- [x] Persistent event log (Drift / SQLite) — last 200, wall-clock `YYYY-MM-DD HH:MM:SS`; clear all / delete one / filter by port
- [x] Database page sort (newest/oldest/port/threat) + show 50 at a time with Show more
- [ ] Install system deps for `make linux` (`clang ninja-build pkg-config libgtk-3-dev`)

### Deferred (out of current v1 scope)

- [ ] Policy editor (VID/class whitelist UI)
- [ ] Scenario replay UI / recorded demo files
- [ ] Configurable HID thresholds from GUI
- [ ] Authentication / multi-user access
- [ ] Global system status UI (FPGA reset, external 5 V, hub power mode)
- [ ] Settings page
- [ ] Link from `Website/` to operator console (if desired publicly)
- [ ] Revive legacy FastAPI `GUI/backend/` (not planned — Dart SoT)

---

## At a glance

| Layer | Status |
| --- | --- |
| Operator dashboard (Flutter) | **Built** — single-page console |
| In-process mock hub | **Built** — default (`HUB_MODE=mock`) |
| Serial UART backend | **Built** — `SerialDevice` + `flutter_libserialport` (desktop only) |
| Dummy MCU peer (`mcu_sim.py`) | **Built** — Tier-1 / Tier-2 test peer; **not** hardware |
| JSON host↔MCU protocol (Dart) | **Built** — `app/lib/protocol.dart` (+ unit tests) |
| Real MCU / carrier integration | **Stub** — `Firmware/` UART JSON over USART1→CP2102; no SPI/sensors yet |
| Native Linux desktop launch | **Scaffolded** — needs system GTK/clang toolchain |
| Windows `.exe` / serial host | **Scaffolded** — `run_windows_serial.ps1` (COM) + `build_windows.ps1` (build on Windows only) |
| Policy editor, scenario replay | **Not built** — out of v1 scope |
| Event log persistence | **Built** — Drift SQLite, last 200 events, reload on start |
| Automated tests | Protocol + persist + widget + serial Tier-1 + `make tier1-check` |

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
         UART / PTY  ←── mcu_sim.py (dummy) or future MCU
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

**Host → MCU:** `{"type":"command","cmd":"isolate_port"|"restore_port"|"clear_fault","port":0-3}\n`

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
