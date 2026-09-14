import { useEffect, useRef, useState } from "react";
import { api, num, type SeedPreview, type SeedSpec, type SeedStatus } from "../lib/api";
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
export function SeedCard({
  spec,
  setSpec,
  onSeeded,
  maxVariantsPerTarget,
}: {
  spec: SeedSpec | null;
  setSpec: (s: SeedSpec) => void;
  onSeeded: () => Promise<void>;
  /** The run's current variant cap, so the form can say when a wide charge would not be fully covered. */
  maxVariantsPerTarget: number | null;
}) {
  const [open, setOpen] = useState(false);
  const [limits, setLimits] = useState<Record<string, number> | null>(null);
  const [preview, setPreview] = useState<SeedPreview | null>(null);
  const [status, setStatus] = useState<SeedStatus | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [rescanning, setRescanning] = useState(false);
  const seenDone = useRef<number | null>(null);

  // Defaults come from the server so the form and the seeder cannot disagree,
  // and a job already running (another tab, or before a reload) is picked up.
  useEffect(() => {
    api
      .seedStatus()
      .then((r) => {
        setLimits(r.limits);
        setStatus(r.status);
        if (!spec) setSpec(r.status.spec ?? r.defaults);
        if (r.status.phase === "running") setOpen(true);
      })
      .catch((e) => setErr((e as Error).message));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Preview what the current widths would create, debounced.
  useEffect(() => {
    if (!spec) return;
    const t = setTimeout(() => {
      api.seedPreview(spec).then(setPreview).catch(() => setPreview(null));
    }, 250);
    return () => clearTimeout(t);
  }, [spec]);

  // Poll while running; rescan once when it finishes so the new targets appear.
  const running = status?.phase === "running";
  useEffect(() => {
    if (!running) return;
    const t = setInterval(() => {
      api
        .seedStatus()
        .then((r) => setStatus(r.status))
        .catch(() => {});
    }, 700);
    return () => clearInterval(t);
  }, [running]);
  useEffect(() => {
    if (!status || status.phase === "running" || status.phase === "idle") return;
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
    if (!spec) return;
    setErr(null);
    try {
      const r = await api.seed(spec);
      setStatus(r.status);
    } catch (e) {
      setErr((e as Error).message);
    }
  };

  const field = (key: keyof Omit<SeedSpec, "prefix" | "currency">, label: string, note: string) =>
    spec && (
      <label className="field">
        {label}
        <input
          type="number"
          min={1}
          max={limits?.[key] ?? undefined}
          value={spec[key]}
          disabled={running}
          onChange={(e) => setSpec({ ...spec, [key]: Number(e.target.value) })}
        />
        <span className="note">{note}</span>
      </label>
    );

  return (
    <Card
      title="Seed fixtures"
      hint="create many metrics, plans, charges and subscriptions through the Lago API so the load fans out"
      right={
        <button className="btn" onClick={() => setOpen((o) => !o)}>
          {open ? "Hide" : "Show"}
        </button>
      }
    >
      {!open && (
        <p style={{ color: "var(--text-secondary)", fontSize: 13, margin: 0 }}>
          Every lookup in the pipeline is a temporal join, and a temporal join hashes the event stream on its key: one
          subscription and one metric code keep one actor busy whatever the cluster's parallelism. Seeding widens the key
          sets — metric codes for stage 0, (plan, code) pairs and subscriptions for stage 1 — so the ceiling a run finds is
          the pipeline's and not one core's. It also plants AI-company charges with dozens of filters each (one per model ×
          token type), so filter matching is scored against a realistic candidate set rather than two values.
          {status?.phase === "done" && status.matrix
            ? ` Last seed: ${num(status.matrix.targets)} targets under "${status.spec?.prefix}".`
            : ""}
        </p>
      )}
      {open && spec && (
        <>
          {err && <Banner kind="bad">{err}</Banner>}
          <div className="grid cols-4" style={{ marginTop: err ? 10 : 0 }}>
            <label className="field">
              prefix
              <input
                type="text"
                value={spec.prefix}
                disabled={running}
                onChange={(e) => setSpec({ ...spec, prefix: e.target.value })}
              />
              <span className="note">every code and external id starts with it; the seed is idempotent per prefix</span>
            </label>
            {field(
              "billableMetrics",
              "billable metrics",
              "distinct codes = stage-0 keys (billable_metrics join). Kinds rotate: count, count+filters, sum+filters, sum grouped by region",
            )}
            {field("plans", "plans", "each subscribes 1/N of the customers")}
            {field(
              "chargesPerPlan",
              "charges per plan",
              "a window of metrics per plan; plans × charges = stage-1 (plan, code) keys (flat_filters_agg join)",
            )}
            {field(
              "subscriptions",
              "customers + subscriptions",
              "one active subscription per customer; distinct external ids = stage-1 subscription keys AND the API's Kafka partition keys",
            )}
            {field(
              "wideFilters",
              "charge filters per wide charge",
              "the AI-company shape: one charge filter per model × token type (input, output, cached_input) on every 'sum many filters' charge — the size of the candidate array matching_filter() scores each event against",
            )}
            <label className="field">
              currency
              <input
                type="text"
                value={spec.currency}
                disabled={running}
                style={{ width: 80 }}
                onChange={(e) => setSpec({ ...spec, currency: e.target.value })}
              />
              <span className="note">plans and customers</span>
            </label>
          </div>

          {preview && (
            <div style={{ marginTop: 12 }}>
              <Banner kind="info">
                <b>{num(preview.metrics)}</b> metric codes ({Object.entries(preview.kinds)
                  .map(([k, n]) => `${n} ${k.replace("_", " ")}`)
                  .join(", ")}) · <b>{num(preview.plans)}</b> plans × {num(preview.spec.chargesPerPlan)} charges ={" "}
                <b>{num(preview.planCodePairs)}</b> (plan, code) pairs carrying <b>{num(preview.chargeFilters)}</b> charge
                filters · <b>{num(preview.subscriptions)}</b> subscriptions → <b>{num(preview.targets)}</b> targets after a
                rescan. Filtered metrics get charge filters on <code>tier=gold</code> and <code>tier=silver</code>, leaving{" "}
                <code>bronze</code> for the default bucket; grouped ones price by <code>region</code>; the wide ones carry{" "}
                {num(preview.spec.wideFilters)} filters each, one per <code>model</code> × <code>token_type</code>, with one
                extra model declared but unpriced so it lands in the default bucket. All charges are standard at an integer
                price per unit, so a wallet stays priceable. About {num(preview.apiCalls)} API calls, 8 in flight.
                <br />
                <span style={{ color: "var(--text-muted)" }}>
                  Sizing rule: hashing K keys over P actors only evens out when K is several times P. The defaults give a
                  16-actor fragment 2× its actors in codes, 6× in (plan, code) pairs and 8× in subscriptions — the
                  subscription join being the hot fragment. Shrink one dimension on purpose to watch that fragment become
                  the bottleneck.
                </span>
              </Banner>
            </div>
          )}

          {preview && maxVariantsPerTarget != null && maxVariantsPerTarget <= preview.maxFiltersPerCharge && (
            <div style={{ marginTop: 10 }}>
              <Banner kind="warn">
                The run's <b>max shapes per target</b> is {num(maxVariantsPerTarget)}, but a wide charge has{" "}
                {num(preview.maxFiltersPerCharge)} filters plus the default bucket: the run would send only the first{" "}
                {num(maxVariantsPerTarget)} shapes and never exercise the rest. Raise it above{" "}
                {num(preview.maxFiltersPerCharge)} on the Run tab (the default is {num(preview.defaultMaxVariantsPerTarget)}).
              </Banner>
            </div>
          )}

          <div className="row" style={{ marginTop: 12 }}>
            <button className="btn primary" onClick={start} disabled={running || !preview}>
              {running ? "Seeding…" : "Seed"}
            </button>
            {rescanning && <span style={{ color: "var(--text-muted)", fontSize: 12 }}>rescanning Lago…</span>}
            {status?.phase === "done" && !running && (
              <span className="pill">
                <span className="dot ok" /> done in {status.endedAt && status.startedAt ? Math.round((status.endedAt - status.startedAt) / 100) / 10 : "?"}s
              </span>
            )}
            {status?.phase === "failed" && (
              <span className="pill">
                <span className="dot bad" /> {status.error}
              </span>
            )}
          </div>

          {status && status.phase !== "idle" && (
            <div style={{ marginTop: 12 }}>
              <div className="scroll">
                <table className="data">
                  <thead>
                    <tr>
                      <th>Step</th>
                      <th>Total</th>
                      <th>Created</th>
                      <th>Existing</th>
                      <th>Failed</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(
                      [
                        ["metrics", "billable metrics"],
                        ["plans", "plans (with charges and charge filters)"],
                        ["customers", "customers"],
                        ["subscriptions", "subscriptions"],
                      ] as const
                    ).map(([k, label]) => {
                      const c = status.steps[k];
                      return (
                        <tr key={k}>
                          <td>{label}</td>
                          <td className="num">{num(c.total)}</td>
                          <td className="num">{num(c.created)}</td>
                          <td className="num">{num(c.existing)}</td>
                          <td className="num" style={c.failed ? { color: "var(--critical)" } : undefined}>
                            {num(c.failed)}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              <div style={{ marginTop: 10 }}>
                <LogPanel logs={status.log} />
              </div>
            </div>
          )}
        </>
      )}
    </Card>
  );
}
