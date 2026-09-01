from __future__ import annotations

from enum import IntEnum, StrEnum
from typing import Literal

from pydantic import BaseModel, Field


class PortState(StrEnum):
    DISCONNECTED = "DISCONNECTED"
    ENUMERATING = "ENUMERATING"
    AUTHORIZED = "AUTHORIZED"
    QUARANTINED = "QUARANTINED"
    MANUAL_BLOCKED = "MANUAL_BLOCKED"


class ThreatCode(IntEnum):
    NO_FAULT = 0
    UNAUTHORIZED_HID = 1
    KEYSTROKE_BURST = 2
    COOLDOWN_BURST = 3
    DESCRIPTOR_OVERFLOW = 4
    CRC_TOKEN_FAULT = 5
    BIT_STUFF_ERROR = 6
    MANUAL_HOST_KILL = 7


THREAT_NAMES: dict[int, str] = {code.value: code.name for code in ThreatCode}


class PortStatus(BaseModel):
    port: int = Field(ge=0, le=3)
    state: PortState
    threat_code: int = Field(ge=0, le=7)
    vbus_mv: int = Field(ge=0)
    current_ma: int = Field(ge=0)
    vid: str
    pid: str
    dev_class: str
    int_class: str


class TelemetryFrame(BaseModel):
    type: Literal["telemetry"] = "telemetry"
    timestamp_ms: int
    ports: list[PortStatus]


class SecurityEvent(BaseModel):
    type: Literal["event"] = "event"
    timestamp_ms: int
    port: int = Field(ge=0, le=3)
    threat_code: int = Field(ge=0, le=7)
    threat_name: str
    state: PortState
    message: str


class SnapshotMessage(BaseModel):
    type: Literal["snapshot"] = "snapshot"
    mode: str
    events: list[SecurityEvent]
    telemetry: TelemetryFrame


class CommandType(StrEnum):
    ISOLATE_PORT = "isolate_port"
    RESTORE_PORT = "restore_port"
    CLEAR_FAULT = "clear_fault"


class CommandMessage(BaseModel):
    type: Literal["command"] = "command"
    cmd: CommandType
    port: int = Field(ge=0, le=3)
