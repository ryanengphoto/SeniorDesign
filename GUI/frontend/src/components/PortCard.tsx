import type { CommandType, PortStatus } from "../types/protocol";
import { stateColor, stateLabel, ThreatBadge } from "./ThreatBadge";

interface PortCardProps {
  port: PortStatus;
  onCommand: (cmd: CommandType, port: number) => void;
}

export function PortCard({ port, onCommand }: PortCardProps) {
  const canIsolate =
    port.state !== "DISCONNECTED" && port.state !== "MANUAL_BLOCKED";
  const canRestore =
    port.state === "MANUAL_BLOCKED" || port.state === "QUARANTINED";
  const canClearFault = port.threat_code > 0;

  return (
    <article className="flex h-full flex-col rounded-xl border border-border bg-surface p-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-mono text-xs tracking-widest text-muted uppercase">
            Port {port.port + 1}
          </p>
          <span
            className={`mt-2 inline-flex rounded-full border px-2.5 py-0.5 text-xs font-medium ${stateColor(port.state)}`}
          >
            {stateLabel(port.state)}
          </span>
        </div>
        <ThreatBadge threatCode={port.threat_code} />
      </div>

      <dl className="mt-5 grid grid-cols-2 gap-3 text-sm">
        <div>
          <dt className="text-xs text-muted">VID / PID</dt>
          <dd className="mt-1 font-mono text-text">
            {port.vid} / {port.pid}
          </dd>
        </div>
        <div>
          <dt className="text-xs text-muted">Classes</dt>
          <dd className="mt-1 font-mono text-text">
            {port.dev_class} / {port.int_class}
          </dd>
        </div>
        <div>
          <dt className="text-xs text-muted">VBUS</dt>
          <dd className="mt-1 font-mono text-text">
            {(port.vbus_mv / 1000).toFixed(2)} V
          </dd>
        </div>
        <div>
          <dt className="text-xs text-muted">Current</dt>
          <dd className="mt-1 font-mono text-text">{port.current_ma} mA</dd>
        </div>
      </dl>

      <div className="mt-auto flex flex-wrap gap-2 pt-5">
        <button
          type="button"
          disabled={!canIsolate}
          onClick={() => onCommand("isolate_port", port.port)}
          className="rounded-lg border border-danger/40 px-3 py-1.5 text-xs font-medium text-danger transition-colors enabled:hover:bg-danger/10 disabled:cursor-not-allowed disabled:opacity-40"
        >
          Isolate
        </button>
        <button
          type="button"
          disabled={!canRestore}
          onClick={() => onCommand("restore_port", port.port)}
          className="rounded-lg border border-ok/40 px-3 py-1.5 text-xs font-medium text-ok transition-colors enabled:hover:bg-ok/10 disabled:cursor-not-allowed disabled:opacity-40"
        >
          Restore
        </button>
        <button
          type="button"
          disabled={!canClearFault}
          onClick={() => onCommand("clear_fault", port.port)}
          className="rounded-lg border border-border px-3 py-1.5 text-xs font-medium text-muted transition-colors enabled:hover:border-accent/40 enabled:hover:text-accent disabled:cursor-not-allowed disabled:opacity-40"
        >
          Clear fault
        </button>
      </div>
    </article>
  );
}
