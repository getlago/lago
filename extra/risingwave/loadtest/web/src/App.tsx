import { useEffect, useMemo, useState } from "react";
import {
  api,
  useLiveSnapshot,
  type ConfigView,
  type Discovery,
  type Health,
  type RunSpec,
  type Segment,
  type StoreInfo,
} from "./lib/api";
import { Setup } from "./views/Setup";
import { Targets } from "./views/Targets";
import { Run } from "./views/Run";
import { History } from "./views/History";

type Tab = "setup" | "targets" | "run" | "history";

const THEME_KEY = "lago-loadtest-theme";

export default function App() {
  const [tab, setTab] = useState<Tab>("run");
  const [config, setConfig] = useState<ConfigView | null>(null);
  const [store, setStore] = useState<StoreInfo | null>(null);
  const [health, setHealth] = useState<Health | null>(null);
  const [segments, setSegments] = useState<Segment[]>([]);
  const [spec, setSpec] = useState<RunSpec | null>(null);
  const [discovery, setDiscovery] = useState<Discovery | null>(null);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [probeTargetId, setProbeTargetId] = useState<string | null>(null);
  const [walletProbeTargetId, setWalletProbeTargetId] = useState<string | null>(null);
  const [theme, setTheme] = useState<"system" | "light" | "dark">(
    () => (localStorage.getItem(THEME_KEY) as "system" | "light" | "dark" | null) ?? "system",
  );

  const { snap, connected } = useLiveSnapshot();

  useEffect(() => {
    if (theme === "system") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", theme);
    localStorage.setItem(THEME_KEY, theme);
  }, [theme]);

  const checkHealth = () => {
    api.health().then(setHealth).catch(() => setHealth(null));
  };

  useEffect(() => {
    api.segments().then((r) => {
      setSegments(r.segments);
      setSpec((s) => s ?? r.defaultSpec);
    });
    api.getConfig().then((r) => {
      setConfig(r.config);
      setStore(r.store);
      // Nothing can run without connections, so start where the user must start.
      if (!r.store.configured) setTab("setup");
    });
    api.lastDiscovery().then((d) => {
      if (d.targets.length) setDiscovery(d);
    });
    checkHealth();
  }, []);

  // The spec the server receives always reflects the current picker state.
  const effectiveSpec: RunSpec | null = useMemo(
    () => (spec ? { ...spec, targetIds: [...selected], probeTargetId, walletProbeTargetId } : null),
    [spec, selected, probeTargetId, walletProbeTargetId],
  );

  const phase = snap?.phase ?? "idle";
  const running = ["preflight", "sending", "draining"].includes(phase);

  return (
    <div className="app">
      <header className="top">
        <div className="brand">
          <h1>RisingWave pipeline — load test</h1>
          <span>event → enrich → expand → ClickHouse → current usage</span>
        </div>
        <div className="spacer" />
        {running && (
          <span className="pill">
            <span className="dot live" />
            {phase} · {snap?.counters?.accepted ?? 0} accepted
          </span>
        )}
        <span className="pill" title={connected ? "live stream connected" : "live stream reconnecting"}>
          <span className={`dot ${connected ? "ok" : "warn"}`} />
          {connected ? "live" : "reconnecting"}
        </span>
        <nav className="tabs">
          {(
            [
              ["run", "Run"],
              ["targets", "Targets"],
              ["setup", "Setup"],
              ["history", "History"],
            ] as [Tab, string][]
          ).map(([k, label]) => (
            <button key={k} aria-current={tab === k ? "page" : undefined} onClick={() => setTab(k)}>
              {label}
              {k === "targets" && selected.size > 0 ? ` (${selected.size})` : ""}
            </button>
          ))}
        </nav>
        <select
          value={theme}
          onChange={(e) => setTheme(e.target.value as "system" | "light" | "dark")}
          style={{ width: 90 }}
          aria-label="Theme"
        >
          <option value="system">System</option>
          <option value="light">Light</option>
          <option value="dark">Dark</option>
        </select>
      </header>

      <main>
        {tab === "setup" && (
          <Setup
            config={config}
            store={store}
            health={health}
            onSaved={(c, st) => {
              setConfig(c);
              setStore(st);
            }}
            onCheck={checkHealth}
          />
        )}
        {tab === "targets" && (
          <Targets
            discovery={discovery}
            selected={selected}
            probeTargetId={probeTargetId}
            walletProbeTargetId={walletProbeTargetId}
            onDiscovered={(d) => {
              setDiscovery(d);
              setSelected(new Set());
              setProbeTargetId(null);
              setWalletProbeTargetId(null);
            }}
            onSelect={setSelected}
            onProbe={setProbeTargetId}
            onWalletProbe={setWalletProbeTargetId}
          />
        )}
        {tab === "run" && effectiveSpec && (
          <Run
            segments={segments}
            spec={effectiveSpec}
            setSpec={(s) => setSpec(s)}
            discovery={discovery}
            snap={snap}
            connected={connected}
          />
        )}
        {tab === "history" && <History segments={segments} />}
      </main>
    </div>
  );
}
