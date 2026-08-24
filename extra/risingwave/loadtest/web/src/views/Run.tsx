import { useMemo, useState } from "react";
import {
  api,
  duration,
  ms,
  num,
  pct,
  type Discovery,
  type RunSpec,
  type Segment,
  type Snapshot,
  type StageKey,
} from "../lib/api";
import { Banner, Card, Checklist, ClockPanel, ErrorsPanel, LogPanel, PercentileTable, Stat } from "../components/panels";
import { Funnel, Histogram, HopWaterfall, PercentileBars, Throughput, type FunnelStage, type PercentileRow } from "../components/charts";

const STAGE_LABELS: Record<StageKey, string> = {
  rwEnriched: "RisingWave events_enriched",
  rwExpanded: "RisingWave events_expanded",
  chRwEnriched: "ClickHouse RW shadow (enriched)",
  chRwExpanded: "ClickHouse RW shadow (expanded)",
  chGoEnriched: "ClickHouse Go path (enriched)",
  chGoExpanded: "ClickHouse Go path (expanded)",
};

const ALL_STAGES = Object.keys(STAGE_LABELS) as StageKey[];

const RUNNING = ["preflight", "sending", "draining"];

export function Run({
  segments,
  spec,
  setSpec,
  discovery,
  snap,
  connected,
}: {
  segments: Segment[];
  spec: RunSpec;
  setSpec: (s: RunSpec) => void;
  discovery: Discovery | null;
  snap: Snapshot | null;
  connected: boolean;
}) {
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [histSeg, setHistSeg] = useState<string>("ch_rw_expanded_visible");

  const live = snap && RUNNING.includes(snap.phase);
  const stats = snap?.stats ?? {};
  const unavailable = snap?.unavailable ?? [];

  const polled = segments.filter((s) => s.kind === "polled");
  const stamped = segments.filter((s) => s.kind === "stamped");

  const start = async () => {
    setStarting(true);
    setError(null);
    try {
      await api.startRun(spec);
    } catch (e) {
      const body = (e as { body?: { error?: string; run?: Snapshot } }).body;
      setError(body?.error ?? (e as Error).message);
    } finally {
      setStarting(false);
    }
  };

  const stop = async () => {
    try {
      await api.stopRun();
    } catch (e) {
      setError((e as Error).message);
    }
  };

  const estSeconds = spec.rateEps > 0 ? Math.round(spec.totalEvents / spec.rateEps) : 0;

  const headlineRows: PercentileRow[] = useMemo(
    () =>
      polled.flatMap((s): PercentileRow[] => {
        const p = stats[s.key];
        if (!p) return [];
        const row: PercentileRow = { key: s.key, label: s.label, p50: p.p50, p95: p.p95, p99: p.p99, count: p.count };
        if (s.key === "usage_visible") row.note = snap?.usageMode === "watermark" ? "watermark attribution" : "exact probe";
        return [row];
      }),
    [polled, stats],
  );

  const hops = useMemo(
    () =>
      [
        { key: "ingest_to_broker", label: "Lago → Redpanda" },
        { key: "broker_to_rw", label: "Redpanda → RisingWave" },
        { key: "rw_to_ch", label: "RisingWave → ClickHouse" },
      ]
        .map((h) => ({ ...h, value: stats[h.key]?.p50 ?? NaN }))
        .filter((h) => Number.isFinite(h.value)),
    [stats],
  );

  const funnel: FunnelStage[] = useMemo(() => {
    const out: FunnelStage[] = [];
    if (snap?.counters) out.push({ key: "accepted", label: "Accepted by the Lago API", count: snap.counters.accepted });
    for (const s of ALL_STAGES) {
      const c = snap?.stageCounts?.[s];
      if (c != null) out.push({ key: s, label: STAGE_LABELS[s], count: c });
    }
    return out;
  }, [snap]);

  /** A negative duration cannot happen physically: it means the two clocks disagree. */
  const skewed = useMemo(
    () => stamped.filter((seg) => (stats[seg.key]?.p50 ?? 0) < 0).map((seg) => seg.label),
    [stamped, stats],
  );

  const effectiveRate = useMemo(() => {
    const r = snap?.rate ?? [];
    if (r.length < 3) return null;
    const window = r.slice(-6);
    return Math.round(window.reduce((s, x) => s + x.sent, 0) / window.length);
  }, [snap]);

  return (
    <>
      {error && <Banner kind="bad">{error}</Banner>}
      {!connected && <Banner kind="warn">Live stream disconnected — retrying. The server keeps running the test.</Banner>}

      <Card
        title="Launch"
        hint={live ? "a run is in progress" : `${spec.targetIds.length} target(s) selected`}
        right={
          live ? (
            <div className="row">
              <span className="pill">
                <span className="dot live" /> {snap?.phase}
              </span>
              <button className="btn danger" onClick={stop}>
                Stop
              </button>
            </div>
          ) : (
            <button className="btn primary" onClick={start} disabled={starting || spec.targetIds.length === 0}>
              {starting ? "Starting…" : "Run preflight & start"}
            </button>
          )
        }
      >
        {spec.targetIds.length === 0 && (
          <Banner kind="warn">No targets selected. Pick some on the Targets tab first.</Banner>
        )}
        <div className="grid cols-4" style={{ marginTop: spec.targetIds.length === 0 ? 12 : 0 }}>
          <label className="field">
            Target rate (events/s)
            <input
              type="number"
              min={1}
              value={spec.rateEps}
              disabled={!!live}
              onChange={(e) => setSpec({ ...spec, rateEps: Number(e.target.value) })}
            />
            <span className="note">one POST per event, bounded worker pool</span>
          </label>
          <label className="field">
            Total events
            <input
              type="number"
              min={1}
              value={spec.totalEvents}
              disabled={!!live}
              onChange={(e) => setSpec({ ...spec, totalEvents: Number(e.target.value) })}
            />
            <span className="note">≈ {duration(estSeconds * 1000)} at the target rate</span>
          </label>
          <label className="field">
            Probe every Nth event
            <input
              type="number"
              min={0}
              value={spec.probeEvery}
              disabled={!!live}
              onChange={(e) => setSpec({ ...spec, probeEvery: Number(e.target.value) })}
            />
            <span className="note">0 disables visibility polling (stamps only)</span>
          </label>
          <label className="field">
            Stop above error rate (%)
            <input
              type="number"
              min={0}
              value={spec.guards.maxErrorRatePct}
              disabled={!!live}
              onChange={(e) => setSpec({ ...spec, guards: { ...spec.guards, maxErrorRatePct: Number(e.target.value) } })}
            />
            <span className="note">hard cap {num(spec.guards.hardCap)} events</span>
          </label>
        </div>

        <div className="row" style={{ marginTop: 12, gap: 18 }}>
          <span style={{ fontSize: 12, color: "var(--text-muted)" }}>Spread:</span>
          <label className="row" style={{ fontSize: 12, gap: 6 }}>
            values per group key
            <input
              type="number"
              min={1}
              style={{ width: 70 }}
              value={spec.spread.groupKeyValues}
              disabled={!!live}
              onChange={(e) => setSpec({ ...spec, spread: { ...spec.spread, groupKeyValues: Number(e.target.value) } })}
            />
          </label>
          <label className="row" style={{ fontSize: 12, gap: 6 }}>
            <input
              type="checkbox"
              checked={spec.spread.includeDefaultBucket}
              disabled={!!live}
              onChange={(e) =>
                setSpec({ ...spec, spread: { ...spec.spread, includeDefaultBucket: e.target.checked } })
              }
            />
            also hit the default bucket
          </label>
          <label className="row" style={{ fontSize: 12, gap: 6 }}>
            max shapes / target
            <input
              type="number"
              min={1}
              style={{ width: 70 }}
              value={spec.spread.maxVariantsPerTarget}
              disabled={!!live}
              onChange={(e) =>
                setSpec({ ...spec, spread: { ...spec.spread, maxVariantsPerTarget: Number(e.target.value) } })
              }
            />
          </label>
        </div>

        <div className="row" style={{ marginTop: 12, gap: 18 }}>
          <label className="row" style={{ fontSize: 13, gap: 6 }}>
            <input
              type="checkbox"
              checked={spec.ramp.enabled}
              disabled={!!live}
              onChange={(e) => setSpec({ ...spec, ramp: { ...spec.ramp, enabled: e.target.checked } })}
            />
            Ramp
          </label>
          {spec.ramp.enabled && (
            <>
              <label className="row" style={{ fontSize: 12, gap: 6 }}>
                from
                <input
                  type="number"
                  style={{ width: 90 }}
                  value={spec.ramp.fromEps}
                  disabled={!!live}
                  onChange={(e) => setSpec({ ...spec, ramp: { ...spec.ramp, fromEps: Number(e.target.value) } })}
                />
                /s
              </label>
              <label className="row" style={{ fontSize: 12, gap: 6 }}>
                over
                <input
                  type="number"
                  style={{ width: 90 }}
                  value={spec.ramp.overSec}
                  disabled={!!live}
                  onChange={(e) => setSpec({ ...spec, ramp: { ...spec.ramp, overSec: Number(e.target.value) } })}
                />
                s
              </label>
            </>
          )}
          <div style={{ width: 1, height: 20, background: "var(--border)" }} />
          <span style={{ fontSize: 12, color: "var(--text-muted)" }}>Stages to poll:</span>
          {ALL_STAGES.map((s) => (
            <label key={s} className="row" style={{ fontSize: 12, gap: 5 }}>
              <input
                type="checkbox"
                checked={spec.stages[s]}
                disabled={!!live}
                onChange={(e) => setSpec({ ...spec, stages: { ...spec.stages, [s]: e.target.checked } })}
              />
              {STAGE_LABELS[s]}
            </label>
          ))}
        </div>
      </Card>

      {snap?.preflight && snap.preflight.length > 0 && (
        <Card title="Preflight" hint="what is reachable, and therefore what this run can and cannot measure">
          <Checklist checks={snap.preflight} />
        </Card>
      )}

      {snap && snap.phase !== "idle" && (
        <>
          <Card
            title="Run"
            hint={snap.id}
            right={
              <span className="pill">
                {live ? <span className="dot live" /> : <span className={`dot ${snap.phase === "done" ? "ok" : "warn"}`} />}
                {snap.phase}
              </span>
            }
          >
            <div className="grid cols-4">
              <Stat
                label="Accepted"
                value={num(snap.counters?.accepted)}
                sub={`of ${num(snap.counters?.sent)} sent · ${pct(snap.counters?.accepted ?? 0, snap.counters?.sent ?? 0)}`}
              />
              <Stat
                label="Failed"
                value={num(snap.counters?.failed)}
                sub={snap.counters?.sent ? pct(snap.counters.failed, snap.counters.sent) : "—"}
              />
              <Stat label="Elapsed" value={duration(snap.elapsedMs)} sub={effectiveRate != null ? `${effectiveRate}/s observed` : "—"} />
              <Stat
                label={snap.usageMode === "watermark" ? "Usage attributed" : "Probes in flight"}
                value={
                  snap.usageMode === "watermark"
                    ? `${num(snap.probeTarget?.attributed)} / ${num(snap.probeTarget?.expected)}`
                    : num(snap.counters?.pendingProbes)
                }
                sub={`${num(snap.counters?.probes)} visibility probe(s) · ${num(snap.counters?.usageProbes)} usage sample(s)${
                  snap.counters?.usageTimeouts ? ` · ${snap.counters.usageTimeouts} never counted` : ""
                }`}
              />
            </div>
          </Card>

          {skewed.length > 0 && (
            <Banner kind="warn">
              <b>Negative durations on {skewed.length} stamped segment(s)</b> — {skewed.join("; ")}. A hop cannot take
              less than zero time, so this is clock disagreement between the two machines, not latency. Check the clock
              offsets panel below; the polled end-to-end numbers are unaffected because both of their endpoints come from
              this app's clock.
            </Banner>
          )}

          {snap.usageFreshness && snap.usageFreshness.verdict === "batched" && (
            <Banner kind="bad">
              <b>The usage numbers below are not per-event latency.</b> One reading accounted for{" "}
              {num(snap.usageFreshness.worstBatch)} events at once (
              {Math.round(snap.usageFreshness.batchShare * 100)}% of the run), which is what a <em>cached</em> read path
              looks like: it does not move while events arrive, then jumps once when something invalidates it. Every
              "latency" in that jump is really the same refresh, measured from each event's own send time — which is why
              the distribution comes out as a straight ramp. Fix the read path
              (<code>LAGO_RISINGWAVE_USAGE_ENABLED=true</code>, and the charge must be count/sum, in arrears,
              non-prorated, non-recurring, no custom expression), then re-run.
            </Banner>
          )}
          {snap.usageFreshness && snap.usageFreshness.verdict === "coarse" && (
            <Banner kind="warn">
              Usage readings advanced in steps of up to {num(snap.usageFreshness.worstBatch)} events, so the usage
              percentiles are coarser than the other stages. Poll harder (Setup → usage poll interval / in flight) or
              lower the event rate for a cleaner usage measurement.
            </Banner>
          )}

          {snap.usageMode !== "off" && snap.usagePoll && (
            <Card
              title="Usage sampling"
              hint={`${snap.usageMode} attribution · what the current_usage measurement can resolve`}
            >
              <div className="grid cols-4">
                <Stat
                  label="Polls / second"
                  value={snap.usagePoll.perSecond.toFixed(1)}
                  sub={`${num(snap.usagePoll.completed)} completed · ${num(snap.usagePoll.inFlight)} in flight${
                    snap.usagePoll.failed ? ` · ${num(snap.usagePoll.failed)} failed` : ""
                  }`}
                />
                <Stat
                  label="current_usage RTT"
                  value={ms(snap.usagePoll.rttP50)}
                  sub={`p95 ${ms(snap.usagePoll.rttP95)} — pipelined, so this does not set the resolution`}
                />
                <Stat
                  label="Uncertainty"
                  value={`±${ms(snap.usagePoll.resolutionMs)}`}
                  sub={`half the window each crossing was pinned inside (p95 window ${ms(snap.usagePoll.bracketP95Ms)})`}
                />
                <Stat
                  label="Attributed"
                  value={`${num(snap.probeTarget?.attributed)} / ${num(snap.probeTarget?.expected)}`}
                  sub={`by expected units on ${snap.probeTarget?.metric ?? "—"}`}
                />
                <Stat
                  label="Reading advance"
                  value={
                    snap.usageFreshness?.verdict === "incremental"
                      ? "incremental"
                      : snap.usageFreshness?.verdict ?? "unknown"
                  }
                  sub={`largest single step ${num(snap.usageFreshness?.worstBatch)} event(s)${
                    snap.usageFreshness?.batches ? ` · ${num(snap.usageFreshness.batches)} multi-event step(s)` : ""
                  }`}
                />
              </div>
            </Card>
          )}

          <Card
            title="End-to-end latency, by stage"
            hint="from the moment the POST left this app until a reader could see the row — single clock, no skew"
          >
            <PercentileBars rows={headlineRows} />
            {headlineRows.length > 0 && (
              <p style={{ marginTop: 10, fontSize: 12, color: "var(--text-muted)" }}>
                Resolution is the poll tick, so a value below it means "seen on the first poll". Sampled from every{" "}
                {spec.probeEvery}
                th event; the table below covers every event for the stamped segments.
              </p>
            )}
          </Card>

          <div className="grid cols-2">
            <Card title="Where the time goes" hint="median hop, from timestamps the pipeline recorded (all events)">
              <HopWaterfall hops={hops} />
              {hops.length < 3 && (
                <p style={{ marginTop: 8, fontSize: 12, color: "var(--text-muted)" }}>
                  Missing hops are legs whose clock column does not exist upstream — see Preflight.
                </p>
              )}
            </Card>
            <Card title="Did everything arrive?" hint="distinct events of this run reaching each stage">
              <Funnel stages={funnel} />
            </Card>
          </div>

          <Card
            title="Distribution"
            hint="the shape behind the percentiles — a long right tail and a shifted bulk mean different things"
            right={
              <select value={histSeg} onChange={(e) => setHistSeg(e.target.value)} style={{ width: 340 }}>
                {segments
                  .filter((s) => snap.histograms?.[s.key])
                  .map((s) => (
                    <option key={s.key} value={s.key}>
                      {s.label}
                    </option>
                  ))}
              </select>
            }
          >
            <Histogram
              hist={snap.histograms?.[histSeg]}
              p50={stats[histSeg]?.p50}
              p95={stats[histSeg]?.p95}
              p99={stats[histSeg]?.p99}
              label={segments.find((s) => s.key === histSeg)?.label ?? histSeg}
            />
          </Card>

          <Card title="Throughput" hint="what was actually achieved per second, against what was asked for">
            <Throughput series={snap.rate ?? []} />
          </Card>

          <Card
            title="All segments"
            hint="the table view — polled segments are single-clock; stamped segments span two machines"
          >
            <PercentileTable segments={[...polled, ...stamped]} stats={stats} unavailable={unavailable} />
          </Card>

          <div className="grid cols-2">
            <Card title="Clock offsets" hint="measured at preflight">
              <ClockPanel clocks={snap.clocks} />
            </Card>
            <Card title="Errors" hint="grouped by message">
              <ErrorsPanel errors={snap.errors ?? []} />
            </Card>
          </div>

          {snap.spread && snap.spread.length > 0 && (
            <Card
              title="Event spread"
              hint={`${snap.spread.length} shape(s) — every charge filter, the default bucket, and each pricing group key value${
                snap.spreadTruncated ? ` · ${num(snap.spreadTruncated)} capped` : ""
              }`}
            >
              <div className="scroll">
                <table className="data">
                  <thead>
                    <tr>
                      <th>Target</th>
                      <th style={{ textAlign: "left" }}>Shape</th>
                      <th style={{ textAlign: "left" }}>Bucket</th>
                      <th style={{ textAlign: "left" }}>Properties sent</th>
                      <th>Events</th>
                    </tr>
                  </thead>
                  <tbody>
                    {snap.spread.map((v) => (
                      <tr key={v.target + v.label}>
                        <td className="mono" style={{ fontSize: 12 }}>
                          {v.target}
                        </td>
                        <td style={{ textAlign: "left" }}>{v.label}</td>
                        <td style={{ textAlign: "left" }}>
                          <span className="pill" style={{ fontSize: 11 }}>
                            {v.kind === "filter" ? "charge filter" : "default"}
                            {v.grouped ? " · grouped" : ""}
                          </span>
                        </td>
                        <td className="mono" style={{ textAlign: "left", fontSize: 11, color: "var(--text-secondary)" }}>
                          {Object.entries(v.properties)
                            .map(([k, val]) => `${k}=${val}`)
                            .join(" ") || "—"}
                        </td>
                        <td className="num">{num(v.sent)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Card>
          )}

          <Card title="Log" hint="newest first">
            <LogPanel logs={snap.logs} />
          </Card>
        </>
      )}

      {(!snap || snap.phase === "idle") && (
        <Card title="What this measures" hint="read once, then the numbers above interpret themselves">
          <div className="grid cols-2">
            <div>
              <h3>Polled — the trustworthy end-to-end numbers</h3>
              <p style={{ fontSize: 13, color: "var(--text-secondary)", marginTop: 6 }}>
                A sampled event is queried at each stage every poll tick until it appears. Both ends of the measurement —
                the moment the POST left, and the tick that first saw the row — are read from this app's clock, so no
                cross-cloud clock skew can enter. Cost is flat in the number of probes: one query per stage per tick for
                the whole in-flight set, not one per event.
              </p>
            </div>
            <div>
              <h3>Stamped — the per-hop breakdown</h3>
              <p style={{ fontSize: 13, color: "var(--text-secondary)", marginTop: 6 }}>
                Every event (not just probes) also carries the timestamps the pipeline itself recorded:{" "}
                <code>ingested_at</code> from Lago, <code>kafka_timestamp</code> from the broker,{" "}
                <code>rw_received_at</code> from RisingWave, <code>enriched_at</code> from ClickHouse. These pinpoint the
                expensive hop, but each spans two machines' clocks — the offsets panel shows how much that is worth.
              </p>
            </div>
          </div>
        </Card>
      )}
    </>
  );
}
