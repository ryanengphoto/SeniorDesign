import { useEffect, useRef, useState } from "react";
import type { SecurityEvent } from "../types/protocol";

interface EventLogProps {
  events: SecurityEvent[];
}

function formatTime(timestampMs: number): string {
  const totalSeconds = Math.floor(timestampMs / 1000);
  const minutes = Math.floor(totalSeconds / 60)
    .toString()
    .padStart(2, "0");
  const seconds = (totalSeconds % 60).toString().padStart(2, "0");
  const millis = (timestampMs % 1000).toString().padStart(3, "0");
  return `${minutes}:${seconds}.${millis}`;
}

export function EventLog({ events }: EventLogProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    if (paused || !containerRef.current) {
      return;
    }
    containerRef.current.scrollTop = containerRef.current.scrollHeight;
  }, [events, paused]);

  return (
    <section className="flex h-full min-h-80 flex-col rounded-xl border border-border bg-surface">
      <header className="flex items-center justify-between border-b border-border px-4 py-3">
        <div>
          <h2 className="text-sm font-semibold">Security event log</h2>
          <p className="text-xs text-muted">
            {events.length} event{events.length === 1 ? "" : "s"}
          </p>
        </div>
        {paused && (
          <span className="font-mono text-xs text-warn">Auto-scroll paused</span>
        )}
      </header>

      <div
        ref={containerRef}
        onMouseEnter={() => setPaused(true)}
        onMouseLeave={() => setPaused(false)}
        className="flex-1 overflow-y-auto px-4 py-3"
      >
        {events.length === 0 ? (
          <p className="text-sm text-muted">Waiting for security events…</p>
        ) : (
          <ul className="space-y-3">
            {events.map((event, index) => (
              <li
                key={`${event.timestamp_ms}-${event.port}-${index}`}
                className="rounded-lg border border-border bg-surface-raised px-3 py-2"
              >
                <div className="flex items-center justify-between gap-3">
                  <span className="font-mono text-xs text-accent">
                    {formatTime(event.timestamp_ms)}
                  </span>
                  <span className="font-mono text-xs text-muted">
                    Port {event.port + 1}
                  </span>
                </div>
                <p className="mt-1 text-sm font-medium">{event.threat_name}</p>
                <p className="mt-1 text-sm text-muted">{event.message}</p>
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  );
}
