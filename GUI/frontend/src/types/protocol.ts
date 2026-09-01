export type PortState =
  | "DISCONNECTED"
  | "ENUMERATING"
  | "AUTHORIZED"
  | "QUARANTINED"
  | "MANUAL_BLOCKED";

export type CommandType = "isolate_port" | "restore_port" | "clear_fault";

export interface PortStatus {
  port: number;
  state: PortState;
  threat_code: number;
  vbus_mv: number;
  current_ma: number;
  vid: string;
  pid: string;
  dev_class: string;
  int_class: string;
}

export interface TelemetryFrame {
  type: "telemetry";
  timestamp_ms: number;
  ports: PortStatus[];
}

export interface SecurityEvent {
  type: "event";
  timestamp_ms: number;
  port: number;
  threat_code: number;
  threat_name: string;
  state: PortState;
  message: string;
}

export interface SnapshotMessage {
  type: "snapshot";
  mode: string;
  events: SecurityEvent[];
  telemetry: TelemetryFrame;
}

export interface CommandMessage {
  type: "command";
  cmd: CommandType;
  port: number;
}

export const THREAT_NAMES: Record<number, string> = {
  0: "NO_FAULT",
  1: "UNAUTHORIZED_HID",
  2: "KEYSTROKE_BURST",
  3: "COOLDOWN_BURST",
  4: "DESCRIPTOR_OVERFLOW",
  5: "CRC_TOKEN_FAULT",
  6: "BIT_STUFF_ERROR",
  7: "MANUAL_HOST_KILL",
};

export type HubMessage = TelemetryFrame | SecurityEvent | SnapshotMessage;

export function isSnapshot(message: HubMessage): message is SnapshotMessage {
  return message.type === "snapshot";
}

export function isTelemetry(message: HubMessage): message is TelemetryFrame {
  return message.type === "telemetry";
}

export function isEvent(message: HubMessage): message is SecurityEvent {
  return message.type === "event";
}
