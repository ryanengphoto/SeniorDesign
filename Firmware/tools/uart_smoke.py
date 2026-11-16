#!/usr/bin/env python3
"""Quick COM smoke test for the UART stub (telemetry + isolate/restore)."""

from __future__ import annotations

import argparse
import json
import sys
import time

import serial


def read_frame(ser: serial.Serial, timeout_s: float = 2.0) -> dict:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        raw = ser.readline().decode("utf-8", errors="replace").strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if "ports" in obj and "timestamp_ms" in obj:
            return obj
    raise TimeoutError("no telemetry frame")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="COM3")
    ap.add_argument("--baud", type=int, default=115200)
    args = ap.parse_args()

    ser = serial.Serial(args.port, args.baud, timeout=0.3)
    time.sleep(0.2)
    ser.reset_input_buffer()

    frame = read_frame(ser)
    print("telemetry_ok", frame["ports"][0]["state"], "ts", frame["timestamp_ms"])

    ser.write(b'{"type":"command","cmd":"isolate_port","port":0}\n')
    ser.flush()
    isolated = None
    deadline = time.time() + 2.0
    while time.time() < deadline:
        frame = read_frame(ser, timeout_s=0.5)
        isolated = frame
        if frame["ports"][0]["state"] == "MANUAL_BLOCKED" and frame["ports"][0]["threat_code"] == 7:
            break
    print("isolate", isolated["ports"][0] if isolated else None)

    ser.write(b'{"type":"command","cmd":"restore_port","port":0}\n')
    ser.flush()
    restored = None
    deadline = time.time() + 2.0
    while time.time() < deadline:
        frame = read_frame(ser, timeout_s=0.5)
        restored = frame
        if frame["ports"][0]["state"] == "AUTHORIZED":
            break
    print("restore", restored["ports"][0] if restored else None)
    ser.close()

    if not isolated or isolated["ports"][0]["state"] != "MANUAL_BLOCKED":
        return 2
    if not restored or restored["ports"][0]["state"] != "AUTHORIZED":
        return 3
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
