import { useMemo, useState } from "react";
import { api, type Discovery } from "../lib/api";
import { Banner, Card } from "../components/panels";

export function Targets({
  discovery,
  selected,
  probeTargetId,
  walletProbeTargetId,
  onDiscovered,
  onSelect,
  onProbe,
  onWalletProbe,
}: {
  discovery: Discovery | null;
  selected: Set<string>;
  probeTargetId: string | null;
  walletProbeTargetId: string | null;
  onDiscovered: (d: Discovery) => void;
  onSelect: (ids: Set<string>) => void;
  onProbe: (id: string | null) => void;
  onWalletProbe: (id: string | null) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const bySub = useMemo(() => {
    const m = new Map<string, Discovery["targets"]>();
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
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const toggle = (id: string, on: boolean) => {
    const next = new Set(selected);
    if (on) next.add(id);
    else next.delete(id);
    onSelect(next);
  };

  const toggleSub = (sub: string, on: boolean) => {
    const next = new Set(selected);
    for (const t of bySub.get(sub) ?? []) {
      if (on) next.add(t.id);
      else next.delete(t.id);
    }
    onSelect(next);
  };

  const walletTarget = discovery?.targets.find((t) => t.id === walletProbeTargetId);
  const probeSub = discovery?.targets.find((t) => t.id === probeTargetId);
  const shared =
    probeSub &&
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
  const walletAligned = Boolean(
    walletTarget &&
      walletProbeFeeds &&
      walletFeeds.every(
        (t) =>
          t &&
          t.subscriptionExternalId === probeSub!.subscriptionExternalId &&
          t.metricCode === probeSub!.metricCode,
      ),
  );
  const walletPriceable = Boolean(
    walletTarget &&
      [...walletFeeds, ...(walletProbeFeeds ? [probeSub] : [])].every((t) => t && t.chargeModel === "standard"),
  );
  const walletMode = !walletTarget
    ? "off"
    : walletFeeds.length === 0 && !walletProbeFeeds
      ? "no traffic"
      : walletAligned && !shared
        ? "exact"
        : walletPriceable
          ? "watermark"
          : "refresh";

  return (
    <>
      {err && <Banner kind="bad">{err}</Banner>}

      <Card
        title="Discover targets"
        hint="reads subscriptions → plan → charges → billable metrics from the Lago API"
        right={
          <button className="btn primary" onClick={run} disabled={busy}>
            {busy ? "Scanning…" : discovery ? "Rescan" : "Scan Lago"}
          </button>
        }
      >
        {!discovery && <p style={{ color: "var(--text-secondary)" }}>Scan to list what this instance can be load-tested against.</p>}
        {discovery && (
          <p style={{ color: "var(--text-secondary)", fontSize: 13 }}>
            {discovery.subscriptions.length} active subscription(s), {discovery.targets.length} chargeable metric target(s),
            scanned {new Date(discovery.scannedAt).toLocaleTimeString()}. Only active subscriptions whose plan actually
            charges for a metric are offered — an event for an uncharged metric never reaches the expanded stage, so its
            latency could not be measured past stage 0.
          </p>
        )}
        {discovery?.warnings.map((w) => (
          <div key={w} style={{ marginTop: 8 }}>
            <Banner kind="warn">{w}</Banner>
          </div>
        ))}
      </Card>

      {discovery && discovery.targets.length > 0 && (
        <Card
          title="Bulk load targets"
          hint={`${selected.size} selected — events are spread round-robin across them`}
          right={
            <div className="row">
              <button className="btn" onClick={() => onSelect(new Set(discovery.targets.map((t) => t.id)))}>
                Select all
              </button>
              <button className="btn" onClick={() => onSelect(new Set())}>
                Clear
              </button>
            </div>
          }
        >
          <div className="targets">
            {[...bySub.entries()].map(([sub, list]) => {
              const first = list[0]!;
              const allOn = list.every((t) => selected.has(t.id));
              return (
                <div className="sub-block" key={sub}>
                  <div className="head">
                    <input type="checkbox" checked={allOn} onChange={(e) => toggleSub(sub, e.target.checked)} />
                    <b>{sub}</b>
                    <span style={{ color: "var(--text-muted)", fontSize: 12 }}>
                      customer {first.customerExternalId} · plan {first.planCode}
                      {first.subscriptionName ? ` · ${first.subscriptionName}` : ""}
                    </span>
                  </div>
                  <div className="metrics">
                    {list.map((t) => (
                      <div className="metric-row" key={t.id}>
                        <input type="checkbox" checked={selected.has(t.id)} onChange={(e) => toggle(t.id, e.target.checked)} />
                        <span className="mono">{t.metricCode}</span>
                        <span className="agg">
                          {t.aggregationType}
                          {t.fieldName ? `(${t.fieldName})` : ""} · {t.chargeModel}
                        </span>
                        {t.filters.length > 0 && (
                          <span
                            className="filter"
                            title={t.filters
                              .map((f, i) => `#${i + 1} ${Object.entries(f.values).map(([k, v]) => `${k}=[${v.join("|")}]`).join(", ")}`)
                              .join("\n")}
                          >
                            {t.filters.length} filter{t.filters.length > 1 ? "s" : ""}
                          </span>
                        )}
                        {t.groupKeys.length > 0 && (
                          <span className="filter" title="pricing group keys — each distinct value becomes its own usage row">
                            grouped by {t.groupKeys.join(", ")}
                          </span>
                        )}
                        {!t.servedByRealtimeBuckets && (
                          <span className="pill" style={{ fontSize: 11 }} title="only count and sum recompose across 15-minute buckets">
                            <span className="dot warn" /> not bucket-served
                          </span>
                        )}
                        {t.wallets.length > 0 && (
                          <span
                            className="pill"
                            style={{ fontSize: 11 }}
                            title={t.wallets
                              .map(
                                (w) =>
                                  `${w.code ?? w.name ?? "wallet"} · ${w.currency} · balance ${w.balanceCents} cents` +
                                  (w.metricCodes.length ? ` · limited to ${w.metricCodes.join(", ")}` : ""),
                              )
                              .join("\n")}
                          >
                            <span className="dot ok" /> {t.wallets.length} wallet{t.wallets.length > 1 ? "s" : ""}
                          </span>
                        )}
                        <div style={{ flex: 1 }} />
                        <label className="row" style={{ fontSize: 11, color: "var(--text-muted)", gap: 5 }}>
                          <input
                            type="radio"
                            name="probe"
                            checked={probeTargetId === t.id}
                            onChange={() => onProbe(t.id)}
                          />
                          usage probe
                        </label>
                        <label
                          className="row"
                          style={{
                            fontSize: 11,
                            color: t.wallets.length ? "var(--text-muted)" : "var(--text-disabled, var(--text-muted))",
                            gap: 5,
                            opacity: t.wallets.length ? 1 : 0.45,
                          }}
                          title={
                            t.wallets.length
                              ? "poll this customer's wallets and time the ongoing balance against each event"
                              : "this customer holds no active wallet, so there is no ongoing balance to watch"
                          }
                        >
                          <input
                            type="radio"
                            name="walletProbe"
                            disabled={t.wallets.length === 0}
                            checked={walletProbeTargetId === t.id}
                            onChange={() => onWalletProbe(t.id)}
                          />
                          wallet probe
                        </label>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      )}

      {discovery && (
        <Card title="Usage probe" hint="the one target whose current_usage is polled per event">
          {!probeTargetId ? (
            <Banner kind="warn">
              No probe target selected — the run will measure every pipeline stage but <b>not</b> "reflected in the
              customer's current usage". Pick one with the radio button beside a metric above.
            </Banner>
          ) : shared ? (
            <Banner kind="info">
              <b>Watermark mode.</b> <b className="mono">{probeSub?.subscriptionExternalId}/{probeSub?.metricCode}</b> also
              carries bulk traffic — normal when an instance has a single subscription and metric. Every accepted event for
              that pair is recorded in send order, and when <code>events_count</code> reaches k the crossing is attributed
              to the k-th event. All traffic to the pair is this app's, so k is exact; only the crossing-to-event pairing
              assumes in-order delivery, so treat the tail as indicative rather than per-event truth. Every event gets a
              sample, not just a sampled probe.
              <br />
              <span style={{ color: "var(--text-muted)" }}>
                For per-event exactness instead, untick this metric from the bulk set — the probe then runs one event at a
                time and each crossing is unambiguous.
              </span>
            </Banner>
          ) : (
            <Banner kind="info">
              <b>Exact mode.</b> Probing <b className="mono">{probeSub?.subscriptionExternalId}/{probeSub?.metricCode}</b>,
              which carries no bulk traffic. One probe event is in flight at a time: send → poll{" "}
              <code>GET /current_usage</code> until <code>events_count</code> reaches the expected value → send the next.
              Each measurement is attributable to a single event, and it runs <em>under</em> the bulk load rather than
              instead of it.
            </Banner>
          )}
        </Card>
      )}

      {discovery && (
        <Card
          title="Wallet probe"
          hint="the one customer whose wallet ongoing balance is polled per event"
          right={
            walletProbeTargetId ? (
              <button className="btn" onClick={() => onWalletProbe(null)}>
                Clear
              </button>
            ) : undefined
          }
        >
          {discovery.wallets.length === 0 ? (
            <Banner kind="info">
              This instance has no active wallet, so there is no ongoing balance to measure. Create a wallet for a
              customer that has a chargeable subscription and rescan.
            </Banner>
          ) : !walletProbeTargetId ? (
            <Banner kind="warn">
              No wallet probe selected — the run will measure current usage but <b>not</b> "reflected in the customer's
              wallet ongoing balance". {discovery.wallets.length} active wallet(s) exist; pick a metric belonging to one
              of their customers with the <b>wallet probe</b> radio above.
            </Banner>
          ) : walletMode === "no traffic" ? (
            <Banner kind="bad">
              Nothing in this run sends events to <b className="mono">{walletTarget?.customerExternalId}</b>, so its
              wallet cannot move. Tick a bulk target for that customer, or point the usage probe at it.
            </Banner>
          ) : (
            <>
              <Banner kind="info">
                {walletMode === "exact" ? (
                  <>
                    <b>Exact mode.</b> <b className="mono">{walletTarget?.customerExternalId}</b> receives only the
                    serial usage probe, so exactly one event is outstanding at a time and the n-th increase of{" "}
                    <code>ongoing_usage_balance_cents</code> <em>is</em> the n-th event. No price and no arithmetic are
                    involved, so this holds for any charge model.
                  </>
                ) : walletMode === "watermark" ? (
                  <>
                    <b>Watermark mode.</b> <b className="mono">{walletTarget?.customerExternalId}</b> also carries bulk
                    traffic, and every shape sent to it is a <code>standard</code> charge — linear in units — so the run
                    can predict the exact cents the balance must reach after k events, the same way the usage watermark
                    predicts units. Preflight calibrates that prediction against one real event, which absorbs taxes, the
                    currency subunit and the wallet's rate without modelling any of them.
                  </>
                ) : (
                  <>
                    <b>Refresh mode.</b> <b className="mono">{walletTarget?.customerExternalId}</b> carries bulk traffic
                    and at least one shape is not a <code>standard</code> charge, so per-event cents are not predictable.
                    Each observed refresh is timed against the oldest outstanding event instead — an <b>upper bound</b>,
                    because a refresh covers every event whose bucket had already landed and the ones behind it are
                    charged to the next refresh. For per-event truth, point both probes at the same standard charge.
                  </>
                )}
              </Banner>
              {walletAligned ? (
                <p style={{ marginTop: 10, fontSize: 12, color: "var(--text-secondary)" }}>
                  Both probes point at the same target, so the run also reports{" "}
                  <b>current usage → wallet caught up</b> per event: what the trigger, the Kafka hop, the consumer's
                  bucket wait and the refresh cost <em>on top of</em> usage already being fresh.
                </p>
              ) : (
                <p style={{ marginTop: 10, fontSize: 12, color: "var(--text-muted)" }}>
                  The usage probe and the wallet probe cover different traffic, so the per-event{" "}
                  <b>current usage → wallet</b> split is not measurable in this run — only the two distributions side by
                  side. Point the usage probe at this same target to get it.
                </p>
              )}
              {walletTarget && walletTarget.wallets.some((w) => w.metricCodes.length > 0) && (
                <div style={{ marginTop: 10 }}>
                  <Banner kind="warn">
                    Some of this customer's wallets are restricted to specific billable metrics
                    {walletTarget.wallets.some((w) => w.metricCodes.length > 0 && !w.metricCodes.includes(walletTarget.metricCode))
                      ? ` and at least one excludes ${walletTarget.metricCode}`
                      : ""}
                    . A restricted wallet receives no allocation for a metric it does not list, so its ongoing balance
                    will not move for these events.
                  </Banner>
                </div>
              )}
              {!walletTarget?.wallets.some((w) => w.exposesSyncStamp) && (
                <p style={{ marginTop: 8, fontSize: 12, color: "var(--text-muted)" }}>
                  This Lago does not serialize <code>last_ongoing_balance_sync_at</code>, so refreshes are counted from
                  amount changes only — a refresh that recomputed the same number is invisible and the coalescing factor
                  is a lower bound.
                </p>
              )}
            </>
          )}
        </Card>
      )}
    </>
  );
}
