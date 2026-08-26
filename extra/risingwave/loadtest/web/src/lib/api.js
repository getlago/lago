import { useEffect, useRef, useState } from "react";
async function json(url, init) {
    // Only declare a JSON body when one is actually being sent: a POST with
    // Content-Type: application/json and no body is a 400 by spec.
    const res = await fetch(url, {
        ...init,
        headers: {
            ...(init?.body != null ? { "Content-Type": "application/json" } : {}),
            ...(init?.headers ?? {}),
        },
    });
    const text = await res.text();
    const body = text ? JSON.parse(text) : {};
    if (!res.ok)
        throw Object.assign(new Error(body.error ?? `HTTP ${res.status}`), { status: res.status, body });
    return body;
}
export const api = {
    segments: () => json("/api/segments"),
    getConfig: () => json("/api/config"),
    putConfig: (patch) => json("/api/config", { method: "PUT", body: JSON.stringify(patch) }),
    health: () => json("/api/health"),
    discover: () => json("/api/discover", { method: "POST" }),
    lastDiscovery: () => json("/api/discover"),
    startRun: (spec) => json("/api/runs", { method: "POST", body: JSON.stringify(spec) }),
    stopRun: () => json("/api/runs/current/stop", { method: "POST" }),
    runs: () => json("/api/runs"),
    run: (id) => json(`/api/runs/${id}`),
};
/** Live snapshots over SSE, with automatic reconnect. */
export function useLiveSnapshot() {
    const [snap, setSnap] = useState(null);
    const [connected, setConnected] = useState(false);
    const esRef = useRef(null);
    useEffect(() => {
        let stopped = false;
        const open = () => {
            if (stopped)
                return;
            const es = new EventSource("/api/stream");
            esRef.current = es;
            es.onopen = () => setConnected(true);
            es.onmessage = (e) => {
                try {
                    setSnap(JSON.parse(e.data));
                }
                catch {
                    /* ignore a partial frame */
                }
            };
            es.onerror = () => {
                setConnected(false);
                es.close();
                setTimeout(open, 1500);
            };
        };
        open();
        return () => {
            stopped = true;
            esRef.current?.close();
        };
    }, []);
    return { snap, connected };
}
// ------------------------------------------------------------------ formatting
export function ms(v, digits = 0) {
    if (v == null || !Number.isFinite(v))
        return "—";
    if (Math.abs(v) >= 10_000)
        return `${(v / 1000).toFixed(1)}s`;
    if (Math.abs(v) < 1)
        return `${v.toFixed(2)}ms`;
    return `${v.toFixed(digits)}ms`;
}
export function num(v) {
    if (v == null || !Number.isFinite(v))
        return "—";
    return v.toLocaleString();
}
export function pct(part, whole) {
    if (!whole)
        return "—";
    return `${((part / whole) * 100).toFixed(1)}%`;
}
export function duration(msValue) {
    if (!msValue || msValue < 0)
        return "—";
    const s = Math.round(msValue / 1000);
    if (s < 60)
        return `${s}s`;
    return `${Math.floor(s / 60)}m ${String(s % 60).padStart(2, "0")}s`;
}
