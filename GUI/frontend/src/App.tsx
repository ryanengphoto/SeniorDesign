import { ConnectionBanner } from "./components/ConnectionBanner";
import { EventLog } from "./components/EventLog";
import { PortCard } from "./components/PortCard";
import { useHubSocket } from "./hooks/useHubSocket";

const EMPTY_PORTS = Array.from({ length: 4 }, (_, port) => ({
  port,
  state: "DISCONNECTED" as const,
  threat_code: 0,
  vbus_mv: 0,
  current_ma: 0,
  vid: "0x0000",
  pid: "0x0000",
  dev_class: "0x00",
  int_class: "0x00",
}));

export default function App() {
  const { connected, mode, telemetry, events, sendCommand } = useHubSocket();
  const ports = telemetry?.ports ?? EMPTY_PORTS;

  return (
    <div className="min-h-screen">
      <header className="border-b border-border bg-surface/80 backdrop-blur">
        <div className="mx-auto flex max-w-7xl flex-col gap-4 px-6 py-5 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="font-mono text-xs tracking-widest text-accent uppercase">
              Operator Console
            </p>
            <h1 className="text-2xl font-bold tracking-tight">
              Hardware-secure USB Hub
            </h1>
          </div>
          <ConnectionBanner connected={connected} mode={mode} />
        </div>
      </header>

      <main className="mx-auto grid max-w-7xl gap-6 px-6 py-8 lg:grid-cols-[minmax(0,2fr)_minmax(320px,1fr)]">
        <section>
          <div className="mb-4">
            <h2 className="text-lg font-semibold">Downstream ports</h2>
            <p className="text-sm text-muted">
              Live telemetry from the hub management plane.
            </p>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            {ports.map((port) => (
              <PortCard key={port.port} port={port} onCommand={sendCommand} />
            ))}
          </div>
        </section>

        <section className="min-h-0">
          <EventLog events={events} />
        </section>
      </main>
    </div>
  );
}
