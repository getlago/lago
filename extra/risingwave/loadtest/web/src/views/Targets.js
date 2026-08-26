import { jsx as _jsx, jsxs as _jsxs, Fragment as _Fragment } from "react/jsx-runtime";
import { useMemo, useState } from "react";
import { api } from "../lib/api";
import { Banner, Card } from "../components/panels";
export function Targets({ discovery, selected, probeTargetId, walletProbeTargetId, onDiscovered, onSelect, onProbe, onWalletProbe, }) {
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState(null);
    const bySub = useMemo(() => {
        const m = new Map();
        for (const t of discovery?.targets ?? []) {
            const list = m.get(t.subscriptionExternalId) ?? [];
            list.push(t);
            m.set(t.subscriptionExternalId, list);
        }
        return m;
    }, [discovery]);
    const run = async () => {
        setBusy(true);
        setErr(null);
        try {
            onDiscovered(await api.discover());
        }
        catch (e) {
            setErr(e.message);
        }
        finally {
            setBusy(false);
        }
    };
    const toggle = (id, on) => {
        const next = new Set(selected);
        if (on)
            next.add(id);
        else
            next.delete(id);
        onSelect(next);
    };
    const toggleSub = (sub, on) => {
        const next = new Set(selected);
        for (const t of bySub.get(sub) ?? []) {
            if (on)
                next.add(t.id);
            else
                next.delete(t.id);
        }
        onSelect(next);
    };
    const walletTarget = discovery?.targets.find((t) => t.id === walletProbeTargetId);
    const probeSub = discovery?.targets.find((t) => t.id === probeTargetId);
    const shared = probeSub &&
        [...selected]
            .map((id) => discovery?.targets.find((t) => t.id === id))
            .some((t) => t && t.subscriptionExternalId === probeSub.subscriptionExternalId && t.metricCode === probeSub.metricCode);
    // What can actually move this wallet: every selected target for its customer,
    // plus the usage probe if it points at the same customer.
    const walletFeeds = walletTarget
        ? [...selected]
            .map((id) => discovery?.targets.find((t) => t.id === id))
            .filter((t) => t && t.customerExternalId === walletTarget.customerExternalId)
        : [];
    const walletProbeFeeds = Boolean(walletTarget && probeSub?.customerExternalId === walletTarget.customerExternalId);
    const walletAligned = Boolean(walletTarget &&
        walletProbeFeeds &&
        walletFeeds.every((t) => t &&
            t.subscriptionExternalId === probeSub.subscriptionExternalId &&
            t.metricCode === probeSub.metricCode));
    const walletPriceable = Boolean(walletTarget &&
        [...walletFeeds, ...(walletProbeFeeds ? [probeSub] : [])].every((t) => t && t.chargeModel === "standard"));
    const walletMode = !walletTarget
        ? "off"
        : walletFeeds.length === 0 && !walletProbeFeeds
            ? "no traffic"
            : walletAligned && !shared
                ? "exact"
                : walletPriceable
                    ? "watermark"
                    : "refresh";
    return (_jsxs(_Fragment, { children: [err && _jsx(Banner, { kind: "bad", children: err }), _jsxs(Card, { title: "Discover targets", hint: "reads subscriptions \u2192 plan \u2192 charges \u2192 billable metrics from the Lago API", right: _jsx("button", { className: "btn primary", onClick: run, disabled: busy, children: busy ? "Scanning…" : discovery ? "Rescan" : "Scan Lago" }), children: [!discovery && _jsx("p", { style: { color: "var(--text-secondary)" }, children: "Scan to list what this instance can be load-tested against." }), discovery && (_jsxs("p", { style: { color: "var(--text-secondary)", fontSize: 13 }, children: [discovery.subscriptions.length, " active subscription(s), ", discovery.targets.length, " chargeable metric target(s), scanned ", new Date(discovery.scannedAt).toLocaleTimeString(), ". Only active subscriptions whose plan actually charges for a metric are offered \u2014 an event for an uncharged metric never reaches the expanded stage, so its latency could not be measured past stage 0."] })), discovery?.warnings.map((w) => (_jsx("div", { style: { marginTop: 8 }, children: _jsx(Banner, { kind: "warn", children: w }) }, w)))] }), discovery && discovery.targets.length > 0 && (_jsx(Card, { title: "Bulk load targets", hint: `${selected.size} selected — events are spread round-robin across them`, right: _jsxs("div", { className: "row", children: [_jsx("button", { className: "btn", onClick: () => onSelect(new Set(discovery.targets.map((t) => t.id))), children: "Select all" }), _jsx("button", { className: "btn", onClick: () => onSelect(new Set()), children: "Clear" })] }), children: _jsx("div", { className: "targets", children: [...bySub.entries()].map(([sub, list]) => {
                        const first = list[0];
                        const allOn = list.every((t) => selected.has(t.id));
                        return (_jsxs("div", { className: "sub-block", children: [_jsxs("div", { className: "head", children: [_jsx("input", { type: "checkbox", checked: allOn, onChange: (e) => toggleSub(sub, e.target.checked) }), _jsx("b", { children: sub }), _jsxs("span", { style: { color: "var(--text-muted)", fontSize: 12 }, children: ["customer ", first.customerExternalId, " \u00B7 plan ", first.planCode, first.subscriptionName ? ` · ${first.subscriptionName}` : ""] })] }), _jsx("div", { className: "metrics", children: list.map((t) => (_jsxs("div", { className: "metric-row", children: [_jsx("input", { type: "checkbox", checked: selected.has(t.id), onChange: (e) => toggle(t.id, e.target.checked) }), _jsx("span", { className: "mono", children: t.metricCode }), _jsxs("span", { className: "agg", children: [t.aggregationType, t.fieldName ? `(${t.fieldName})` : "", " \u00B7 ", t.chargeModel] }), t.filters.length > 0 && (_jsxs("span", { className: "filter", title: t.filters
                                                    .map((f, i) => `#${i + 1} ${Object.entries(f.values).map(([k, v]) => `${k}=[${v.join("|")}]`).join(", ")}`)
                                                    .join("\n"), children: [t.filters.length, " filter", t.filters.length > 1 ? "s" : ""] })), t.groupKeys.length > 0 && (_jsxs("span", { className: "filter", title: "pricing group keys \u2014 each distinct value becomes its own usage row", children: ["grouped by ", t.groupKeys.join(", ")] })), !t.servedByRealtimeBuckets && (_jsxs("span", { className: "pill", style: { fontSize: 11 }, title: "only count and sum recompose across 15-minute buckets", children: [_jsx("span", { className: "dot warn" }), " not bucket-served"] })), t.wallets.length > 0 && (_jsxs("span", { className: "pill", style: { fontSize: 11 }, title: t.wallets
                                                    .map((w) => `${w.code ?? w.name ?? "wallet"} · ${w.currency} · balance ${w.balanceCents} cents` +
                                                    (w.metricCodes.length ? ` · limited to ${w.metricCodes.join(", ")}` : ""))
                                                    .join("\n"), children: [_jsx("span", { className: "dot ok" }), " ", t.wallets.length, " wallet", t.wallets.length > 1 ? "s" : ""] })), _jsx("div", { style: { flex: 1 } }), _jsxs("label", { className: "row", style: { fontSize: 11, color: "var(--text-muted)", gap: 5 }, children: [_jsx("input", { type: "radio", name: "probe", checked: probeTargetId === t.id, onChange: () => onProbe(t.id) }), "usage probe"] }), _jsxs("label", { className: "row", style: {
                                                    fontSize: 11,
                                                    color: t.wallets.length ? "var(--text-muted)" : "var(--text-disabled, var(--text-muted))",
                                                    gap: 5,
                                                    opacity: t.wallets.length ? 1 : 0.45,
                                                }, title: t.wallets.length
                                                    ? "poll this customer's wallets and time the ongoing balance against each event"
                                                    : "this customer holds no active wallet, so there is no ongoing balance to watch", children: [_jsx("input", { type: "radio", name: "walletProbe", disabled: t.wallets.length === 0, checked: walletProbeTargetId === t.id, onChange: () => onWalletProbe(t.id) }), "wallet probe"] })] }, t.id))) })] }, sub));
                    }) }) })), discovery && (_jsx(Card, { title: "Usage probe", hint: "the one target whose current_usage is polled per event", children: !probeTargetId ? (_jsxs(Banner, { kind: "warn", children: ["No probe target selected \u2014 the run will measure every pipeline stage but ", _jsx("b", { children: "not" }), " \"reflected in the customer's current usage\". Pick one with the radio button beside a metric above."] })) : shared ? (_jsxs(Banner, { kind: "info", children: [_jsx("b", { children: "Watermark mode." }), " ", _jsxs("b", { className: "mono", children: [probeSub?.subscriptionExternalId, "/", probeSub?.metricCode] }), " also carries bulk traffic \u2014 normal when an instance has a single subscription and metric. Every accepted event for that pair is recorded in send order, and when ", _jsx("code", { children: "events_count" }), " reaches k the crossing is attributed to the k-th event. All traffic to the pair is this app's, so k is exact; only the crossing-to-event pairing assumes in-order delivery, so treat the tail as indicative rather than per-event truth. Every event gets a sample, not just a sampled probe.", _jsx("br", {}), _jsx("span", { style: { color: "var(--text-muted)" }, children: "For per-event exactness instead, untick this metric from the bulk set \u2014 the probe then runs one event at a time and each crossing is unambiguous." })] })) : (_jsxs(Banner, { kind: "info", children: [_jsx("b", { children: "Exact mode." }), " Probing ", _jsxs("b", { className: "mono", children: [probeSub?.subscriptionExternalId, "/", probeSub?.metricCode] }), ", which carries no bulk traffic. One probe event is in flight at a time: send \u2192 poll", " ", _jsx("code", { children: "GET /current_usage" }), " until ", _jsx("code", { children: "events_count" }), " reaches the expected value \u2192 send the next. Each measurement is attributable to a single event, and it runs ", _jsx("em", { children: "under" }), " the bulk load rather than instead of it."] })) })), discovery && (_jsx(Card, { title: "Wallet probe", hint: "the one customer whose wallet ongoing balance is polled per event", right: walletProbeTargetId ? (_jsx("button", { className: "btn", onClick: () => onWalletProbe(null), children: "Clear" })) : undefined, children: discovery.wallets.length === 0 ? (_jsx(Banner, { kind: "info", children: "This instance has no active wallet, so there is no ongoing balance to measure. Create a wallet for a customer that has a chargeable subscription and rescan." })) : !walletProbeTargetId ? (_jsxs(Banner, { kind: "warn", children: ["No wallet probe selected \u2014 the run will measure current usage but ", _jsx("b", { children: "not" }), " \"reflected in the customer's wallet ongoing balance\". ", discovery.wallets.length, " active wallet(s) exist; pick a metric belonging to one of their customers with the ", _jsx("b", { children: "wallet probe" }), " radio above."] })) : walletMode === "no traffic" ? (_jsxs(Banner, { kind: "bad", children: ["Nothing in this run sends events to ", _jsx("b", { className: "mono", children: walletTarget?.customerExternalId }), ", so its wallet cannot move. Tick a bulk target for that customer, or point the usage probe at it."] })) : (_jsxs(_Fragment, { children: [_jsx(Banner, { kind: "info", children: walletMode === "exact" ? (_jsxs(_Fragment, { children: [_jsx("b", { children: "Exact mode." }), " ", _jsx("b", { className: "mono", children: walletTarget?.customerExternalId }), " receives only the serial usage probe, so exactly one event is outstanding at a time and the n-th increase of", " ", _jsx("code", { children: "ongoing_usage_balance_cents" }), " ", _jsx("em", { children: "is" }), " the n-th event. No price and no arithmetic are involved, so this holds for any charge model."] })) : walletMode === "watermark" ? (_jsxs(_Fragment, { children: [_jsx("b", { children: "Watermark mode." }), " ", _jsx("b", { className: "mono", children: walletTarget?.customerExternalId }), " also carries bulk traffic, and every shape sent to it is a ", _jsx("code", { children: "standard" }), " charge \u2014 linear in units \u2014 so the run can predict the exact cents the balance must reach after k events, the same way the usage watermark predicts units. Preflight calibrates that prediction against one real event, which absorbs taxes, the currency subunit and the wallet's rate without modelling any of them."] })) : (_jsxs(_Fragment, { children: [_jsx("b", { children: "Refresh mode." }), " ", _jsx("b", { className: "mono", children: walletTarget?.customerExternalId }), " carries bulk traffic and at least one shape is not a ", _jsx("code", { children: "standard" }), " charge, so per-event cents are not predictable. Each observed refresh is timed against the oldest outstanding event instead \u2014 an ", _jsx("b", { children: "upper bound" }), ", because a refresh covers every event whose bucket had already landed and the ones behind it are charged to the next refresh. For per-event truth, point both probes at the same standard charge."] })) }), walletAligned ? (_jsxs("p", { style: { marginTop: 10, fontSize: 12, color: "var(--text-secondary)" }, children: ["Both probes point at the same target, so the run also reports", " ", _jsx("b", { children: "current usage \u2192 wallet caught up" }), " per event: what the trigger, the Kafka hop, the consumer's bucket wait and the refresh cost ", _jsx("em", { children: "on top of" }), " usage already being fresh."] })) : (_jsxs("p", { style: { marginTop: 10, fontSize: 12, color: "var(--text-muted)" }, children: ["The usage probe and the wallet probe cover different traffic, so the per-event", " ", _jsx("b", { children: "current usage \u2192 wallet" }), " split is not measurable in this run \u2014 only the two distributions side by side. Point the usage probe at this same target to get it."] })), walletTarget && walletTarget.wallets.some((w) => w.metricCodes.length > 0) && (_jsx("div", { style: { marginTop: 10 }, children: _jsxs(Banner, { kind: "warn", children: ["Some of this customer's wallets are restricted to specific billable metrics", walletTarget.wallets.some((w) => w.metricCodes.length > 0 && !w.metricCodes.includes(walletTarget.metricCode))
                                        ? ` and at least one excludes ${walletTarget.metricCode}`
                                        : "", ". A restricted wallet receives no allocation for a metric it does not list, so its ongoing balance will not move for these events."] }) })), !walletTarget?.wallets.some((w) => w.exposesSyncStamp) && (_jsxs("p", { style: { marginTop: 8, fontSize: 12, color: "var(--text-muted)" }, children: ["This Lago does not serialize ", _jsx("code", { children: "last_ongoing_balance_sync_at" }), ", so refreshes are counted from amount changes only \u2014 a refresh that recomputed the same number is invisible and the coalescing factor is a lower bound."] }))] })) }))] }));
}
