import { useCallback, useEffect, useRef, useState } from "react";
import type {
  CommandMessage,
  CommandType,
  HubMessage,
  SecurityEvent,
  TelemetryFrame,
} from "../types/protocol";
import { isEvent, isSnapshot, isTelemetry } from "../types/protocol";

const WS_URL =
  import.meta.env.DEV
    ? `${window.location.protocol === "https:" ? "wss" : "ws"}://${window.location.host}/ws`
    : "ws://localhost:8000/ws";

const MAX_BACKOFF_MS = 5000;

export function useHubSocket() {
  const [connected, setConnected] = useState(false);
  const [mode, setMode] = useState("mock");
  const [telemetry, setTelemetry] = useState<TelemetryFrame | null>(null);
  const [events, setEvents] = useState<SecurityEvent[]>([]);
  const socketRef = useRef<WebSocket | null>(null);
  const reconnectRef = useRef<number | null>(null);
  const backoffRef = useRef(500);

  const sendCommand = useCallback((cmd: CommandType, port: number) => {
    const socket = socketRef.current;
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      return;
    }

    const message: CommandMessage = { type: "command", cmd, port };
    socket.send(JSON.stringify(message));
  }, []);

  useEffect(() => {
    let cancelled = false;

    const connect = () => {
      if (cancelled) {
        return;
      }

      const socket = new WebSocket(WS_URL);
      socketRef.current = socket;

      socket.onopen = () => {
        if (cancelled) {
          return;
        }
        setConnected(true);
        backoffRef.current = 500;
      };

      socket.onclose = () => {
        if (cancelled) {
          return;
        }
        setConnected(false);
        socketRef.current = null;
        const delay = backoffRef.current;
        backoffRef.current = Math.min(delay * 2, MAX_BACKOFF_MS);
        reconnectRef.current = window.setTimeout(connect, delay);
      };

      socket.onerror = () => {
        socket.close();
      };

      socket.onmessage = (event) => {
        try {
          const payload = JSON.parse(event.data) as HubMessage;
          if (!payload || typeof payload !== "object" || !("type" in payload)) {
            return;
          }

          if (isSnapshot(payload)) {
            setMode(payload.mode);
            setTelemetry(payload.telemetry);
            setEvents(payload.events);
            return;
          }

          if (isTelemetry(payload)) {
            setTelemetry(payload);
            return;
          }

          if (isEvent(payload)) {
            setEvents((current) => [...current, payload]);
          }
        } catch {
          // Ignore malformed frames.
        }
      };
    };

    connect();

    return () => {
      cancelled = true;
      if (reconnectRef.current !== null) {
        window.clearTimeout(reconnectRef.current);
      }
      socketRef.current?.close();
    };
  }, []);

  return { connected, mode, telemetry, events, sendCommand };
}
