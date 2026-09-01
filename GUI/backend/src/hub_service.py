from __future__ import annotations

import os
from collections import deque

from .mock_device import MockDevice
from .protocol import (
    CommandMessage,
    CommandType,
    PortState,
    SecurityEvent,
    TelemetryFrame,
    THREAT_NAMES,
)
from .serial_device import SerialDevice


class HubService:
    def __init__(self, max_events: int = 200) -> None:
        mode = os.getenv("HUB_MODE", "mock").lower()
        if mode == "serial":
            self._device: MockDevice | SerialDevice = SerialDevice(
                port=os.getenv("SERIAL_PORT", "/dev/ttyACM0"),
            )
        else:
            self._device = MockDevice()

        self._events: deque[SecurityEvent] = deque(maxlen=max_events)
        self._last_snapshot: dict[int, tuple[PortState, int]] = {}

    @property
    def mode(self) -> str:
        return self._device.mode

    def start(self) -> None:
        self._device.start()
        self._record_initial_events()

    async def stop(self) -> None:
        await self._device.stop()

    def get_telemetry(self) -> TelemetryFrame:
        telemetry = self._device.get_telemetry()
        self._detect_changes(telemetry)
        return telemetry

    def get_events(self) -> list[SecurityEvent]:
        return list(self._events)

    def handle_command(self, command: CommandMessage) -> SecurityEvent | None:
        if isinstance(self._device, SerialDevice):
            raise NotImplementedError("Serial command path not implemented")

        port_id = command.port
        result: tuple[PortState, int, str] | None = None

        if command.cmd == CommandType.ISOLATE_PORT:
            result = self._device.isolate_port(port_id)
        elif command.cmd == CommandType.RESTORE_PORT:
            result = self._device.restore_port(port_id)
        elif command.cmd == CommandType.CLEAR_FAULT:
            result = self._device.clear_fault(port_id)

        if result is None:
            return None

        state, threat_code, message = result
        event = SecurityEvent(
            timestamp_ms=self._device.get_telemetry().timestamp_ms,
            port=port_id,
            threat_code=threat_code,
            threat_name=THREAT_NAMES.get(threat_code, "UNKNOWN"),
            state=state,
            message=message,
        )
        self._events.append(event)
        self._last_snapshot[port_id] = (state, threat_code)
        return event

    def _record_initial_events(self) -> None:
        telemetry = self._device.get_telemetry()
        for port in telemetry.ports:
            self._last_snapshot[port.port] = (port.state, port.threat_code)

    def _detect_changes(self, telemetry: TelemetryFrame) -> None:
        for port in telemetry.ports:
            previous = self._last_snapshot.get(port.port)
            current = (port.state, port.threat_code)
            if previous == current:
                continue

            self._last_snapshot[port.port] = current
            if previous is None:
                continue

            prev_state, prev_threat = previous
            if port.threat_code == 0 and port.state == prev_state:
                continue

            if port.threat_code == 2 and port.state == PortState.QUARANTINED:
                message = f"Keystroke burst detected on port {port.port}"
            elif port.threat_code == 1:
                message = f"Unauthorized HID detected on port {port.port}"
            elif port.state == PortState.ENUMERATING:
                message = f"Device enumerating on port {port.port}"
            elif port.state == PortState.AUTHORIZED and prev_state == PortState.ENUMERATING:
                message = f"Device authorized on port {port.port}"
            else:
                message = (
                    f"Port {port.port} changed to {port.state.value} "
                    f"({THREAT_NAMES.get(port.threat_code, 'UNKNOWN')})"
                )

            self._events.append(
                SecurityEvent(
                    timestamp_ms=telemetry.timestamp_ms,
                    port=port.port,
                    threat_code=port.threat_code,
                    threat_name=THREAT_NAMES.get(port.threat_code, "UNKNOWN"),
                    state=port.state,
                    message=message,
                )
            )
