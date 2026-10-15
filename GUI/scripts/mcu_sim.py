#!/usr/bin/env python3
"""Dummy MCU UART peer for Tier-1 GUI serial bring-up.

NOT real hardware / NOT the carrier PCB. Speaks the same newline-delimited
JSON contract as Docs/firmwmare_slop.md §4 so Flutter SerialDevice can be
tested over a socat PTY pair (or dual FTDI) without firmware.

Modes:
  (default) Timed demo like MockDevice (port 1 → burst ~15s)
  --interactive / -i   REPL: you trigger plug/enum/burst/isolate yourself

Usage (pick ONE host path — both stay supported):

  WSL / Linux (PTY or /dev/ttyUSB*):
    make -C GUI sim-pty
    make -C GUI sim-mcu-i
    make -C GUI linux-serial SERIAL_PORT=/tmp/hub_host

  Windows native (COM ports — no usbipd):
    python scripts\\mcu_sim.py --port COM3 -i
    .\\scripts\\run_windows_serial.ps1 -Port COM4

In the REPL, type `help`. GUI Isolate/Restore/Clear still work over UART.

Requires: pyserial (`pip install pyserial` if missing).
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import threading
import time
from dataclasses import dataclass, field

try:
    import serial
except ImportError as exc:  # pragma: no cover
    sys.stderr.write(
        "mcu_sim requires pyserial. Install with: pip install pyserial\n"
    )
    raise SystemExit(1) from exc


HELP = """
Commands (port is 0–3):
  help                 this text
  status               print port table
  script on|off        timed demo on/off (off in -i by default)
  plug <p>             connect flash-like device (AUTHORIZED)
  unplug <p>           DISCONNECTED
  enum <p>             ENUMERATING
  auth <p>             AUTHORIZED keyboard
  burst <p>            QUARANTINED + KEYSTROKE_BURST (2)
  hid <p>              QUARANTINED + UNAUTHORIZED_HID (1)
  threat <p> <code>    set threat_code 0–7 (quarantine if code≠0)
  isolate <p>          MANUAL_BLOCKED + threat 7 (like GUI Isolate)
  restore <p>          AUTHORIZED keyboard again
  clear <p>            clear threat; stay isolated if blocked
  reset                initial demo state (port0 flash, others empty)
  quit / exit          stop sim
""".strip()


@dataclass
class Port:
    port: int
    state: str = "DISCONNECTED"
    threat_code: int = 0
    vbus_mv: int = 0
    current_ma: int = 0
    vid: str = "0x0000"
    pid: str = "0x0000"
    dev_class: str = "0x00"
    int_class: str = "0x00"
    manually_blocked: bool = False


@dataclass
class SimState:
    ports: list[Port] = field(default_factory=list)
    start: float = field(default_factory=time.monotonic)
    script_stage: int = 0
    script_enabled: bool = True
    lock: threading.Lock = field(default_factory=threading.Lock)
    stop: bool = False

    def elapsed_ms(self) -> int:
        return int((time.monotonic() - self.start) * 1000)


def make_initial_state(*, script_enabled: bool = True) -> SimState:
    return SimState(
        script_enabled=script_enabled,
        ports=[
            Port(
                port=0,
                state="AUTHORIZED",
                vbus_mv=5020,
                current_ma=42,
                vid="0x0781",
                pid="0x5583",
                dev_class="0x00",
                int_class="0x08",
            ),
            Port(port=1),
            Port(port=2),
            Port(port=3),
        ],
    )


def advance_script(state: SimState) -> None:
    if not state.script_enabled:
        return
    elapsed_s = time.monotonic() - state.start
    p1 = state.ports[1]
    if p1.manually_blocked or p1.state == "QUARANTINED":
        return
    if state.script_stage == 0 and elapsed_s >= 5:
        p1.state = "ENUMERATING"
        p1.vbus_mv = 5020
        p1.current_ma = 15
        state.script_stage = 1
    elif state.script_stage == 1 and elapsed_s >= 8:
        p1.state = "AUTHORIZED"
        p1.vid = "0x046D"
        p1.pid = "0xC31C"
        p1.dev_class = "0x00"
        p1.int_class = "0x03"
        p1.current_ma = 55
        state.script_stage = 2
    elif state.script_stage == 2 and elapsed_s >= 15:
        p1.state = "QUARANTINED"
        p1.threat_code = 2  # KEYSTROKE_BURST
        p1.vbus_mv = 0
        p1.current_ma = 0
        state.script_stage = 3


def jitter(state: SimState) -> None:
    for p in state.ports:
        if p.vbus_mv > 0 and p.state in ("AUTHORIZED", "ENUMERATING"):
            p.current_ma = max(0, p.current_ma + random.randint(-3, 3))


def telemetry_line(state: SimState) -> str:
    frame = {
        "timestamp_ms": state.elapsed_ms(),
        "ports": [
            {
                "port": p.port,
                "state": p.state,
                "threat_code": p.threat_code,
                "vbus_mv": p.vbus_mv,
                "current_ma": p.current_ma,
                "vid": p.vid,
                "pid": p.pid,
                "dev_class": p.dev_class,
                "int_class": p.int_class,
            }
            for p in state.ports
        ],
    }
    return json.dumps(frame, separators=(",", ":")) + "\n"


def apply_command(state: SimState, obj: dict) -> None:
    if obj.get("type") not in (None, "command"):
        return
    cmd = obj.get("cmd")
    port_id = obj.get("port")
    if not isinstance(port_id, int) or not (0 <= port_id <= 3):
        print(f"mcu_sim: ignore bad port {port_id!r}", flush=True)
        return
    if cmd == "isolate_port":
        _isolate(state.ports[port_id], port_id)
    elif cmd == "restore_port":
        _restore(state.ports[port_id], port_id)
    elif cmd == "clear_fault":
        _clear(state.ports[port_id], port_id)
    else:
        print(f"mcu_sim: unknown cmd {cmd!r}", flush=True)


def _isolate(p: Port, port_id: int) -> None:
    p.manually_blocked = True
    p.state = "MANUAL_BLOCKED"
    p.threat_code = 7
    p.vbus_mv = 0
    p.current_ma = 0
    print(f"mcu_sim: isolate port {port_id}", flush=True)


def _restore(p: Port, port_id: int) -> None:
    p.manually_blocked = False
    p.threat_code = 0
    p.state = "AUTHORIZED"
    p.vbus_mv = 5020
    p.current_ma = 30 + random.randint(0, 50)
    p.vid = "0x046D"
    p.pid = "0xC31C"
    p.dev_class = "0x00"
    p.int_class = "0x03"
    print(f"mcu_sim: restore port {port_id}", flush=True)


def _clear(p: Port, port_id: int) -> None:
    if p.threat_code == 0:
        print(f"mcu_sim: clear_fault port {port_id} (no fault)", flush=True)
        return
    prev = p.threat_code
    p.threat_code = 0
    if p.manually_blocked:
        p.state = "MANUAL_BLOCKED"
    else:
        p.state = "AUTHORIZED"
        p.vbus_mv = 5020
        p.current_ma = 20 + random.randint(0, 40)
    print(f"mcu_sim: clear_fault port {port_id} (was {prev})", flush=True)


def _parse_port(token: str) -> int | None:
    try:
        port_id = int(token)
    except ValueError:
        return None
    if 0 <= port_id <= 3:
        return port_id
    return None


def print_status(state: SimState) -> None:
    print(
        f"script={'on' if state.script_enabled else 'off'}  "
        f"elapsed_ms={state.elapsed_ms()}",
        flush=True,
    )
    print(
        f"{'p':>2}  {'state':<14}  {'threat':>6}  "
        f"{'vbus':>5}  {'mA':>4}  vid:pid",
        flush=True,
    )
    for p in state.ports:
        print(
            f"{p.port:>2}  {p.state:<14}  {p.threat_code:>6}  "
            f"{p.vbus_mv:>5}  {p.current_ma:>4}  {p.vid}:{p.pid}",
            flush=True,
        )


def run_repl_line(state: SimState, line: str) -> bool:
    """Apply one REPL line. Returns False if caller should exit."""
    line = line.strip()
    if not line:
        return True
    parts = line.split()
    cmd = parts[0].lower()

    if cmd in ("quit", "exit", "q"):
        state.stop = True
        return False
    if cmd == "help":
        print(HELP, flush=True)
        return True
    if cmd == "status":
        print_status(state)
        return True
    if cmd == "reset":
        fresh = make_initial_state(script_enabled=state.script_enabled)
        state.ports = fresh.ports
        state.start = time.monotonic()
        state.script_stage = 0
        print("mcu_sim: reset to initial state", flush=True)
        return True
    if cmd == "script":
        if len(parts) != 2 or parts[1].lower() not in ("on", "off"):
            print("usage: script on|off", flush=True)
            return True
        state.script_enabled = parts[1].lower() == "on"
        if state.script_enabled:
            state.start = time.monotonic()
            state.script_stage = 0
        print(
            f"mcu_sim: timed script {'on' if state.script_enabled else 'off'}",
            flush=True,
        )
        return True

    if cmd in (
        "plug",
        "unplug",
        "enum",
        "auth",
        "burst",
        "hid",
        "isolate",
        "restore",
        "clear",
    ):
        if len(parts) != 2:
            print(f"usage: {cmd} <port 0-3>", flush=True)
            return True
        port_id = _parse_port(parts[1])
        if port_id is None:
            print("port must be 0–3", flush=True)
            return True
        p = state.ports[port_id]
        if cmd == "plug":
            p.manually_blocked = False
            p.state = "AUTHORIZED"
            p.threat_code = 0
            p.vbus_mv = 5020
            p.current_ma = 40
            p.vid = "0x0781"
            p.pid = "0x5583"
            p.dev_class = "0x00"
            p.int_class = "0x08"
            print(f"mcu_sim: plug flash on port {port_id}", flush=True)
        elif cmd == "unplug":
            p.manually_blocked = False
            p.state = "DISCONNECTED"
            p.threat_code = 0
            p.vbus_mv = 0
            p.current_ma = 0
            p.vid = p.pid = "0x0000"
            p.dev_class = p.int_class = "0x00"
            print(f"mcu_sim: unplug port {port_id}", flush=True)
        elif cmd == "enum":
            p.manually_blocked = False
            p.state = "ENUMERATING"
            p.threat_code = 0
            p.vbus_mv = 5020
            p.current_ma = 15
            print(f"mcu_sim: enumerating port {port_id}", flush=True)
        elif cmd == "auth":
            _restore(p, port_id)
        elif cmd == "burst":
            p.manually_blocked = False
            p.state = "QUARANTINED"
            p.threat_code = 2
            p.vbus_mv = 0
            p.current_ma = 0
            p.vid = "0x046D"
            p.pid = "0xC31C"
            p.dev_class = "0x00"
            p.int_class = "0x03"
            print(f"mcu_sim: KEYSTROKE_BURST on port {port_id}", flush=True)
        elif cmd == "hid":
            p.manually_blocked = False
            p.state = "QUARANTINED"
            p.threat_code = 1
            p.vbus_mv = 0
            p.current_ma = 0
            p.vid = "0x046D"
            p.pid = "0xC31C"
            p.dev_class = "0x00"
            p.int_class = "0x03"
            print(f"mcu_sim: UNAUTHORIZED_HID on port {port_id}", flush=True)
        elif cmd == "isolate":
            _isolate(p, port_id)
        elif cmd == "restore":
            _restore(p, port_id)
        elif cmd == "clear":
            _clear(p, port_id)
        return True

    if cmd == "threat":
        if len(parts) != 3:
            print("usage: threat <port 0-3> <code 0-7>", flush=True)
            return True
        port_id = _parse_port(parts[1])
        try:
            code = int(parts[2])
        except ValueError:
            code = -1
        if port_id is None or not (0 <= code <= 7):
            print("port 0–3 and threat code 0–7 required", flush=True)
            return True
        p = state.ports[port_id]
        p.threat_code = code
        if code == 0:
            if not p.manually_blocked and p.state != "DISCONNECTED":
                p.state = "AUTHORIZED"
                p.vbus_mv = 5020
        else:
            if p.state != "MANUAL_BLOCKED":
                p.state = "QUARANTINED"
                p.vbus_mv = 0
                p.current_ma = 0
        print(f"mcu_sim: port {port_id} threat_code={code}", flush=True)
        return True

    print(f"unknown command {cmd!r} — type help", flush=True)
    return True


def repl_loop(state: SimState) -> None:
    print(HELP, flush=True)
    print("mcu_sim> ", end="", flush=True)
    while not state.stop:
        try:
            line = sys.stdin.readline()
        except KeyboardInterrupt:
            state.stop = True
            break
        if line == "":
            state.stop = True
            break
        with state.lock:
            cont = run_repl_line(state, line)
        if not cont:
            break
        if not state.stop:
            print("mcu_sim> ", end="", flush=True)


def reader_loop(ser: serial.Serial, state: SimState, buf: list[str]) -> None:
    while not state.stop:
        try:
            raw = ser.read(ser.in_waiting or 1)
        except serial.SerialException as exc:
            print(f"mcu_sim: read error: {exc}", flush=True)
            state.stop = True
            return
        if not raw:
            continue
        buf[0] += raw.decode("utf-8", errors="replace")
        while "\n" in buf[0]:
            line, buf[0] = buf[0].split("\n", 1)
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                print(f"mcu_sim: drop bad JSON: {line!r}", flush=True)
                continue
            if not isinstance(obj, dict):
                continue
            # Ignore echoed telemetry frames (PTY echo / loopback).
            if "timestamp_ms" in obj and "ports" in obj:
                continue
            with state.lock:
                apply_command(state, obj)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Dummy MCU UART peer (NOT real hardware)."
    )
    parser.add_argument(
        "--port",
        default="/tmp/hub_mcu",
        help="Serial/PTY path (default: /tmp/hub_mcu)",
    )
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument(
        "--hz",
        type=float,
        default=10.0,
        help="Telemetry emit rate (default: 10 Hz)",
    )
    parser.add_argument(
        "-i",
        "--interactive",
        action="store_true",
        help="REPL to trigger plug/burst/isolate yourself (disables timed script)",
    )
    args = parser.parse_args()

    print(
        "mcu_sim: DUMMY peer — not the carrier PCB / not STM32 firmware",
        flush=True,
    )
    print(f"mcu_sim: opening {args.port} @ {args.baud} 8-N-1", flush=True)

    try:
        ser = serial.Serial(
            port=args.port,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1,
        )
    except serial.SerialException as exc:
        sys.stderr.write(f"mcu_sim: failed to open {args.port}: {exc}\n")
        return 1

    state = make_initial_state(script_enabled=not args.interactive)
    buf = [""]
    threading.Thread(
        target=reader_loop, args=(ser, state, buf), daemon=True
    ).start()

    if args.interactive:
        threading.Thread(target=repl_loop, args=(state,), daemon=True).start()
        print(
            "mcu_sim: interactive mode — timed script OFF "
            "(use `script on` to enable)",
            flush=True,
        )

    interval = 1.0 / max(args.hz, 0.1)
    try:
        while not state.stop:
            with state.lock:
                advance_script(state)
                jitter(state)
                line = telemetry_line(state)
            ser.write(line.encode("utf-8"))
            time.sleep(interval)
    except KeyboardInterrupt:
        state.stop = True
        print("\nmcu_sim: stopped", flush=True)
    finally:
        ser.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
