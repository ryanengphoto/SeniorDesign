# Docs — Agent notes

Requirements, architecture narratives, and subsystem specs for the hardware-secure 4-to-1 USB hub. Prefer updating these when behavior or contracts change; do not fork conflicting “shadow” specs elsewhere.

## Source-of-truth map

| Area | Primary doc | Supporting |
| --- | --- | --- |
| Product / goals / engineering tables | [`d_c_txt.md`](d_c_txt.md) | [`init_specs.md`](init_specs.md) |
| Carrier PCB | [`Board_slop.md`](Board_slop.md) | `d_c_txt.md`, [`BlockDiagrams/Rendered/pcb_bd.jpg`](BlockDiagrams/Rendered/pcb_bd.jpg) |
| FPGA fabric | [`fabric_slop.md`](fabric_slop.md) | `d_c_txt.md`, [`BlockDiagrams/Rendered/fabric_bd.jpg`](BlockDiagrams/Rendered/fabric_bd.jpg) |
| MCU firmware | [`firmwmare_slop.md`](firmwmare_slop.md) | `fabric_slop.md`, flowchart under `BlockDiagrams/Rendered/` |

Agents directed at **board**, **fabric**, or **firmware** must read the matching primary doc **and** [`d_c_txt.md`](d_c_txt.md) before implementing. Folder-level pointers: [`PCB/AGENTS.md`](../PCB/AGENTS.md), [`FPGA/AGENTS.md`](../FPGA/AGENTS.md), root [`AGENTS.md`](../AGENTS.md) (firmware section until a `Firmware/` tree exists).

## Conventions

1. Keep threat codes, SPI maps, and JSON telemetry shapes consistent across Docs, FPGA, firmware, and `GUI/backend/src/protocol.py`.
2. When `d_c_txt.md` or block diagrams change architecture, update the three `*_slop.md` specs in the same change set when possible.
3. Filenames `*_slop.md` are historical; treat them as the living subsystem documentation (do not invent parallel `documentation.md` copies).
