# USB Hub Operator Console

Flutter desktop/web operator console for the hardware-secure USB hub. Runs against an in-process mock device by default — no custom hardware required.

**Prototype on Linux/WSL** (`make dev` / `make linux`). **Windows `.exe`** is a packaging target built on a Windows host.

## Structure

| Path | Role |
| --- | --- |
| `app/` | Flutter operator console — `linux/`, `web/`, `windows/` platforms |
| `scripts/run_web.sh` | One-command web launcher used by `make dev` |
| `scripts/mcu_sim.py` | Dummy MCU UART peer for Tier-1 serial tests (**not** real hardware) |
| `scripts/pty_pair.py` | socat alternative — PTY pair with `/tmp/hub_mcu` ↔ `/tmp/hub_host` |
| `scripts/tier1_pty_check.py` | Headless PTY protocol check |
| `scripts/build_windows.ps1` | Windows release build helper |

## Prerequisites

- Flutter SDK (stable) — expected at `~/flutter` on Linux, or on PATH on Windows; override with `FLUTTER=...`
- For `make linux` / `make build-linux` / `make linux-serial`:

```bash
sudo apt update && sudo apt install -y \
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-14-dev
```

- For Tier-1 PTY serial: `socat` and `pyserial` (`sudo apt install socat` / `pip install pyserial`)
- For Windows `.exe`: Flutter for Windows + Visual Studio with the **Desktop development with C++** workload (cannot cross-compile from WSL)

Install Flutter on Linux once:

```bash
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

## Run locally (prototype)

From the repo root:

```bash
make -C GUI dev
```

Or from `GUI/`:

```bash
make dev          # web mock at http://127.0.0.1:7357  (easiest on WSL)
make linux        # build+run native Linux (debug, mock)
make run-linux    # run an already-built Linux binary (release if present, else debug)
```

Mode badge shows `MOCK`.

## Tier-1 serial (PTY + dummy MCU)

Exercises `SerialDevice` without Black Pill / FTDI / carrier PCB. **`SERIAL` + mcu_sim is still not real hardware.**

```bash
# Terminal A
make sim-pty

# Terminal B — timed demo, OR interactive (you trigger events):
make sim-mcu          # auto script
make sim-mcu-i        # REPL: burst 1 / isolate 2 / help

# Terminal C
make linux-serial SERIAL_PORT=/tmp/hub_host
```

In `sim-mcu-i`, useful commands: `burst 1`, `hid 2`, `plug 3`, `unplug 1`, `status`, then use GUI **Isolate / Restore / Clear**. Restart the GUI to confirm the event log reloads from Drift.

Headless protocol check (no GUI):

```bash
make tier1-check
```

Equivalent manual socat:

```bash
socat -d -d PTY,link=/tmp/hub_mcu,raw,echo=0 PTY,link=/tmp/hub_host,raw,echo=0
```

## Release / portable packages

| Target | Output | Notes |
| --- | --- | --- |
| `make build-web` | `app/build/web/` | Portable in any browser; works from WSL |
| `make build-linux` | `app/build/linux/x64/release/bundle/` | Native Linux; run `./hub_console` from that folder |
| `make build-windows` / `make windows` | `app/build/windows/x64/runner/Release/` | **Must build on Windows** |

On Windows (PowerShell):

```powershell
cd GUI
.\scripts\build_windows.ps1
```

Zip the entire `Release` folder for a portable demo — ship `hub_console.exe` **with** its DLLs and `data/` directory, not the `.exe` alone.

Other targets:

```bash
make analyze
make test
make stop       # free port 7357
```

Prototype status: see [`state.md`](state.md).

## Mock demo behavior

- Port 1 starts disconnected; port 0 shows an authorized flash drive.
- ~5 s: port 1 begins enumerating.
- ~8 s: port 1 authorizes as a keyboard.
- ~15 s: port 1 is quarantined for `KEYSTROKE_BURST` unless you isolate it first.

Use **Isolate**, **Restore**, and **Clear fault** on any port to test the control loop. `mcu_sim.py` mirrors the same script over UART.

## Protocol

Host↔MCU JSON contract: `Docs/firmwmare_slop.md` §4 / threat codes in `Docs/fabric_slop.md`. Dart models (SoT for this console): `app/lib/protocol.dart`.

| Direction | Shape |
| --- | --- |
| MCU → host | `{"timestamp_ms":…,"ports":[…]}` newline-delimited @ 115200 8-N-1 |
| Host → MCU | `{"type":"command","cmd":"isolate_port\|restore_port\|clear_fault","port":0-3}\n` |

Backends: `HubDevice` → `MockDevice` (default) or `SerialDevice` (`HUB_MODE=serial`, desktop only).
