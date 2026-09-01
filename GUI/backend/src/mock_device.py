from __future__ import annotations

import random
import time
from dataclasses import dataclass, field

from .protocol import (
    PortState,
    PortStatus,
    TelemetryFrame,
    ThreatCode,
    THREAT_NAMES,
)


@dataclass
class _Port:
    port: int
    state: PortState = PortState.DISCONNECTED
    threat_code: int = ThreatCode.NO_FAULT
    vbus_mv: int = 0
    current_ma: int = 0
    vid: str = "0x0000"
    pid: str = "0x0000"
    dev_class: str = "0x00"
    int_class: str = "0x00"
    manually_blocked: bool = False


@dataclass
class MockDevice:
    _ports: list[_Port] = field(default_factory=list)
    _start_time: float = field(default_factory=time.monotonic)
    _script_stage: int = 0

    def __post_init__(self) -> None:
        if not self._ports:
            self._ports = [
                _Port(
                    port=0,
                    state=PortState.AUTHORIZED,
                    vbus_mv=5020,
                    current_ma=42,
                    vid="0x0781",
                    pid="0x5583",
                    dev_class="0x00",
                    int_class="0x08",
                ),
                _Port(port=1),
                _Port(port=2),
                _Port(port=3),
            ]

    @property
    def mode(self) -> str:
        return "mock"

    def start(self) -> None:
        self._start_time = time.monotonic()
        self._script_stage = 0

    async def stop(self) -> None:
        pass

    def _elapsed_ms(self) -> int:
        return int((time.monotonic() - self._start_time) * 1000)

    def get_telemetry(self) -> TelemetryFrame:
        self._advance_script()
        self._jitter_readings()
        return TelemetryFrame(
            timestamp_ms=self._elapsed_ms(),
            ports=[self._to_status(port) for port in self._ports],
        )

    def _to_status(self, port: _Port) -> PortStatus:
        return PortStatus(
            port=port.port,
            state=port.state,
            threat_code=port.threat_code,
            vbus_mv=port.vbus_mv,
            current_ma=port.current_ma,
            vid=port.vid,
            pid=port.pid,
            dev_class=port.dev_class,
            int_class=port.int_class,
        )

    def get_port(self, port_id: int) -> _Port:
        return self._ports[port_id]

    def isolate_port(self, port_id: int) -> tuple[PortState, int, str]:
        port = self._ports[port_id]
        port.manually_blocked = True
        port.state = PortState.MANUAL_BLOCKED
        port.threat_code = ThreatCode.MANUAL_HOST_KILL
        port.vbus_mv = 0
        port.current_ma = 0
        return (
            port.state,
            port.threat_code,
            f"Port {port_id} manually isolated by operator",
        )

    def restore_port(self, port_id: int) -> tuple[PortState, int, str]:
        port = self._ports[port_id]
        port.manually_blocked = False
        port.threat_code = ThreatCode.NO_FAULT
        port.state = PortState.AUTHORIZED
        port.vbus_mv = 5020
        port.current_ma = random.randint(30, 80)
        port.vid = "0x046D"
        port.pid = "0xC31C"
        port.dev_class = "0x00"
        port.int_class = "0x03"
        return (
            port.state,
            port.threat_code,
            f"Port {port_id} restored and authorized",
        )

    def clear_fault(self, port_id: int) -> tuple[PortState, int, str] | None:
        port = self._ports[port_id]
        if port.threat_code == ThreatCode.NO_FAULT:
            return None

        previous = THREAT_NAMES.get(port.threat_code, "UNKNOWN")
        port.threat_code = ThreatCode.NO_FAULT

        if port.manually_blocked:
            port.state = PortState.MANUAL_BLOCKED
            message = f"Fault cleared on port {port_id} ({previous}); port remains isolated"
        else:
            port.state = PortState.AUTHORIZED
            port.vbus_mv = 5020 if port.state != PortState.DISCONNECTED else 0
            port.current_ma = random.randint(20, 60) if port.vbus_mv else 0
            message = f"Fault cleared on port {port_id} ({previous})"

        return port.state, port.threat_code, message

    def _jitter_readings(self) -> None:
        for port in self._ports:
            if port.vbus_mv > 0 and port.state in (
                PortState.AUTHORIZED,
                PortState.ENUMERATING,
            ):
                port.current_ma = max(
                    0,
                    port.current_ma + random.randint(-3, 3),
                )

    def _advance_script(self) -> None:
        elapsed_s = time.monotonic() - self._start_time
        port1 = self._ports[1]

        if port1.manually_blocked or port1.state == PortState.QUARANTINED:
            return

        if self._script_stage == 0 and elapsed_s >= 5:
            port1.state = PortState.ENUMERATING
            port1.vbus_mv = 5020
            port1.current_ma = 15
            self._script_stage = 1
            return

        if self._script_stage == 1 and elapsed_s >= 8:
            port1.state = PortState.AUTHORIZED
            port1.vid = "0x046D"
            port1.pid = "0xC31C"
            port1.dev_class = "0x00"
            port1.int_class = "0x03"
            port1.current_ma = 55
            self._script_stage = 2
            return

        if self._script_stage == 2 and elapsed_s >= 15:
            port1.state = PortState.QUARANTINED
            port1.threat_code = ThreatCode.KEYSTROKE_BURST
            port1.vbus_mv = 0
            port1.current_ma = 0
            self._script_stage = 3
