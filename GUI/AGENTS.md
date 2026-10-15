# GUI — Agent notes

Operator console: Flutter app in `app/`. Distinct from the marketing site in `Website/`.

## Protocol / hardware context

Before changing telemetry shapes, threat codes, or “live hardware” claims, read:

- [`Docs/firmwmare_slop.md`](../Docs/firmwmare_slop.md) — UART JSON telemetry / commands (MCU → host)
- [`Docs/fabric_slop.md`](../Docs/fabric_slop.md) — threat codes and FPGA register semantics
- [`Docs/d_c_txt.md`](../Docs/d_c_txt.md) — system architecture (FPGA sniff + MCU management plane)
- Prototype honesty: [`GUI/state.md`](state.md)

Keep `GUI/app/lib/protocol.dart` aligned with those docs (host↔MCU SoT for the Flutter console).

## Development

Run Make targets from `GUI/` (or `make -C GUI <target>` from the repo root). **Do not** substitute absolute home-directory paths (except Flutter’s default `~/flutter` install).

| Target | Action |
| --- | --- |
| `make dev` | Install deps, start Flutter web-server mock console (Linux/WSL prototype) |
| `make web` | Same as `make dev` |
| `make linux` | Build+run native Linux desktop (debug; mock; requires clang/ninja/pkg-config/GTK) |
| `make linux-serial` | Linux desktop with `HUB_MODE=serial` (set `SERIAL_PORT=...`) |
| `make sim-pty` | socat PTY pair `/tmp/hub_mcu` ↔ `/tmp/hub_host` |
| `make sim-mcu` | Run `scripts/mcu_sim.py` timed demo (dummy MCU — **not** PCB) |
| `make sim-mcu-i` | Interactive `mcu_sim` REPL (`burst 1`, `isolate 2`, …) |
| `make tier1-check` | Headless PTY + mcu_sim protocol round-trip |
| `make stop-sim` | Stop background socat / mcu_sim |
| `make run-linux` | Run an already-built Linux binary (release preferred, else debug) |
| `make build-web` / `make build` | Release web → `app/build/web/` |
| `make build-linux` | Release Linux bundle |
| `make build-windows` / `make windows` | Release Windows `.exe` — **Windows host only** (see `scripts/build_windows.ps1`) |
| `make install` | `flutter pub get` in `app/` |
| `make analyze` | `flutter analyze` |
| `make test` | `flutter test` (protocol + widget + serial Tier-1) |
| `make test-serial` | SerialDevice ↔ mcu_sim PTY test only |
| `make stop` | Free port 7357 |

Open the dashboard at http://127.0.0.1:7357 after `make dev`. Flutter SDK is expected at `~/flutter` (override with `FLUTTER=...`).

### Hub backends

| Mode | How | Notes |
| --- | --- | --- |
| `mock` (default) | in-process `MockDevice` | Web (`make dev`) and `make linux` |
| `serial` | `SerialDevice` + `flutter_libserialport` | Desktop only; `--dart-define=HUB_MODE=serial --dart-define=SERIAL_PORT=...` |

`scripts/mcu_sim.py` is a **dummy** UART peer for Tier-1 bring-up. Mode badge `SERIAL` against mcu_sim does **not** mean real carrier/FPGA hardware.

Do not claim a Windows build succeeded from WSL; `make windows` exits with instructions on Linux.
