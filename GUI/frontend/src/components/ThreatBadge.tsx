import type { PortState } from "../types/protocol";

interface ThreatBadgeProps {
  threatCode: number;
  threatName?: string;
}

export function ThreatBadge({ threatCode, threatName }: ThreatBadgeProps) {
  if (threatCode === 0) {
    return null;
  }

  const label = threatName ?? `THREAT_${threatCode}`;

  return (
    <span className="inline-flex items-center rounded-full border border-danger/40 bg-danger/10 px-2.5 py-0.5 font-mono text-xs font-medium text-danger">
      {label}
    </span>
  );
}

export function stateLabel(state: PortState): string {
  return state.replaceAll("_", " ");
}

export function stateColor(state: PortState): string {
  switch (state) {
    case "AUTHORIZED":
      return "text-ok border-ok/30 bg-ok/10";
    case "ENUMERATING":
      return "text-warn border-warn/30 bg-warn/10";
    case "QUARANTINED":
    case "MANUAL_BLOCKED":
      return "text-danger border-danger/30 bg-danger/10";
    default:
      return "text-muted border-border bg-surface-raised";
  }
}
