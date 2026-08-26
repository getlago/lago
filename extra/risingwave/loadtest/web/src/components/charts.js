import { jsx as _jsx, jsxs as _jsxs, Fragment as _Fragment } from "react/jsx-runtime";
import { useCallback, useState } from "react";
import { ms, num } from "../lib/api";
export function useTooltip() {
    const [tip, setTip] = useState(null);
    const show = useCallback((e, title, rows) => {
        setTip({ x: e.clientX, y: e.clientY, title, rows });
    }, []);
    const hide = useCallback(() => setTip(null), []);
    const node = tip ? (_jsxs("div", { className: "tooltip", style: {
            left: Math.min(tip.x + 14, window.innerWidth - 300),
            top: Math.min(tip.y + 14, window.innerHeight - 120),
        }, children: [_jsx("div", { className: "t-title", children: tip.title }), tip.rows.map(([k, v]) => (_jsxs("div", { className: "t-row", children: [_jsx("span", { children: k }), _jsx("b", { children: v })] }, k)))] })) : null;
    return { show, hide, node };
}
/** Rounded on the data end only, so every bar shares one flat baseline. */
function barPathH(x, y, w, h, r = 4) {
    const rr = Math.max(0, Math.min(r, w, h / 2));
    if (w <= 0.5)
        return "";
    return [
        `M${x},${y}`,
        `H${x + w - rr}`,
        `a${rr},${rr} 0 0 1 ${rr},${rr}`,
        `V${y + h - rr}`,
        `a${rr},${rr} 0 0 1 ${-rr},${rr}`,
        `H${x}`,
        "Z",
    ].join(" ");
}
function niceTicks(max, count = 4) {
    if (!Number.isFinite(max) || max <= 0)
        return [0];
    const raw = max / count;
    const mag = Math.pow(10, Math.floor(Math.log10(raw)));
    const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((s) => s >= raw) ?? mag * 10;
    const out = [];
    for (let v = 0; v <= max * 1.0001; v += step)
        out.push(Math.round(v * 1000) / 1000);
    return out;
}
export function Empty({ children }) {
    return (_jsx("div", { style: { color: "var(--text-muted)", fontSize: 13, padding: "18px 4px" }, children: children }));
}
const ORD = ["var(--ord-1)", "var(--ord-2)", "var(--ord-3)"];
const ORD_LABELS = ["P50", "P95", "P99"];
/**
 * One row per stage, three bars per row. Percentiles are ORDERED magnitude, so
 * they get a single-hue ordinal ramp (light -> dark = P50 -> P99) rather than
 * three categorical hues, which would imply three unrelated things.
 */
export function PercentileBars({ rows, labelWidth = 300, unitHint = "ms — lower is better", }) {
    const tip = useTooltip();
    if (rows.length === 0)
        return _jsx(Empty, { children: "No samples yet." });
    const barH = 7;
    const gap = 2; // 2px surface gap between the three fills
    const rowH = barH * 3 + gap * 2 + 22;
    const padTop = 18;
    const padBottom = 22;
    const width = 900;
    const plotX = labelWidth + 12;
    const plotW = width - plotX - 74;
    const max = Math.max(...rows.map((r) => r.p99), 1);
    const ticks = niceTicks(max);
    const tickMax = ticks[ticks.length - 1] ?? max;
    const x = (v) => plotX + (Math.max(0, v) / tickMax) * plotW;
    const height = padTop + rows.length * rowH + padBottom;
    return (_jsxs(_Fragment, { children: [_jsxs("div", { className: "legend", style: { marginBottom: 8 }, children: [ORD_LABELS.map((l, i) => (_jsxs("span", { className: "item", children: [_jsx("span", { className: "swatch", style: { background: ORD[i], height: 7 } }), l] }, l))), _jsx("span", { style: { color: "var(--text-muted)" }, children: unitHint })] }), _jsx("div", { className: "scroll", children: _jsxs("svg", { viewBox: `0 0 ${width} ${height}`, width: "100%", height: height, role: "img", children: [ticks.map((t) => (_jsxs("g", { children: [_jsx("line", { x1: x(t), x2: x(t), y1: padTop - 6, y2: height - padBottom + 2, stroke: "var(--grid)", strokeWidth: "1" }), _jsx("text", { x: x(t), y: height - padBottom + 15, fontSize: "10", fill: "var(--text-muted)", textAnchor: "middle", children: t >= 1000 ? `${t / 1000}s` : t })] }, t))), rows.map((r, ri) => {
                            const y0 = padTop + ri * rowH;
                            const vals = [r.p50, r.p95, r.p99];
                            return (_jsxs("g", { children: [_jsx("text", { x: labelWidth, y: y0 + 12, fontSize: "12", fill: "var(--text-primary)", textAnchor: "end", children: r.label.length > 52 ? r.label.slice(0, 51) + "…" : r.label }), _jsxs("text", { x: labelWidth, y: y0 + 26, fontSize: "10", fill: "var(--text-muted)", textAnchor: "end", children: ["n=", num(r.count), r.note ? ` · ${r.note}` : ""] }), vals.map((v, i) => {
                                        const y = y0 + i * (barH + gap);
                                        const w = Math.max(0, x(v) - plotX);
                                        return (_jsxs("g", { onMouseMove: (e) => tip.show(e, r.label, [
                                                ["P50", ms(r.p50, 1)],
                                                ["P95", ms(r.p95, 1)],
                                                ["P99", ms(r.p99, 1)],
                                                ["samples", num(r.count)],
                                            ]), onMouseLeave: tip.hide, children: [_jsx("rect", { x: plotX, y: y - 1, width: plotW, height: barH + 2, fill: "transparent" }), _jsx("path", { d: barPathH(plotX, y, w, barH), fill: ORD[i] })] }, i));
                                    }), _jsx("text", { x: x(r.p99) + 8, y: y0 + barH * 2 + gap * 2 + 2, fontSize: "11", fill: "var(--text-secondary)", className: "mono", children: ms(r.p99) })] }, r.key));
                        })] }) }), tip.node] }));
}
/**
 * Where the median event actually spends its time, hop by hop. Stacked, so the
 * total is the sum of the parts — three categorical slots (the all-pairs-safe
 * first three), 2px gaps, direct labels on every segment wide enough to hold one.
 */
export function HopWaterfall({ hops }) {
    const tip = useTooltip();
    const usable = hops.filter((h) => Number.isFinite(h.value) && h.value > 0);
    if (usable.length === 0)
        return _jsx(Empty, { children: "No stamped hops available yet." });
    const colors = ["var(--series-1)", "var(--series-2)", "var(--series-3)"];
    const total = usable.reduce((s, h) => s + h.value, 0);
    const width = 900;
    const height = 96;
    const barY = 26;
    const barH = 26;
    const gap = 2;
    const plotW = width - 8;
    let cursor = 4;
    return (_jsxs(_Fragment, { children: [_jsx("div", { className: "legend", style: { marginBottom: 8 }, children: usable.map((h, i) => (_jsxs("span", { className: "item", children: [_jsx("span", { className: "swatch", style: { background: colors[i % colors.length], height: 8 } }), h.label, " ", _jsx("b", { className: "mono", children: ms(h.value) })] }, h.key))) }), _jsxs("svg", { viewBox: `0 0 ${width} ${height}`, width: "100%", height: height, role: "img", children: [_jsxs("text", { x: 4, y: 14, fontSize: "11", fill: "var(--text-muted)", children: ["median event, ingest \u2192 ClickHouse: ", _jsx("tspan", { fill: "var(--text-primary)", children: ms(total) })] }), usable.map((h, i) => {
                        const w = Math.max(0, (h.value / total) * (plotW - gap * (usable.length - 1)));
                        const x0 = cursor;
                        cursor += w + gap;
                        const last = i === usable.length - 1;
                        return (_jsxs("g", { onMouseMove: (e) => tip.show(e, h.label, [
                                ["median", ms(h.value, 1)],
                                ["share", `${((h.value / total) * 100).toFixed(1)}%`],
                            ]), onMouseLeave: tip.hide, children: [_jsx("path", { d: last ? barPathH(x0, barY, w, barH) : `M${x0},${barY} H${x0 + w} V${barY + barH} H${x0} Z`, fill: colors[i % colors.length] }), w > 54 && (_jsx("text", { x: x0 + 8, y: barY + barH / 2 + 4, fontSize: "11", fill: "#fff", className: "mono", children: ms(h.value) }))] }, h.key));
                    })] }), tip.node] }));
}
// ------------------------------------------------------------------ histogram
export function Histogram({ hist, p50, p95, p99, label, }) {
    const tip = useTooltip();
    if (!hist || hist.counts.length === 0)
        return _jsxs(Empty, { children: ["No distribution yet for ", label, "."] });
    const width = 900;
    const height = 210;
    const padL = 44;
    const padR = 12;
    const padT = 14;
    const padB = 30;
    const plotW = width - padL - padR;
    const plotH = height - padT - padB;
    const lo = hist.edges[0];
    const hi = hist.edges[hist.edges.length - 1];
    const maxCount = Math.max(...hist.counts, 1);
    const xOf = (v) => padL + ((v - lo) / (hi - lo || 1)) * plotW;
    const yOf = (c) => padT + plotH - (c / maxCount) * plotH;
    const bw = plotW / hist.counts.length;
    const yTicks = niceTicks(maxCount, 3);
    const marks = [
        ["P50", p50, "var(--ord-1)"],
        ["P95", p95, "var(--ord-2)"],
        ["P99", p99, "var(--ord-3)"],
    ];
    return (_jsxs(_Fragment, { children: [_jsxs("svg", { viewBox: `0 0 ${width} ${height}`, width: "100%", height: height, role: "img", children: [yTicks.map((t) => (_jsxs("g", { children: [_jsx("line", { x1: padL, x2: width - padR, y1: yOf(t), y2: yOf(t), stroke: "var(--grid)", strokeWidth: "1" }), _jsx("text", { x: padL - 8, y: yOf(t) + 3, fontSize: "10", fill: "var(--text-muted)", textAnchor: "end", children: t })] }, t))), hist.counts.map((c, i) => {
                        const x0 = padL + i * bw;
                        const h = plotH - (yOf(c) - padT);
                        if (c === 0)
                            return null;
                        return (_jsxs("g", { onMouseMove: (e) => tip.show(e, label, [
                                ["range", `${ms(hist.edges[i], 1)} – ${ms(hist.edges[i + 1], 1)}`],
                                ["events", num(c)],
                            ]), onMouseLeave: tip.hide, children: [_jsx("rect", { x: x0, y: padT, width: Math.max(1, bw), height: plotH, fill: "transparent" }), _jsx("path", { d: barPathH(x0 + 1, yOf(c), Math.max(1, bw - 2), h, 0), fill: "var(--ord-2)", opacity: "0.9" })] }, i));
                    }), marks.map(([name, v, color]) => v == null || !Number.isFinite(v) ? null : (_jsxs("g", { children: [_jsx("line", { x1: xOf(v), x2: xOf(v), y1: padT - 2, y2: padT + plotH, stroke: color, strokeWidth: "2", strokeDasharray: "4 3" }), _jsx("text", { x: xOf(v) + 4, y: padT + 9, fontSize: "10", fill: color, className: "mono", children: name })] }, name))), _jsx("line", { x1: padL, x2: width - padR, y1: padT + plotH, y2: padT + plotH, stroke: "var(--border-strong)", strokeWidth: "1" }), _jsx("text", { x: padL, y: height - 8, fontSize: "10", fill: "var(--text-muted)", children: ms(lo, 1) }), _jsx("text", { x: width - padR, y: height - 8, fontSize: "10", fill: "var(--text-muted)", textAnchor: "end", children: ms(hi, 1) })] }), tip.node] }));
}
// ----------------------------------------------------------------- throughput
export function Throughput({ series }) {
    const tip = useTooltip();
    if (series.length < 2)
        return _jsx(Empty, { children: "Waiting for the first seconds of traffic\u2026" });
    const width = 900;
    const height = 180;
    const padL = 40;
    const padR = 12;
    const padT = 12;
    const padB = 26;
    const plotW = width - padL - padR;
    const plotH = height - padT - padB;
    const t0 = series[0].t;
    const t1 = series[series.length - 1].t;
    const max = Math.max(...series.map((s) => s.sent), 1);
    const xOf = (t) => padL + ((t - t0) / Math.max(1, t1 - t0)) * plotW;
    const yOf = (v) => padT + plotH - (v / max) * plotH;
    const line = (pick) => series.map((s, i) => `${i ? "L" : "M"}${xOf(s.t)},${yOf(pick(s))}`).join(" ");
    const yTicks = niceTicks(max, 3);
    const anyFailed = series.some((s) => s.failed > 0);
    return (_jsxs(_Fragment, { children: [_jsxs("div", { className: "legend", style: { marginBottom: 6 }, children: [_jsxs("span", { className: "item", children: [_jsx("span", { className: "swatch", style: { background: "var(--series-1)" } }), "accepted / s"] }), _jsxs("span", { className: "item", children: [_jsx("span", { className: "swatch", style: { background: "var(--critical)" } }), _jsx("span", { "aria-hidden": true, children: "\u26A0" }), " failed / s"] })] }), _jsxs("svg", { viewBox: `0 0 ${width} ${height}`, width: "100%", height: height, role: "img", children: [yTicks.map((t) => (_jsxs("g", { children: [_jsx("line", { x1: padL, x2: width - padR, y1: yOf(t), y2: yOf(t), stroke: "var(--grid)", strokeWidth: "1" }), _jsx("text", { x: padL - 8, y: yOf(t) + 3, fontSize: "10", fill: "var(--text-muted)", textAnchor: "end", children: t })] }, t))), _jsx("path", { d: line((s) => s.sent), fill: "none", stroke: "var(--series-1)", strokeWidth: "2", strokeLinejoin: "round" }), anyFailed && (_jsx("path", { d: line((s) => s.failed), fill: "none", stroke: "var(--critical)", strokeWidth: "2", strokeLinejoin: "round" })), series.map((s, i) => (_jsx("g", { onMouseMove: (e) => tip.show(e, new Date(s.t * 1000).toLocaleTimeString(), [
                            ["accepted", `${s.sent - s.failed}/s`],
                            ["failed", `${s.failed}/s`],
                        ]), onMouseLeave: tip.hide, children: _jsx("rect", { x: xOf(s.t) - plotW / series.length / 2, y: padT, width: plotW / series.length, height: plotH, fill: "transparent" }) }, i))), _jsx("line", { x1: padL, x2: width - padR, y1: padT + plotH, y2: padT + plotH, stroke: "var(--border-strong)", strokeWidth: "1" }), _jsx("text", { x: padL, y: height - 8, fontSize: "10", fill: "var(--text-muted)", children: new Date(t0 * 1000).toLocaleTimeString() }), _jsx("text", { x: width - padR, y: height - 8, fontSize: "10", fill: "var(--text-muted)", textAnchor: "end", children: new Date(t1 * 1000).toLocaleTimeString() })] }), tip.node] }));
}
/** Did every event actually arrive? Anything narrowing downstream is loss. */
export function Funnel({ stages }) {
    const tip = useTooltip();
    if (stages.length === 0)
        return _jsx(Empty, { children: "No stage counts yet." });
    const top = Math.max(...stages.map((s) => s.count), 1);
    const width = 900;
    const rowH = 26;
    const height = stages.length * rowH + 8;
    const labelW = 320;
    const plotX = labelW + 12;
    const plotW = width - plotX - 96;
    return (_jsxs(_Fragment, { children: [_jsx("svg", { viewBox: `0 0 ${width} ${height}`, width: "100%", height: height, role: "img", children: stages.map((s, i) => {
                    const y = i * rowH + 4;
                    const w = (s.count / top) * plotW;
                    const shortfall = top - s.count;
                    return (_jsxs("g", { onMouseMove: (e) => tip.show(e, s.label, [
                            ["events", num(s.count)],
                            ["of accepted", `${((s.count / top) * 100).toFixed(2)}%`],
                            ["missing", num(shortfall)],
                        ]), onMouseLeave: tip.hide, children: [_jsx("rect", { x: plotX, y: y, width: plotW, height: rowH - 6, fill: "transparent" }), _jsx("text", { x: labelW, y: y + 13, fontSize: "12", fill: "var(--text-primary)", textAnchor: "end", children: s.label }), _jsx("path", { d: barPathH(plotX, y + 3, Math.max(0, w), 12), fill: i === 0 ? "var(--ord-2)" : "var(--ord-1)" }), _jsxs("text", { x: plotX + Math.max(0, w) + 8, y: y + 13, fontSize: "11", fill: "var(--text-secondary)", className: "mono", children: [num(s.count), i > 0 && shortfall > 0 ? ` (−${num(shortfall)})` : ""] })] }, s.key));
                }) }), tip.node] }));
}
