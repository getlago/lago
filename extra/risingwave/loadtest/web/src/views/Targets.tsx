import { useMemo, useState } from "react";
import { api, type Discovery } from "../lib/api";
import { Banner, Card } from "../components/panels";

export function Targets({
  discovery,
  selected,
  probeTargetId,
  onDiscovered,
  onSelect,
  onProbe,
}: {
  discovery: Discovery | null;
  selected: Set<string>;
  probeTargetId: string | null;
  onDiscovered: (d: Discovery) => void;
  onSelect: (ids: Set<string>) => void;
  onProbe: (id: string | null) => void;
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

  const probeSub = discovery?.targets.find((t) => t.id === probeTargetId);
  const shared =
    probeSub &&
    [...selected]
      .map((id) => discovery?.targets.find((t) => t.id === id))
      .some((t) => t && t.subscriptionExternalId === probeSub.subscriptionExternalId && t.metricCode === probeSub.metricCode);

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
    </>
  );
}
