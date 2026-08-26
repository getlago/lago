import { jsx as _jsx, jsxs as _jsxs, Fragment as _Fragment } from "react/jsx-runtime";
import { ms, num } from "../lib/api";
export function Card({ title, hint, right, children, }) {
    return (_jsxs("section", { className: "card", children: [_jsxs("header", { children: [_jsx("h2", { children: title }), hint && _jsx("span", { className: "hint", children: hint }), _jsx("div", { style: { flex: 1 } }), right] }), children] }));
}
export function Stat({ label, value, sub }) {
    return (_jsxs("div", { className: "stat", children: [_jsx("span", { className: "label", children: label }), _jsx("span", { className: "value", children: value }), sub != null && _jsx("span", { className: "sub", children: sub })] }));
}
export function HealthPills({ health, onRefresh }) {
    const item = (name, s) => (_jsxs("span", { className: "pill", title: s?.error ?? s?.version ?? s?.brokers ?? "not checked", children: [_jsx("span", { className: `dot ${s ? (s.ok ? "ok" : "bad") : ""}` }), name] }));
    return (_jsxs("div", { className: "row", children: [item("Lago", health?.lago), item("RisingWave", health?.risingwave), item("ClickHouse", health?.clickhouse), item("Redpanda", health?.redpanda), _jsx("button", { className: "btn", onClick: onRefresh, style: { padding: "3px 10px", fontSize: 12 }, children: "Test" })] }));
}
export function Checklist({ checks }) {
    if (checks.length === 0)
        return null;
    return (_jsx("div", { className: "checklist", children: checks.map((c) => (_jsxs("div", { className: "item", children: [_jsx("span", { className: `dot ${c.ok ? "ok" : "bad"}`, style: { marginTop: 6 } }), _jsx("span", { className: "name", children: c.name }), _jsxs("span", { className: "detail", children: [c.detail, !c.ok && c.gates.length > 0 && (_jsxs("em", { style: { color: "var(--text-muted)" }, children: [" \u2014 blocks: ", c.gates.join(", ")] }))] })] }, c.name + c.detail))) }));
}
/**
 * Clock offsets are surfaced, never silently applied: a stamped segment spanning
 * two machines is only as trustworthy as the gap between their clocks.
 */
export function ClockPanel({ clocks }) {
    if (!clocks)
        return null;
    const rows = [
        ["Lago API", clocks.lago, "from the HTTP Date header, ±1s by construction"],
        ["RisingWave", clocks.risingwave, "SELECT now() over pgwire, RTT-corrected"],
        ["ClickHouse", clocks.clickhouse, "SELECT now64(3) over HTTPS, RTT-corrected"],
    ];
    const worst = Math.max(...rows.map(([, v]) => (v == null ? 0 : Math.abs(v))));
    return (_jsxs(_Fragment, { children: [_jsxs("table", { className: "data", children: [_jsx("thead", { children: _jsxs("tr", { children: [_jsx("th", { children: "Clock" }), _jsx("th", { children: "Offset vs this app" }), _jsx("th", { style: { textAlign: "left" }, children: "How it was measured" })] }) }), _jsx("tbody", { children: rows.map(([name, v, how]) => (_jsxs("tr", { children: [_jsx("td", { children: name }), _jsx("td", { className: "num", children: v == null ? "—" : `${v >= 0 ? "+" : ""}${v} ms` }), _jsx("td", { style: { textAlign: "left", color: "var(--text-secondary)", fontSize: 12 }, children: how })] }, name))) })] }), _jsx("p", { style: { marginTop: 10, fontSize: 12, color: "var(--text-secondary)" }, children: worst > 250 ? (_jsxs(_Fragment, { children: [_jsx("b", { style: { color: "var(--warning)" }, children: "\u26A0 offsets above 250 ms" }), " \u2014 read the stamped breakdown with that in mind. The polled end-to-end numbers are unaffected: both of their endpoints are read from this app's clock."] })) : (_jsx(_Fragment, { children: "Offsets are small, so the stamped hop breakdown is meaningful. The polled end-to-end numbers never depend on these at all \u2014 both endpoints come from this app's clock." })) })] }));
}
export function PercentileTable({ segments, stats, unavailable, }) {
    return (_jsx("div", { className: "scroll", children: _jsxs("table", { className: "data", children: [_jsx("thead", { children: _jsxs("tr", { children: [_jsx("th", { children: "Segment" }), _jsx("th", { children: "n" }), _jsx("th", { children: "min" }), _jsx("th", { children: "P50" }), _jsx("th", { children: "P95" }), _jsx("th", { children: "P99" }), _jsx("th", { children: "max" }), _jsx("th", { children: "mean" })] }) }), _jsx("tbody", { children: segments.map((seg) => {
                        const p = stats[seg.key];
                        const off = unavailable.includes(seg.key);
                        return (_jsxs("tr", { className: p ? "" : "unavailable", children: [_jsxs("td", { title: `${seg.from} → ${seg.to}${seg.note ? `\n\n${seg.note}` : ""}`, children: [seg.label, seg.kind === "stamped" && (_jsxs("span", { style: { color: "var(--text-muted)", fontSize: 11 }, children: [" \u00B7 clocks: ", seg.clocks.join(" → ")] }))] }), p ? (_jsxs(_Fragment, { children: [_jsx("td", { className: "num", children: num(p.count) }), _jsx("td", { className: "num", title: p.min < 0 ? "negative = clock skew between the two machines" : undefined, children: p.min < 0 ? `⚠ ${ms(p.min, 1)}` : ms(p.min, 1) }), _jsx("td", { className: "num", title: p.p50 < 0 ? "negative = clock skew between the two machines" : undefined, children: p.p50 < 0 ? `⚠ ${ms(p.p50, 1)}` : ms(p.p50, 1) }), _jsx("td", { className: "num", children: ms(p.p95, 1) }), _jsx("td", { className: "num", children: ms(p.p99, 1) }), _jsx("td", { className: "num", children: ms(p.max, 1) }), _jsx("td", { className: "num", children: ms(p.mean, 1) })] })) : (_jsx("td", { colSpan: 7, style: { textAlign: "left" }, children: off ? "not measurable in this run" : "no samples yet" }))] }, seg.key));
                    }) })] }) }));
}
export function ErrorsPanel({ errors }) {
    if (errors.length === 0)
        return (_jsxs("p", { style: { color: "var(--text-secondary)", fontSize: 13 }, children: [_jsx("span", { className: "dot ok", style: { display: "inline-block", marginRight: 6 } }), "No errors."] }));
    return (_jsxs("table", { className: "data", children: [_jsx("thead", { children: _jsxs("tr", { children: [_jsx("th", { children: "Error" }), _jsx("th", { children: "Count" })] }) }), _jsx("tbody", { children: errors.map((e) => (_jsxs("tr", { children: [_jsx("td", { style: { fontFamily: "var(--mono)", fontSize: 12 }, children: e.msg }), _jsx("td", { className: "num", children: num(e.count) })] }, e.msg))) })] }));
}
export function LogPanel({ logs }) {
    if (!logs || logs.length === 0)
        return _jsx("p", { style: { color: "var(--text-muted)", fontSize: 13 }, children: "Nothing logged yet." });
    return (_jsx("div", { className: "log", children: [...logs].reverse().map((l, i) => (_jsxs("div", { className: l.level === "warn" ? "l-warn" : l.level === "error" ? "l-error" : "", children: [_jsxs("span", { className: "t", children: [new Date(l.t).toLocaleTimeString(), " "] }), l.msg] }, i))) }));
}
export function Banner({ kind, children }) {
    const icon = kind === "bad" ? "✕" : kind === "warn" ? "⚠" : "i";
    return (_jsxs("div", { className: `banner ${kind}`, children: [_jsx("span", { "aria-hidden": true, style: { fontWeight: 700 }, children: icon }), _jsx("span", { children: children })] }));
}
