# FPGA references (not in the live fabric)

RTL kept for history / TinyFPGA provenance. **Not** part of `main_wrapper` synthesis or the production sniff path.

| File | Why it is here |
| --- | --- |
| `usb_fs_rx.v` | Original TinyFPGA FS-only soft RX. Replaced in-tree by `usb_sie_rx` (FS/LS). |
| `strobe.v` / `dflip` | TinyFPGA CDC helpers formerly used by `usb_fs_rx`. Active `usb_sie_rx` is same-clock and does not instantiate them. |
| `usb_reset_det.v` | TinyFPGA USB bus-reset detector; never wired under `main_wrapper`. |

Active RX/TX:

- **RX (hardware):** `sources_1/new/usb_sie_rx.sv` via `usb_packet_frontend`
- **TX:** `sources_1/new/usb_fs_tx.v` — sim stimulus + optional `usb_demo_selfstim` under `main_wrapper`

Do not add these files back to `senior_design.xpr` `sources_1` unless deliberately resurrecting them.
