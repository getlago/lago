import { jsx as _jsx, jsxs as _jsxs, Fragment as _Fragment } from "react/jsx-runtime";
import { useEffect, useState } from "react";
import { api, duration, ms, num } from "../lib/api";
import { Card, ClockPanel, ErrorsPanel, PercentileTable } from "../components/panels";
import { PercentileBars } from "../components/charts";
const HEADLINE = "ch_rw_expanded_visible";
export function History({ segments }) {
    const [runs, setRuns] = useState(null);
    const [open, setOpen] = useState(null);
    const [err, setErr] = useState(null);
    const load = () => {
        api
            .runs()
            .then((r) => setRuns(r.runs))
            .catch((e) => setErr(e.message));
    };
    useEffect(load, []);
    const openRun = async (id) => {
        try {
            setOpen(await api.run(id));
        }
        catch (e) {
            setErr(e.message);
        }
    };
    const rows = open
        ? segments
            .filter((s) => s.kind === "polled" && open.stats?.[s.key])
            .map((s) => {
            const p = open.stats[s.key];
            return { key: s.key, label: s.label, p50: p.p50, p95: p.p95, p99: p.p99, count: p.count };
        })
        : [];
    return (_jsxs(_Fragment, { children: [_jsxs(Card, { title: "Past runs", hint: "persisted under loadtest/runs/<id>/ as summary.json + events.jsonl", right: _jsx("button", { className: "btn", onClick: load, children: "Refresh" }), children: [err && _jsx("p", { style: { color: "var(--critical)" }, children: err }), !runs && _jsx("p", { style: { color: "var(--text-muted)" }, children: "Loading\u2026" }), runs && runs.length === 0 && _jsx("p", { style: { color: "var(--text-muted)" }, children: "No runs yet." }), runs && runs.length > 0 && (_jsx("div", { className: "scroll", children: _jsxs("table", { className: "data", children: [_jsx("thead", { children: _jsxs("tr", { children: [_jsx("th", { children: "Run" }), _jsx("th", { children: "Started" }), _jsx("th", { children: "Duration" }), _jsx("th", { children: "Rate" }), _jsx("th", { children: "Sent" }), _jsx("th", { children: "Phase" }), _jsx("th", { children: "P50 \u2192 CH expanded" }), _jsx("th", { children: "P99 \u2192 CH expanded" }), _jsx("th", {})] }) }), _jsx("tbody", { children: runs.map((r) => (_jsxs("tr", { children: [_jsx("td", { className: "mono", children: r.id }), _jsx("td", { children: new Date(r.startedAt).toLocaleString() }), _jsx("td", { className: "num", children: duration(r.endedAt - r.startedAt) }), _jsxs("td", { className: "num", children: [num(r.rateEps), "/s"] }), _jsx("td", { className: "num", children: num(r.sent) }), _jsx("td", { children: r.phase }), _jsx("td", { className: "num", children: ms(r.stats?.[HEADLINE]?.p50) }), _jsx("td", { className: "num", children: ms(r.stats?.[HEADLINE]?.p99) }), _jsx("td", { children: _jsx("button", { className: "btn", style: { padding: "3px 10px", fontSize: 12 }, onClick: () => openRun(r.id), children: "Open" }) })] }, r.id))) })] }) }))] }), open && (_jsxs(_Fragment, { children: [_jsx(Card, { title: `Run ${open.id}`, hint: `${num(open.counters?.accepted)} accepted at ${num(open.spec?.rateEps)}/s · ${duration(open.elapsedMs)}`, right: _jsx("button", { className: "btn", onClick: () => setOpen(null), children: "Close" }), children: _jsx(PercentileBars, { rows: rows }) }), _jsx(Card, { title: "All segments", children: _jsx(PercentileTable, { segments: segments, stats: open.stats ?? {}, unavailable: open.unavailable ?? [] }) }), _jsxs("div", { className: "grid cols-2", children: [_jsx(Card, { title: "Clock offsets", children: _jsx(ClockPanel, { clocks: open.clocks }) }), _jsx(Card, { title: "Errors", children: _jsx(ErrorsPanel, { errors: open.errors ?? [] }) })] })] }))] }));
}
