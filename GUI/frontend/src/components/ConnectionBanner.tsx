interface ConnectionBannerProps {
  connected: boolean;
  mode: string;
}

export function ConnectionBanner({ connected, mode }: ConnectionBannerProps) {
  return (
    <div className="flex items-center gap-3">
      <span
        className={`h-2.5 w-2.5 rounded-full ${connected ? "bg-ok" : "bg-danger"}`}
        aria-hidden="true"
      />
      <span className="text-sm text-muted">
        {connected ? "Connected" : "Reconnecting…"}
      </span>
      <span className="rounded-full border border-border px-2.5 py-0.5 font-mono text-xs text-accent uppercase">
        {mode}
      </span>
    </div>
  );
}
