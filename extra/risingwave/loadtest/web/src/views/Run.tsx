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

  // The run being displayed decides what its segments mean: on a direct-produce
  // run two of them stop describing Lago at all. The override lives in the
  // server's catalog, so the dashboard still cannot claim more than the catalog
  // says — it only picks which of the two statements applies.
  // A snapshot is authoritative about its own run — including a run persisted
  // before this transport existed, whose spec carries no transport at all and is
  // therefore an API run, whatever the form is currently set to.
  const direct = snap?.spec ? snap.spec.send.transport === "kafka" : spec.send.transport === "kafka";
  const shown = useMemo(
    () =>
      direct
        ? segments.map((seg) => (seg.whenDirectProduce ? { ...seg, ...seg.whenDirectProduce } : seg))
        : segments,
    [segments, direct],
  );

  const polled = shown.filter((s) => s.kind === "polled");
  const stamped = shown.filter((s) => s.kind === "stamped");

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
        if (s.key === "wallet_visible")
          row.note =
            snap?.walletMode === "refresh"
              ? "per refresh — upper bound"
              : snap?.walletMode === "watermark"
                ? "watermark attribution"
                : "exact probe";
        if (s.key === "usage_to_wallet") row.note = "the wallet hop alone";
        return [row];
      }),
    [polled, stats, snap?.usageMode, snap?.walletMode],
  );

  const hops = useMemo(
    () =>
      [
        { key: "ingest_to_broker", label: direct ? "this app → Redpanda" : "Lago → Redpanda" },
        { key: "broker_to_rw", label: "Redpanda → RisingWave" },
        { key: "rw_to_ch", label: "RisingWave → ClickHouse" },
      ]
        .map((h) => ({ ...h, value: stats[h.key]?.p50 ?? NaN }))
        .filter((h) => Number.isFinite(h.value)),
    [stats, direct],
  );

  const funnel: FunnelStage[] = useMemo(() => {
    const out: FunnelStage[] = [];
    if (snap?.counters)
      out.push({
        key: "accepted",
        label: direct ? "Acked by Redpanda" : "Accepted by the Lago API",
        count: snap.counters.accepted,
      });
    for (const s of ALL_STAGES) {
      const c = snap?.stageCounts?.[s];
      if (c != null) out.push({ key: s, label: STAGE_LABELS[s], count: c });
    }
    return out;
  }, [snap, direct]);

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
      {direct && (
        <Banner kind="info">
          <b>Direct produce.</b> Events are written straight to the raw events topic, byte-shape identical to what the
          API produces — so the Lago API is not in the send path and its ingest cost is <em>not</em> part of any number
          below. "Produce ack" replaces "API response", and <code>ingested_at</code> is stamped by this app rather than
          by Lago. The read paths measured here (current usage, wallets) still go through the API.
        </Banner>
      )}

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
            <span className="note">
              {spec.send.transport === "kafka"
                ? `${Math.ceil(spec.rateEps / Math.max(1, spec.send.batchSize))} produce/s of ${spec.send.batchSize} events`
                : spec.send.batchSize > 1
                  ? `${Math.ceil(spec.rateEps / spec.send.batchSize)} POST/s of ${spec.send.batchSize} events`
                  : "one POST per event"}
            </span>
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
            <span className="note">judged over a trailing 10s window; 0 disables the stop</span>
          </label>
        </div>

        <div className="row" style={{ marginTop: 12, gap: 18 }}>
          <span style={{ fontSize: 12, color: "var(--text-muted)" }}>Send:</span>
          <label className="row" style={{ fontSize: 12, gap: 6 }}>
            transport
            <select
              style={{ width: 190 }}
              value={spec.send.transport}
              disabled={!!live}
              onChange={(e) => {
                const transport = e.target.value as RunSpec["send"]["transport"];
                // The two transports have completely different useful batch
                // sizes (Lago caps at 100, a produce request does not), so
                // switching without moving the batch would either leave 5 000
                // events on a POST or 1 event on a produce request.
                const batchSize = transport === "kafka" ? Math.max(spec.send.batchSize, 500) : 1;
                setSpec({ ...spec, send: { ...spec.send, transport, batchSize } });
              }}
            >
              <option value="api">Lago API (POST /events)</option>
              <option value="kafka">Redpanda (direct produce)</option>
            </select>
          </label>
          <label className="row" style={{ fontSize: 12, gap: 6 }}>
            events per {spec.send.transport === "kafka" ? "produce" : "POST"}
            <input
              type="number"
              min={1}
              max={spec.send.transport === "kafka" ? 2000 : 100}
              style={{ width: 80 }}
              value={spec.send.batchSize}
              disabled={!!live}
              onChange={(e) => setSpec({ ...spec, send: { ...spec.send, batchSize: Number(e.target.value) } })}
            />
          </label>
          <label className="row" style={{ fontSize: 12, gap: 6 }}>
            requests in flight
            <input
              type="number"
              min={0}
              style={{ width: 70 }}
              value={spec.send.maxInFlight}
              disabled={!!live}
              onChange={(e) => setSpec({ ...spec, send: { ...spec.send, maxInFlight: Number(e.target.value) } })}
            />
          </label>
          <span style={{ fontSize: 12, color: "var(--text-muted)" }}>
            {spec.send.transport === "kafka"
              ? "Direct produce writes the API's own message to the raw events topic, so the send rate is no longer capped by Lago's round trip. The read paths (usage, wallets) still go through the API. 0 in flight = sized from the target rate and the ack latency being measured."
              : "0 = sized from the target rate and the round trip being measured. 1 event per POST is what a per-event integration sends; up to 100 is POST /events/batch."}
          </span>
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
                }${snap.walletMode !== "off" ? ` · ${num(snap.counters?.walletProbes)} wallet sample(s)` : ""}${
                  snap.counters?.walletTimeouts ? ` · ${snap.counters.walletTimeouts} never reached the wallet` : ""
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

          {snap.walletFreshness?.staleAtStart && (
            <Banner kind="bad">
              <b>The wallet numbers below are not latency.</b> Preflight sent one event and the ongoing balance never
              moved, so the refresh path was not running when this run started. Check that karafka is consuming{" "}
              <code>wallet_refresh_triggers</code> (<code>LAGO_KAFKA_WALLET_REFRESH_TRIGGERS_TOPIC</code>), that the
              RisingWave <code>wallet_refresh_triggers_sink</code> exists, and that <code>current_usage</code> itself is
              live — the refresh reads usage, so a dead usage path is a dead wallet path.
            </Banner>
          )}
          {snap.walletMode === "refresh" && (
            <Banner kind="warn">
              <b>Wallet latency is an upper bound in this run.</b> The wallet's customer carries bulk traffic and at least
              one shape is not a <code>standard</code> charge, so per-event cents are not predictable and each refresh is
              timed against the oldest outstanding event. A refresh covers every event whose bucket had landed, so the
              events behind it are charged to the next refresh rather than to the one that actually included them. Point
              both probes at the same standard charge for per-event truth.
            </Banner>
          )}
          {snap.walletMode !== "off" && snap.walletFreshness?.verdict === "batched" && !snap.walletFreshness.staleAtStart && (
            <Banner kind="warn">
              One wallet reading accounted for {num(snap.walletFreshness.worstBatch)} events at once (
              {Math.round(snap.walletFreshness.batchShare * 100)}% of the run). That is the consumer's batch collapse
              doing its job — N triggers for one customer cost one refresh — but it means the wallet percentiles describe
              refresh cadence rather than per-event work. Lower the rate to separate the two.
            </Banner>
          )}

          {snap.walletMode !== "off" && snap.walletPoll && (
            <Card
              title="Wallet sampling"
              hint={`${snap.walletMode} attribution · ${snap.walletProbe?.customer ?? "—"} · ${num(
                snap.walletProbe?.wallets,
              )} active wallet(s)`}
            >
              <div className="grid cols-4">
                <Stat
                  label="Polls / second"
                  value={snap.walletPoll.perSecond.toFixed(1)}
                  sub={`${num(snap.walletPoll.completed)} completed · ${num(snap.walletPoll.inFlight)} in flight${
                    snap.walletPoll.failed ? ` · ${num(snap.walletPoll.failed)} failed` : ""
                  }`}
                />
                <Stat
                  label="GET /wallets RTT"
                  value={ms(snap.walletPoll.rttP50)}
                  sub={`p95 ${ms(snap.walletPoll.rttP95)} — the reading is a stored column, so polling never triggers the refresh it times`}
                />
                <Stat
                  label="Uncertainty"
                  value={`±${ms(snap.walletPoll.resolutionMs)}`}
                  sub={`half the window each crossing was pinned inside (p95 window ${ms(snap.walletPoll.bracketP95Ms)})`}
                />
                <Stat
                  label="Attributed"
                  value={`${num(snap.walletProbe?.attributed)} / ${num(snap.walletProbe?.expected)}`}
                  sub={
                    snap.walletMode === "watermark"
                      ? `by predicted cents × ${snap.walletProbe?.centsFactor ?? 1} calibration`
                      : "by observed increase of the ongoing balance"
                  }
                />
                <Stat
                  label="Refreshes"
                  value={num(snap.walletProbe?.refreshes)}
                  sub={
                    snap.walletProbe?.eventsPerRefresh != null
                      ? `${snap.walletProbe.eventsPerRefresh} event(s) per refresh — the consumer's batch collapse${
                          snap.walletProbe.refreshesExact ? "" : " (lower bound: counted from amount changes only)"
                        }`
                      : "none observed yet"
                  }
                />
                <Stat
                  label="Reading advance"
                  value={snap.walletFreshness?.verdict ?? "unknown"}
                  sub={`largest single step ${num(snap.walletFreshness?.worstBatch)} event(s)${
                    snap.walletFreshness?.batches ? ` · ${num(snap.walletFreshness.batches)} multi-event step(s)` : ""
                  }`}
                />
                <Stat
                  label="Calibration"
                  value={snap.walletProbe?.canary || "—"}
                  sub="one real event, measured at preflight — absorbs taxes, currency subunit and the wallet rate"
                />
                <Stat
                  label="Usage → wallet split"
                  value={snap.walletProbe?.aligned ? "per event" : "not measurable"}
                  sub={
                    snap.walletProbe?.aligned
                      ? "both probes cover the same events, so the gap is one event compared with itself"
                      : "the probes cover different traffic — only the two distributions are comparable"
                  }
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
                {shown
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
              label={shown.find((s) => s.key === histSeg)?.label ?? histSeg}
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
