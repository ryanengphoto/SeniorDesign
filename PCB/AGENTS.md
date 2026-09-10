# PCB — Agent notes

Carrier board for the hardware-secure 4-to-1 USB hub (KiCad/Altium under `PCB/` when schematics land). Distinct from `FPGA/` (RTL) and host `GUI/`.

## Required reading (before any board change)

1. [`Docs/Board_slop.md`](../Docs/Board_slop.md) — stackup, routing, BOM, bus map (**primary**)
2. [`Docs/d_c_txt.md`](../Docs/d_c_txt.md) — product architecture, enclosure/power/switch timing specs
3. [`Docs/init_specs.md`](../Docs/init_specs.md) — board requirements
4. Cross-check kill/SPI/I²C/UART roles with [`Docs/fabric_slop.md`](../Docs/fabric_slop.md) and [`Docs/firmwmare_slop.md`](../Docs/firmwmare_slop.md)
5. Block diagram: [`Docs/BlockDiagrams/Rendered/pcb_bd.jpg`](../Docs/BlockDiagrams/Rendered/pcb_bd.jpg)

## Architecture reminders

- Per-port path: Type-A → analog protection + FPGA-controlled switch + sense → **hub IC and FPGA tap in parallel**.
- FPGA kill must meet **≤ 120 ns** switch turn-off; do not lengthen USB critical path with an in-line FPGA (stretch only).
- MCU ↔ FPGA = SPI; MCU ↔ host GUI = UART (USB–UART bridge); sensors = I²C.

## Conventions

1. Put new schematics, layout, and BOMs under `PCB/`; do not invent a parallel top-level board tree.
2. Keep part choices and net names consistent with `Docs/Board_slop.md` BOM and digital bus section.
3. Document placeholders / unpopulated options in the board doc or a local README—not only in chat.
4. Do not commit secrets, vendor junk, or large generated output; follow `.gitignore`.
