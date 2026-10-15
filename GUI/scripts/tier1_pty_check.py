#!/usr/bin/env python3
"""Tier-1 headless check: socat PTY + mcu_sim + host command round-trip.

Does not launch Flutter. Proves the dummy MCU peer speaks the UART JSON
contract and applies isolate/restore/clear. SERIAL mode against mcu_sim is
still not real PCB hardware.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

try:
    import serial
except ImportError as exc:  # pragma: no cover
    sys.stderr.write("tier1_pty_check requires pyserial\n")
    raise SystemExit(1) from exc

ROOT = Path(__file__).resolve().parent


def read_frame(ser: serial.Serial, timeout_s: float = 3.0) -> dict:
    deadline = time.monotonic() + timeout_s
    buf = ""
    while time.monotonic() < deadline:
        chunk = ser.read(ser.in_waiting or 1)
        if chunk:
            buf += chunk.decode("utf-8", errors="replace")
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(obj, dict) and "ports" in obj:
                    return obj
        else:
            time.sleep(0.02)
    raise TimeoutError("no telemetry frame received")


def port_state(frame: dict, port_id: int) -> dict:
    for p in frame["ports"]:
        if p["port"] == port_id:
            return p
    raise KeyError(port_id)


def send_cmd(ser: serial.Serial, cmd: str, port: int) -> None:
    line = json.dumps({"type": "command", "cmd": cmd, "port": port}) + "\n"
    ser.write(line.encode("utf-8"))
    ser.flush()


def wait_port(
    ser: serial.Serial,
    port_id: int,
    *,
    state: str | None = None,
    threat_code: int | None = None,
    timeout_s: float = 5.0,
) -> dict:
    deadline = time.monotonic() + timeout_s
    last = None
    while time.monotonic() < deadline:
        frame = read_frame(ser, timeout_s=1.0)
        last = port_state(frame, port_id)
        ok = True
        if state is not None and last["state"] != state:
            ok = False
        if threat_code is not None and last["threat_code"] != threat_code:
            ok = False
        if ok:
            return last
    raise AssertionError(
        f"port {port_id} did not reach state={state} threat={threat_code}; last={last}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host-port", default="/tmp/hub_host")
    parser.add_argument("--mcu-port", default="/tmp/hub_mcu")
    parser.add_argument("--baud", type=int, default=115200)
    args = parser.parse_args()

    pid_file = Path("/tmp/hub_mcu_sim.pid")
    sim = subprocess.Popen(
        [
            sys.executable,
            str(ROOT / "mcu_sim.py"),
            "--port",
            args.mcu_port,
            "--baud",
            str(args.baud),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    pid_file.write_text(str(sim.pid), encoding="utf-8")
    time.sleep(0.5)
    if sim.poll() is not None:
        out = sim.stdout.read() if sim.stdout else ""
        sys.stderr.write(f"mcu_sim exited early:\n{out}\n")
        pid_file.unlink(missing_ok=True)
        return 1

    try:
        with serial.Serial(
            args.host_port,
            args.baud,
            timeout=0.1,
        ) as ser:
            frame = read_frame(ser)
            p0 = port_state(frame, 0)
            assert p0["state"] == "AUTHORIZED", p0
            assert p0["vid"] == "0x0781", p0
            print("OK telemetry: port 0 AUTHORIZED")

            send_cmd(ser, "isolate_port", 1)
            wait_port(ser, 1, state="MANUAL_BLOCKED", threat_code=7)
            print("OK isolate_port → MANUAL_BLOCKED / threat 7")

            send_cmd(ser, "clear_fault", 1)
            wait_port(ser, 1, state="MANUAL_BLOCKED", threat_code=0)
            print("OK clear_fault → threat 0, still isolated")

            send_cmd(ser, "restore_port", 1)
            wait_port(ser, 1, state="AUTHORIZED", threat_code=0)
            print("OK restore_port → AUTHORIZED")

        print("tier1_pty_check PASSED (dummy mcu_sim peer — not PCB)")
        return 0
    except Exception as exc:
        sys.stderr.write(f"tier1_pty_check FAILED: {exc}\n")
        return 1
    finally:
        sim.terminate()
        try:
            sim.wait(timeout=2)
        except subprocess.TimeoutExpired:
            sim.kill()
        pid_file.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
