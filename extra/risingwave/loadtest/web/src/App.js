import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useMemo, useState } from "react";
import { api, useLiveSnapshot, } from "./lib/api";
import { Setup } from "./views/Setup";
import { Targets } from "./views/Targets";
import { Run } from "./views/Run";
import { History } from "./views/History";
const THEME_KEY = "lago-loadtest-theme";
export default function App() {
    const [tab, setTab] = useState("run");
    const [config, setConfig] = useState(null);
    const [store, setStore] = useState(null);
    const [health, setHealth] = useState(null);
    const [segments, setSegments] = useState([]);
    const [spec, setSpec] = useState(null);
    const [discovery, setDiscovery] = useState(null);
    const [selected, setSelected] = useState(new Set());
    const [probeTargetId, setProbeTargetId] = useState(null);
    const [walletProbeTargetId, setWalletProbeTargetId] = useState(null);
    const [theme, setTheme] = useState(() => localStorage.getItem(THEME_KEY) ?? "system");
    const { snap, connected } = useLiveSnapshot();
    useEffect(() => {
        if (theme === "system")
            document.documentElement.removeAttribute("data-theme");
        else
            document.documentElement.setAttribute("data-theme", theme);
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
            if (!r.store.configured)
                setTab("setup");
        });
        api.lastDiscovery().then((d) => {
            if (d.targets.length)
                setDiscovery(d);
        });
        checkHealth();
    }, []);
    // The spec the server receives always reflects the current picker state.
    const effectiveSpec = useMemo(() => (spec ? { ...spec, targetIds: [...selected], probeTargetId, walletProbeTargetId } : null), [spec, selected, probeTargetId, walletProbeTargetId]);
    const phase = snap?.phase ?? "idle";
    const running = ["preflight", "sending", "draining"].includes(phase);
    return (_jsxs("div", { className: "app", children: [_jsxs("header", { className: "top", children: [_jsxs("div", { className: "brand", children: [_jsx("h1", { children: "RisingWave pipeline \u2014 load test" }), _jsx("span", { children: "event \u2192 enrich \u2192 expand \u2192 ClickHouse \u2192 current usage" })] }), _jsx("div", { className: "spacer" }), running && (_jsxs("span", { className: "pill", children: [_jsx("span", { className: "dot live" }), phase, " \u00B7 ", snap?.counters?.accepted ?? 0, " accepted"] })), _jsxs("span", { className: "pill", title: connected ? "live stream connected" : "live stream reconnecting", children: [_jsx("span", { className: `dot ${connected ? "ok" : "warn"}` }), connected ? "live" : "reconnecting"] }), _jsx("nav", { className: "tabs", children: [
                            ["run", "Run"],
                            ["targets", "Targets"],
                            ["setup", "Setup"],
                            ["history", "History"],
                        ].map(([k, label]) => (_jsxs("button", { "aria-current": tab === k ? "page" : undefined, onClick: () => setTab(k), children: [label, k === "targets" && selected.size > 0 ? ` (${selected.size})` : ""] }, k))) }), _jsxs("select", { value: theme, onChange: (e) => setTheme(e.target.value), style: { width: 90 }, "aria-label": "Theme", children: [_jsx("option", { value: "system", children: "System" }), _jsx("option", { value: "light", children: "Light" }), _jsx("option", { value: "dark", children: "Dark" })] })] }), _jsxs("main", { children: [tab === "setup" && (_jsx(Setup, { config: config, store: store, health: health, onSaved: (c, st) => {
                            setConfig(c);
                            setStore(st);
                        }, onCheck: checkHealth })), tab === "targets" && (_jsx(Targets, { discovery: discovery, selected: selected, probeTargetId: probeTargetId, walletProbeTargetId: walletProbeTargetId, onDiscovered: (d) => {
                            setDiscovery(d);
                            setSelected(new Set());
                            setProbeTargetId(null);
                            setWalletProbeTargetId(null);
                        }, onSelect: setSelected, onProbe: setProbeTargetId, onWalletProbe: setWalletProbeTargetId })), tab === "run" && effectiveSpec && (_jsx(Run, { segments: segments, spec: effectiveSpec, setSpec: (s) => setSpec(s), discovery: discovery, snap: snap, connected: connected })), tab === "history" && _jsx(History, { segments: segments })] })] }));
}
