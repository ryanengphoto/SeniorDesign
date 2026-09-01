# Agents

Instructions for coding agents working in this repository.

## Purpose

Senior Design project: a **hardware-secure 4-to-1 USB hub**. Custom PCB, FPGA inspection/isolation, MCU management plane, and host software work together to provide hub functionality with per-port power control, threat detection, and operator visibility. Requirements live in `Docs/init_specs.md` and subsystem notes in `Docs/`.

## Components

| Path | Role | Agent notes |
| --- | --- | --- |
| `Docs/` | Specs, diagrams, reports | Source of truth for requirements; read before implementing |
| `FPGA/` | HDL, constraints, Vivado project | Simulation/testbenches preferred before claiming RTL works |
| `PCB/` | Schematics, layout, BOMs | |
| `GUI/` | Operator console (FastAPI + React) | `GUI/AGENTS.md`, prototype status in `GUI/state.md` |
| `Website/` | Public project site (Astro) | `Website/AGENTS.md`, prototype status in `Website/state.md` |
| `Agents/` | Agent-related project files | |

Repo layout: `MAP.md`. Put new files in the mapped folders. Do not add top-level directories unless asked.

## How agents should work

**Finish, don’t spill.** Implement changes that can be **evaluated**: run builds, start servers, execute tests or sims, and fix failures before stopping. Do not leave broken or unverified code for the user to discover.

**Deterministic and repeatable.** Prefer Make targets and documented scripts over ad-hoc shell one-liners. Use paths **relative to the repo** (`GUI/backend`, not `/home/...`). When you add a recurring workflow, add a Make target.

| Path | Common commands |
| --- | --- |
| `GUI/` | `make -C GUI dev`, `make -C GUI backend`, `make -C GUI frontend`, `make -C GUI stop` |

**Testable.** Add or run checks appropriate to the change: `npm run build`, pytest, Vivado sim, lint. If tests do not exist yet, verify manually with the Make/dev workflow and say what you ran.

**Minimal scope.** Match existing style and conventions. Smallest correct diff. No drive-by refactors or unrelated files.

## Implementation rules

**No unnecessary hardcoding.** Magic numbers, VID/PIDs, thresholds, and port counts belong in config, constants, protocol enums, or spec-backed modules—not scattered in UI or handlers. Hardcode only when the value is fixed by the protocol or hardware (e.g. threat code `0x7` in the FPGA spec).

**Document dummy and placeholder behavior.** Mock data, stubs, TODO integrations, and scripted demos must be called out in code comments and in the relevant `state.md` or README (e.g. `GUI/state.md` for the console). Never present simulated telemetry or fake hardware actions as real.

**Single source of truth.** Protocol shapes, threat codes, and register maps should align across `Docs/`, `GUI/backend/src/protocol.py`, and firmware/FPGA when those exist. Update docs when the contract changes.

**Secrets and generated output.** Do not commit secrets, credentials, tool junk, or build artifacts. Follow `.gitignore` and per-folder `.gitignore` (e.g. `GUI/.gitignore`).

## Before you change something

1. Read `MAP.md` and the target folder’s README / `AGENTS.md` / `state.md`.
2. Read the relevant spec in `Docs/`.
3. Prefer extending existing modules over parallel implementations.

## After you change something

1. Run the applicable build or dev command and report the result.
2. Update local `state.md` for changed section of the project if it exists, README, or specs if behavior, mocks, or integration status changed.
3. Do not commit unless the user asks.

## Subsystem docs

- `GUI/AGENTS.md` — operator console commands and conventions
- `Website/AGENTS.md` — Astro dev server
- `Website/state.md` — what is built vs placeholder vs not built on the public site
- `GUI/state.md` — what is built vs mock vs not built in the GUI prototype
