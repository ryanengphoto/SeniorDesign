#!/usr/bin/env python3
"""Create a bidirectional PTY pair with stable symlink paths (socat alternative).

Links default to /tmp/hub_mcu and /tmp/hub_host. Blocks until killed.
Configures slaves as raw/echo-off (like `socat ...,raw,echo=0`).
"""

from __future__ import annotations

import argparse
import os
import pty
import select
import signal
import sys
import termios
import tty


def _raw_noecho(fd: int) -> None:
    """Match socat PTY,link=...,raw,echo=0 so peers do not read their own writes."""
    tty.setraw(fd, when=termios.TCSANOW)
    attrs = termios.tcgetattr(fd)
    attrs[3] = attrs[3] & ~(termios.ECHO | termios.ECHOE | termios.ECHOK | termios.ECHONL)
    termios.tcsetattr(fd, termios.TCSANOW, attrs)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mcu-link", default="/tmp/hub_mcu")
    parser.add_argument("--host-link", default="/tmp/hub_host")
    args = parser.parse_args()

    mcu_master, mcu_slave = pty.openpty()
    host_master, host_slave = pty.openpty()
    _raw_noecho(mcu_slave)
    _raw_noecho(host_slave)

    mcu_name = os.ttyname(mcu_slave)
    host_name = os.ttyname(host_slave)

    for link in (args.mcu_link, args.host_link):
        try:
            if os.path.islink(link) or os.path.exists(link):
                os.unlink(link)
        except OSError:
            pass

    os.symlink(mcu_name, args.mcu_link)
    os.symlink(host_name, args.host_link)
    print(
        f"pty_pair: {args.mcu_link} → {mcu_name} ↔ {args.host_link} → {host_name}",
        flush=True,
    )

    stop = False

    def _stop(_signum, _frame):
        nonlocal stop
        stop = True

    signal.signal(signal.SIGINT, _stop)
    signal.signal(signal.SIGTERM, _stop)

    try:
        while not stop:
            readable, _, _ = select.select(
                [mcu_master, host_master], [], [], 0.5
            )
            if mcu_master in readable:
                data = os.read(mcu_master, 4096)
                if not data:
                    break
                os.write(host_master, data)
            if host_master in readable:
                data = os.read(host_master, 4096)
                if not data:
                    break
                os.write(mcu_master, data)
    finally:
        for fd in (mcu_master, mcu_slave, host_master, host_slave):
            try:
                os.close(fd)
            except OSError:
                pass
        for link in (args.mcu_link, args.host_link):
            try:
                if os.path.islink(link):
                    os.unlink(link)
            except OSError:
                pass
        print("pty_pair: stopped", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
