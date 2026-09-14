import { jsx as _jsx, jsxs as _jsxs, Fragment as _Fragment } from "react/jsx-runtime";
import { useEffect, useRef, useState } from "react";
import { api, num } from "../lib/api";
import { Banner, Card, LogPanel } from "../components/panels";
/**
 * Seeds a fixture matrix through the Lago API — many billable metrics (with
 * filters), many plans (with charges and charge filters), many customers each
 * holding an active subscription — so a run fans out across the pipeline's
 * hash-distributed joins instead of landing on one actor per lookup.
 *
 * The form only decides the widths; the shapes (which metric kinds, which
 * filters) are fixed on the server so every seeded instance looks the same.
 */
export function SeedCard({ spec, setSpec, onSeeded, maxVariantsPerTarget, }) {
    const [open, setOpen] = useState(false);
    const [limits, setLimits] = useState(null);
    const [preview, setPreview] = useState(null);
    const [status, setStatus] = useState(null);
    const [err, setErr] = useState(null);
    const [rescanning, setRescanning] = useState(false);
    const seenDone = useRef(null);
    // Defaults come from the server so the form and the seeder cannot disagree,
    // and a job already running (another tab, or before a reload) is picked up.
    useEffect(() => {
        api
            .seedStatus()
            .then((r) => {
            setLimits(r.limits);
            setStatus(r.status);
            if (!spec)
                setSpec(r.status.spec ?? r.defaults);
            if (r.status.phase === "running")
                setOpen(true);
        })
            .catch((e) => setErr(e.message));
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);
    // Preview what the current widths would create, debounced.
    useEffect(() => {
        if (!spec)
            return;
        const t = setTimeout(() => {
            api.seedPreview(spec).then(setPreview).catch(() => setPreview(null));
        }, 250);
        return () => clearTimeout(t);
    }, [spec]);
    // Poll while running; rescan once when it finishes so the new targets appear.
    const running = status?.phase === "running";
    useEffect(() => {
        if (!running)
            return;
        const t = setInterval(() => {
            api
                .seedStatus()
                .then((r) => setStatus(r.status))
                .catch(() => { });
        }, 700);
        return () => clearInterval(t);
    }, [running]);
    useEffect(() => {
        if (!status || status.phase === "running" || status.phase === "idle")
            return;
        if (status.endedAt && seenDone.current !== status.endedAt) {
            seenDone.current = status.endedAt;
            // Only rescan for a job that ended during this page's lifetime, not one
            // found already finished on mount.
            if (Date.now() - status.endedAt < 60_000) {
                setRescanning(true);
                onSeeded().finally(() => setRescanning(false));
            }
        }
    }, [status, onSeeded]);
    const start = async () => {
        if (!spec)
            return;
        setErr(null);
        try {
            const r = await api.seed(spec);
            setStatus(r.status);
        }
        catch (e) {
            setErr(e.message);
        }
    };
    const field = (key, label, note) => spec && (_jsxs("label", { className: "field", children: [label, _jsx("input", { type: "number", min: 1, max: limits?.[key] ?? undefined, value: spec[key], disabled: running, onChange: (e) => setSpec({ ...spec, [key]: Number(e.target.value) }) }), _jsx("span", { className: "note", children: note })] }));
    return (_jsxs(Card, { title: "Seed fixtures", hint: "create many metrics, plans, charges and subscriptions through the Lago API so the load fans out", right: _jsx("button", { className: "btn", onClick: () => setOpen((o) => !o), children: open ? "Hide" : "Show" }), children: [!open && (_jsxs("p", { style: { color: "var(--text-secondary)", fontSize: 13, margin: 0 }, children: ["Every lookup in the pipeline is a temporal join, and a temporal join hashes the event stream on its key: one subscription and one metric code keep one actor busy whatever the cluster's parallelism. Seeding widens the key sets \u2014 metric codes for stage 0, (plan, code) pairs and subscriptions for stage 1 \u2014 so the ceiling a run finds is the pipeline's and not one core's. It also plants AI-company charges with dozens of filters each (one per model \u00D7 token type), so filter matching is scored against a realistic candidate set rather than two values.", status?.phase === "done" && status.matrix
                        ? ` Last seed: ${num(status.matrix.targets)} targets under "${status.spec?.prefix}".`
                        : ""] })), open && spec && (_jsxs(_Fragment, { children: [err && _jsx(Banner, { kind: "bad", children: err }), _jsxs("div", { className: "grid cols-4", style: { marginTop: err ? 10 : 0 }, children: [_jsxs("label", { className: "field", children: ["prefix", _jsx("input", { type: "text", value: spec.prefix, disabled: running, onChange: (e) => setSpec({ ...spec, prefix: e.target.value }) }), _jsx("span", { className: "note", children: "every code and external id starts with it; the seed is idempotent per prefix" })] }), field("billableMetrics", "billable metrics", "distinct codes = stage-0 keys (billable_metrics join). Kinds rotate: count, count+filters, sum+filters, sum grouped by region"), field("plans", "plans", "each subscribes 1/N of the customers"), field("chargesPerPlan", "charges per plan", "a window of metrics per plan; plans × charges = stage-1 (plan, code) keys (flat_filters_agg join)"), field("subscriptions", "customers + subscriptions", "one active subscription per customer; distinct external ids = stage-1 subscription keys AND the API's Kafka partition keys"), field("wideFilters", "charge filters per wide charge", "the AI-company shape: one charge filter per model × token type (input, output, cached_input) on every 'sum many filters' charge — the size of the candidate array matching_filter() scores each event against"), _jsxs("label", { className: "field", children: ["currency", _jsx("input", { type: "text", value: spec.currency, disabled: running, style: { width: 80 }, onChange: (e) => setSpec({ ...spec, currency: e.target.value }) }), _jsx("span", { className: "note", children: "plans and customers" })] })] }), preview && (_jsx("div", { style: { marginTop: 12 }, children: _jsxs(Banner, { kind: "info", children: [_jsx("b", { children: num(preview.metrics) }), " metric codes (", Object.entries(preview.kinds)
                                    .map(([k, n]) => `${n} ${k.replace("_", " ")}`)
                                    .join(", "), ") \u00B7 ", _jsx("b", { children: num(preview.plans) }), " plans \u00D7 ", num(preview.spec.chargesPerPlan), " charges =", " ", _jsx("b", { children: num(preview.planCodePairs) }), " (plan, code) pairs carrying ", _jsx("b", { children: num(preview.chargeFilters) }), " charge filters \u00B7 ", _jsx("b", { children: num(preview.subscriptions) }), " subscriptions \u2192 ", _jsx("b", { children: num(preview.targets) }), " targets after a rescan. Filtered metrics get charge filters on ", _jsx("code", { children: "tier=gold" }), " and ", _jsx("code", { children: "tier=silver" }), ", leaving", " ", _jsx("code", { children: "bronze" }), " for the default bucket; grouped ones price by ", _jsx("code", { children: "region" }), "; the wide ones carry", " ", num(preview.spec.wideFilters), " filters each, one per ", _jsx("code", { children: "model" }), " \u00D7 ", _jsx("code", { children: "token_type" }), ", with one extra model declared but unpriced so it lands in the default bucket. All charges are standard at an integer price per unit, so a wallet stays priceable. About ", num(preview.apiCalls), " API calls, 8 in flight.", _jsx("br", {}), _jsx("span", { style: { color: "var(--text-muted)" }, children: "Sizing rule: hashing K keys over P actors only evens out when K is several times P. The defaults give a 16-actor fragment 2\u00D7 its actors in codes, 6\u00D7 in (plan, code) pairs and 8\u00D7 in subscriptions \u2014 the subscription join being the hot fragment. Shrink one dimension on purpose to watch that fragment become the bottleneck." })] }) })), preview && maxVariantsPerTarget != null && maxVariantsPerTarget <= preview.maxFiltersPerCharge && (_jsx("div", { style: { marginTop: 10 }, children: _jsxs(Banner, { kind: "warn", children: ["The run's ", _jsx("b", { children: "max shapes per target" }), " is ", num(maxVariantsPerTarget), ", but a wide charge has", " ", num(preview.maxFiltersPerCharge), " filters plus the default bucket: the run would send only the first", " ", num(maxVariantsPerTarget), " shapes and never exercise the rest. Raise it above", " ", num(preview.maxFiltersPerCharge), " on the Run tab (the default is ", num(preview.defaultMaxVariantsPerTarget), ")."] }) })), _jsxs("div", { className: "row", style: { marginTop: 12 }, children: [_jsx("button", { className: "btn primary", onClick: start, disabled: running || !preview, children: running ? "Seeding…" : "Seed" }), rescanning && _jsx("span", { style: { color: "var(--text-muted)", fontSize: 12 }, children: "rescanning Lago\u2026" }), status?.phase === "done" && !running && (_jsxs("span", { className: "pill", children: [_jsx("span", { className: "dot ok" }), " done in ", status.endedAt && status.startedAt ? Math.round((status.endedAt - status.startedAt) / 100) / 10 : "?", "s"] })), status?.phase === "failed" && (_jsxs("span", { className: "pill", children: [_jsx("span", { className: "dot bad" }), " ", status.error] }))] }), status && status.phase !== "idle" && (_jsxs("div", { style: { marginTop: 12 }, children: [_jsx("div", { className: "scroll", children: _jsxs("table", { className: "data", children: [_jsx("thead", { children: _jsxs("tr", { children: [_jsx("th", { children: "Step" }), _jsx("th", { children: "Total" }), _jsx("th", { children: "Created" }), _jsx("th", { children: "Existing" }), _jsx("th", { children: "Failed" })] }) }), _jsx("tbody", { children: [
                                                ["metrics", "billable metrics"],
                                                ["plans", "plans (with charges and charge filters)"],
                                                ["customers", "customers"],
                                                ["subscriptions", "subscriptions"],
                                            ].map(([k, label]) => {
                                                const c = status.steps[k];
                                                return (_jsxs("tr", { children: [_jsx("td", { children: label }), _jsx("td", { className: "num", children: num(c.total) }), _jsx("td", { className: "num", children: num(c.created) }), _jsx("td", { className: "num", children: num(c.existing) }), _jsx("td", { className: "num", style: c.failed ? { color: "var(--critical)" } : undefined, children: num(c.failed) })] }, k));
                                            }) })] }) }), _jsx("div", { style: { marginTop: 10 }, children: _jsx(LogPanel, { logs: status.log }) })] }))] }))] }));
}
