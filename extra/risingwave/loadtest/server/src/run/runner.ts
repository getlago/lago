import { randomBytes } from "node:crypto";
import { mkdirSync, writeFileSync, appendFileSync } from "node:fs";
import { resolve } from "node:path";
import { getConfig, RUNS_DIR } from "../config.js";
import type { Target } from "../discovery.js";
import { buildVariants, unitsOfVariant, type EventVariant } from "../variants.js";
import {
  currentUsage,
  postEvent,
  usageValue,
  lagoHealth,
  lagoServerTimeMs,
  type EventPayload,
} from "../clients/lago.js";
import {
  chCount,
  chHealth,
  chNowMs,
  chSeen,
  chSweep,
  chTable,
  chTableCheck,
  type ChScope,
  type ChTableKey,
} from "../clients/clickhouse.js";
import {
  rwCount,
  rwHealth,
  rwNowMs,
  rwSeen,
  rwSweep,
  rwTableCheck,
  type RwCaps,
  type RwTableKey,
} from "../clients/risingwave.js";
import { RateTracker, Series, SeriesSet } from "./stats.js";
import type { ClockOffsets, RunPhase, RunSpec, StageKey } from "../types.js";

const RW_STAGES: RwTableKey[] = ["rwEnriched", "rwExpanded"];
const CH_STAGES: ChTableKey[] = ["chRwEnriched", "chRwExpanded", "chGoEnriched", "chGoExpanded"];
const isRwStage = (s: StageKey): s is RwTableKey => (RW_STAGES as StageKey[]).includes(s);

type Rec = {
  txid: string;
  seq: number;
  stream: "bulk" | "probe";
  targetId: string;
  metricCode: string;
  subscriptionExternalId: string;
  isVisibilityProbe: boolean;
  sentAt: number;
  apiMs: number;
  ok: boolean;
  status: number;
  /** Wall-clock ms (this app's clock) at which a stage first answered a query. */
  seen: Partial<Record<StageKey, number>>;
  /** Timestamps recorded by the pipeline itself. */
  stamps: {
    ingestedMs?: number;
    kafkaMs?: number;
    rwReceivedMs?: number;
    rwExpandedMs?: number;
    chRwEnrichedMs?: number;
    chRwExpandedMs?: number;
    chGoEnrichedMs?: number;
    chGoExpandedMs?: number;
  };
  usageMs?: number;
  computed: Set<string>;
};

export type LogLine = { t: number; level: "info" | "warn" | "error"; msg: string };

export type PreflightCheck = {
  name: string;
  ok: boolean;
  detail: string;
  /** Segments this check gates; if it fails, they are not measurable. */
  gates: string[];
};

const nowSec = () => Math.floor(Date.now() / 1000);

/** How many events should have been sent by `elapsedSec`, integrating the ramp. */
function plannedBy(spec: RunSpec, elapsedSec: number): number {
  const { rateEps, ramp } = spec;
  if (!ramp.enabled || ramp.overSec <= 0) return rateEps * elapsedSec;
  const from = Math.max(0, ramp.fromEps);
  if (elapsedSec <= ramp.overSec) {
    return from * elapsedSec + ((rateEps - from) * elapsedSec * elapsedSec) / (2 * ramp.overSec);
  }
  const atKnee = from * ramp.overSec + ((rateEps - from) * ramp.overSec) / 2;
  return atKnee + rateEps * (elapsedSec - ramp.overSec);
}

export class Run {
  readonly id: string;
  readonly prefix: string;
  phase: RunPhase = "idle";
  startedAt = 0;
  endedAt = 0;
  logs: LogLine[] = [];
  preflight: PreflightCheck[] = [];
  clocks: ClockOffsets = { lago: null, risingwave: null, clickhouse: null, measuredAt: 0 };
  errors = new Map<string, number>();
  unavailable = new Set<string>();

  private recs = new Map<string, Rec>();
  private series = new SeriesSet();
  private rate = new RateTracker();
  private pending = new Map<StageKey, Set<string>>();
  private sweepWatermark = new Map<string, number>();
  private counters = { sent: 0, accepted: 0, failed: 0, probes: 0, usageProbes: 0, usageTimeouts: 0 };
  private stageCounts: Partial<Record<StageKey, number>> = {};
  private stopRequested = false;
  private timers: NodeJS.Timeout[] = [];
  /**
   * Per RELATION, not per run: events_enriched carries kafka_timestamp and
   * rw_received_at, events_expanded carries neither. Reusing one capability set
   * for both makes the expanded query reference columns that do not exist, and
   * RisingWave rejects the whole statement — so that stage silently measures
   * nothing. Found by smoke test 2026-08-24.
   */
  private rwCaps = new Map<RwTableKey, RwCaps>();
  private sendingDone = false;
  private usageBaseline = 0;
  private usageExpected = 0;
  /**
   * Usage attribution has two modes, because `current_usage` exposes no
   * per-event handle — only the monotonic events_count of a metric.
   *
   *  exact     the probe target receives NO bulk traffic, so one probe is sent
   *            at a time and the count crossing is unambiguously that event.
   *
   *  watermark the probe target also carries bulk traffic (the common case when
   *            an instance has a single subscription and metric). Every accepted
   *            event for the pair is recorded in send order, and when the count
   *            reaches k we attribute that crossing to the k-th event sent. All
   *            traffic to the pair is ours, so k is exact; only the pairing of
   *            crossing-to-event assumes in-order delivery, which is why this
   *            mode is labelled rather than presented as identical to `exact`.
   */
  usageMode: "exact" | "watermark" | "off" = "off";
  private usagePairSentAt: number[] = [];
  /** Cumulative units this run expects usage to read after event i. */
  private usagePairCumUnits: number[] = [];
  private usageUnitsBaseline = 0;
  private usageAttributed = 0;
  /**
   * A read path served from the charge cache does not move while events arrive,
   * then jumps once when something invalidates it. That produces a beautiful
   * linear ramp of "latencies" which are really one refresh — so it is detected
   * and reported instead of being averaged into a percentile.
   */
  private usageStale = { unchangedSincePolls: 0, unchangedSinceMs: 0, worstBatch: 0, batches: 0 };
  /** Set when the preflight canary proved the read path was not live. */
  usageStaleAtStart = false;
  private usagePolls = { issued: 0, completed: 0, failed: 0, inFlight: 0, firstAt: 0, lastAt: 0 };
  private usageRtt = new Series();
  /**
   * Send time of the most recent poll that came back NOT yet seeing the next
   * event. It is a hard lower bound on the crossing: a request that started
   * then, and reported the count as still short, proves the crossing had not
   * happened before it started. Pairing it with the receive time of the poll
   * that DID see the crossing brackets the event far tighter than assuming the
   * server read the counter halfway through one request.
   */
  private usageLastBelowT0 = 0;
  private usageBracket = new Series();
  private eventsFile: string;
  /**
   * One entry per (target, variant): a charge filter value combination, a
   * pricing-group-key value, or the default bucket. Events round-robin over the
   * whole plan so every dimension the pipeline can branch on is exercised
   * evenly, instead of every event landing in the first filter.
   */
  private plan: { target: Target; variant: EventVariant; sent: number }[] = [];
  private planTruncated = 0;

  constructor(
    readonly spec: RunSpec,
    readonly targets: Target[],
    readonly probeTarget: Target | null,
  ) {
    this.id = `${new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14)}-${randomBytes(2).toString("hex")}`;
    // Every id of this run shares a prefix, so a sweep is one LIKE scan per stage.
    this.prefix = `lt-${this.id}-`;
    mkdirSync(resolve(RUNS_DIR, this.id), { recursive: true });
    this.eventsFile = resolve(RUNS_DIR, this.id, "events.jsonl");
    for (const s of [...RW_STAGES, ...CH_STAGES]) this.pending.set(s, new Set());
    for (const t of targets) {
      const { variants, truncated } = buildVariants(t, spec.spread);
      this.planTruncated += truncated;
      for (const variant of variants) this.plan.push({ target: t, variant, sent: 0 });
    }
    if (this.plan.length === 0 && targets[0]) {
      const { variants } = buildVariants(targets[0], spec.spread);
      for (const variant of variants) this.plan.push({ target: targets[0], variant, sent: 0 });
    }
  }

  private log(level: LogLine["level"], msg: string) {
    this.logs.push({ t: Date.now(), level, msg });
    if (this.logs.length > 500) this.logs.splice(0, this.logs.length - 500);
  }

  private enabledStages(): StageKey[] {
    return [...RW_STAGES, ...CH_STAGES].filter((s) => this.spec.stages[s]);
  }

  private caps(key: RwTableKey): RwCaps {
    return this.rwCaps.get(key) ?? { rw: false, kafka: false, ingested: false, expanded: false };
  }

  /**
   * Everything the ClickHouse index needs to avoid a full scan: which
   * subscriptions and metric codes this run touches, and when it started.
   */
  private chScope(): ChScope {
    const all = [...this.targets, ...(this.probeTarget ? [this.probeTarget] : [])];
    return {
      subs: [...new Set(all.map((t) => t.subscriptionExternalId))],
      codes: [...new Set(all.map((t) => t.metricCode))],
      // Events carry `timestamp` = send time; back off a minute for clock slack.
      sinceMs: (this.startedAt || Date.now()) - 60_000,
    };
  }

  // ---------------------------------------------------------------- preflight

  async runPreflight(): Promise<boolean> {
    this.phase = "preflight";
    const checks: PreflightCheck[] = [];

    const lago = await lagoHealth();
    checks.push({
      name: "Lago API",
      ok: lago.ok,
      detail: lago.ok ? `authenticated, ${lago.metrics ?? "?"} billable metrics visible` : lago.error!,
      gates: ["everything"],
    });

    const rw = await rwHealth();
    checks.push({
      name: "RisingWave (pgwire)",
      ok: rw.ok,
      detail: rw.ok ? rw.version! : rw.error!,
      gates: ["rw_enriched_visible", "rw_expanded_visible", "stamped breakdown"],
    });

    if (rw.ok) {
      for (const key of RW_STAGES) {
        if (!this.spec.stages[key]) continue;
        const c = await rwTableCheck(key);
        checks.push({
          name: `RisingWave ${c.table}`,
          ok: c.ok,
          detail: c.ok
            ? `readable; clocks: ${
                [
                  "hasRwExpandedAt" in c && c.hasRwExpandedAt ? "rw_expanded_at" : null,
                  "hasRwReceivedAt" in c && c.hasRwReceivedAt ? "rw_received_at" : null,
                  "hasKafkaTimestamp" in c && c.hasKafkaTimestamp ? "kafka_timestamp" : null,
                ]
                  .filter(Boolean)
                  .join(", ") || "NONE (polling only)"
              }`
            : c.error!,
          gates: [key === "rwEnriched" ? "rw_enriched_visible" : "rw_expanded_visible"],
        });
        if (c.ok && "hasRwReceivedAt" in c) {
          this.rwCaps.set(key, {
            rw: Boolean(c.hasRwReceivedAt),
            kafka: Boolean(c.hasKafkaTimestamp),
            ingested: Boolean(c.hasIngestedAt),
            expanded: "hasRwExpandedAt" in c ? Boolean(c.hasRwExpandedAt) : false,
          });
        }
      }
      const enrichedCaps = this.caps("rwEnriched");
      if (!enrichedCaps.rw) {
        for (const k of ["broker_to_rw", "rw_to_ch"]) this.unavailable.add(k);
        this.log("warn", "events_enriched has no rw_received_at — stamped RisingWave legs unavailable");
      }
      if (!enrichedCaps.kafka) this.unavailable.add("ingest_to_broker");
    }

    const ch = await chHealth();
    checks.push({
      name: "ClickHouse (HTTPS)",
      ok: ch.ok,
      detail: ch.ok ? ch.version! : ch.error!,
      gates: CH_STAGES.map(String),
    });
    if (ch.ok) {
      for (const key of CH_STAGES) {
        if (!this.spec.stages[key]) continue;
        const c = await chTableCheck(key as ChTableKey);
        checks.push({
          name: `ClickHouse ${c.table}`,
          ok: c.ok,
          detail: c.ok ? "readable, has transaction_id + enriched_at" : c.error!,
          gates: [key],
        });
        if (!c.ok) this.spec.stages[key] = false;
      }
    }

    // Probe target must be isolated: usage attribution counts events_count on the
    // probe's (subscription, metric), so bulk traffic on the same pair would make
    // "my probe landed" indistinguishable from "someone else's event landed".
    if (this.probeTarget) {
      const shared = this.targets.some(
        (t) =>
          t.subscriptionExternalId === this.probeTarget!.subscriptionExternalId &&
          t.metricCode === this.probeTarget!.metricCode,
      );
      this.usageMode = shared ? "watermark" : "exact";
      checks.push({
        name: "Usage attribution",
        ok: true,
        detail: shared
          ? `WATERMARK mode: ${this.probeTarget.subscriptionExternalId}/${this.probeTarget.metricCode} also carries bulk traffic, so the k-th events_count increment is attributed to the k-th event sent to that pair. All traffic to it is ours, so k is exact; the pairing assumes in-order delivery.`
          : `EXACT mode: ${this.probeTarget.subscriptionExternalId}/${this.probeTarget.metricCode} carries no bulk traffic, so one probe is in flight at a time and each crossing is unambiguous.`,
        gates: ["usage_visible"],
      });
      {
        try {
          const { usage } = await currentUsage(
            this.probeTarget.customerExternalId,
            this.probeTarget.subscriptionExternalId,
          );
          const v = usageValue(usage, this.probeTarget.metricCode);
          this.usageBaseline = v.eventsCount;
          this.usageUnitsBaseline = v.units;
          this.usageExpected = this.usageBaseline;
          checks.push({
            name: "Usage baseline",
            ok: true,
            detail: `${this.probeTarget.metricCode} reads units=${v.units}, events_count=${v.eventsCount} at start of run`,
            gates: ["usage_visible"],
          });
        } catch (e) {
          checks.push({
            name: "Usage baseline",
            ok: false,
            detail: (e as Error).message,
            gates: ["usage_visible"],
          });
        }
      }
    } else {
      this.unavailable.add("usage_visible");
      this.log("info", "no usage probe target selected — usage latency will not be measured");
    }

    if (this.probeTarget && !this.unavailable.has("usage_visible")) {
      checks.push(await this.usageFreshnessCanary());
    }

    await this.measureClocks();
    checks.push({
      name: "Clock offsets",
      ok: true,
      detail:
        `lago ${fmtOff(this.clocks.lago)}, risingwave ${fmtOff(this.clocks.risingwave)}, ` +
        `clickhouse ${fmtOff(this.clocks.clickhouse)} (relative to this app)`,
      gates: ["stamped breakdown"],
    });

    const withFilters = this.plan.filter((p) => p.variant.chargeFilterId).length;
    const withGroups = this.plan.filter((p) => p.variant.groupLabel).length;
    checks.push({
      name: "Targets",
      ok: this.targets.length > 0,
      detail: `${this.targets.length} target(s), ${new Set(this.targets.map((t) => t.subscriptionExternalId)).size} subscription(s)`,
      gates: ["everything"],
    });
    checks.push({
      name: "Event spread",
      ok: this.plan.length > 0,
      detail:
        `${this.plan.length} event shape(s): ${withFilters} matching a charge filter, ` +
        `${this.plan.length - withFilters} default-bucket, ${withGroups} carrying pricing group keys` +
        (this.planTruncated > 0 ? ` — ${this.planTruncated} more capped by maxVariantsPerTarget` : ""),
      gates: ["everything"],
    });

    checks.push({
      name: "Guards",
      ok: this.spec.totalEvents <= this.spec.guards.hardCap,
      detail: `total ${this.spec.totalEvents} vs hard cap ${this.spec.guards.hardCap}; stop above ${this.spec.guards.maxErrorRatePct}% errors`,
      gates: ["everything"],
    });

    this.preflight = checks;
    const blocking = checks.filter((c) => !c.ok && c.gates.includes("everything"));
    const ok = blocking.length === 0 && lago.ok;
    if (!ok) {
      this.phase = "failed";
      this.log("error", `preflight failed: ${blocking.map((b) => b.name).join(", ") || "Lago API"}`);
    }
    writeFileSync(
      resolve(RUNS_DIR, this.id, "preflight.json"),
      JSON.stringify({ checks, clocks: this.clocks, config: redactedTables() }, null, 2) + "\n",
    );
    return ok;
  }

  /**
   * Send ONE event and see whether current_usage reflects it. This is the check
   * that would have saved the 2026-08-24 staging run: a cached read path does
   * not move while events arrive, so every usage "latency" in that run was one
   * cache refresh spread over the send window. Better to know before 1000 events
   * than to read a plausible-looking ramp afterwards.
   */
  private async usageFreshnessCanary(): Promise<PreflightCheck> {
    const t = this.probeTarget!;
    const budgetMs = Math.min(getConfig().measurement.probeTimeoutMs, 15_000);
    const before = this.usageUnitsBaseline;
    const variant = buildVariants(t, this.spec.spread).variants[0]!;
    const expected = before + unitsOfVariant(t, variant);
    const txid = `${this.prefix}canary`;
    const res = await postEvent({
      transaction_id: txid,
      external_subscription_id: t.subscriptionExternalId,
      code: t.metricCode,
      timestamp: Date.now() / 1000,
      properties: variant.properties,
    });
    if (!res.ok) {
      return {
        name: "Usage read path freshness",
        ok: false,
        detail: `canary event rejected: ${res.error ?? res.status}`,
        gates: ["usage_visible"],
      };
    }
    const deadline = Date.now() + budgetMs;
    let sawAt: number | null = null;
    while (Date.now() < deadline) {
      await sleep(getConfig().measurement.usagePollMs);
      try {
        const { usage } = await currentUsage(t.customerExternalId, t.subscriptionExternalId);
        const v = usageValue(usage, t.metricCode);
        if (v.units >= expected - 1e-9) {
          sawAt = Date.now();
          // Adopt the post-canary reading as the run's baseline.
          this.usageUnitsBaseline = v.units;
          this.usageBaseline = v.eventsCount;
          this.usageExpected = v.eventsCount;
          break;
        }
      } catch {
        /* counted by the poller's error handling during the run */
      }
    }
    if (sawAt) {
      return {
        name: "Usage read path freshness",
        ok: true,
        detail: `one event moved units ${before} → ${this.usageUnitsBaseline} in ${sawAt - res.sentAt}ms, so this read path is live`,
        gates: ["usage_visible"],
      };
    }
    this.usageStaleAtStart = true;
    return {
      name: "Usage read path freshness",
      ok: false,
      detail:
        `one event did NOT move units off ${before} within ${budgetMs}ms. current_usage is almost certainly served ` +
        "from the charge cache, which the legacy events consumer invalidates — so usage latency would measure cache " +
        "refreshes, not the pipeline. Set LAGO_RISINGWAVE_USAGE_ENABLED=true and check the charge is realtime-eligible " +
        "(count/sum, in arrears, non-prorated, non-recurring, no custom expression).",
      gates: ["usage_visible"],
    };
  }

  /**
   * Offsets are (remote_now - local_now), corrected for half the round trip. They
   * are reported, never silently applied: a stamped segment that spans two clocks
   * is only as good as these numbers.
   */
  private async measureClocks() {
    const probe = async (f: () => Promise<number>) => {
      try {
        const t0 = Date.now();
        const remote = await f();
        const t1 = Date.now();
        if (!remote) return null;
        return Math.round(remote - (t0 + t1) / 2);
      } catch {
        return null;
      }
    };
    const [rwOff, chOff] = await Promise.all([probe(rwNowMs), probe(chNowMs)]);
    let lagoOff: number | null = null;
    const lt = await lagoServerTimeMs();
    // The Date header is second-resolution, so this is ±1s by construction.
    if (lt) lagoOff = Math.round(lt.serverMs - (Date.now() - lt.rttMs / 2));
    this.clocks = { lago: lagoOff, risingwave: rwOff, clickhouse: chOff, measuredAt: Date.now() };
  }

  // ------------------------------------------------------------------ sending

  async start() {
    this.phase = "sending";
    this.startedAt = Date.now();
    this.log("info", `run ${this.id} started: ${this.spec.totalEvents} events at ${this.spec.rateEps}/s`);

    const cfg = getConfig().measurement;
    this.timers.push(setInterval(() => void this.pollVisibility(), cfg.pollTickMs));
    this.timers.push(setInterval(() => void this.sweepStamps(), cfg.sweepMs));
    this.timers.push(setInterval(() => void this.countStages(), Math.max(cfg.sweepMs, 2000)));

    const usageLoops =
      this.usageMode === "off"
        ? null
        : Promise.all([this.usagePollLoop(), ...(this.usageMode === "exact" ? [this.usageProbeLoop()] : [])]);
    await this.bulkLoop();

    this.phase = "draining";
    this.sendingDone = true; // stops NEW usage probes; the outstanding one may finish
    this.log("info", "sending done — draining in-flight probes");
    // Bounded: an outstanding usage probe gets a fair chance to land, but a
    // wedged read path must not hold the run open (it used to be raced against
    // 2s, so a probe that landed later was recorded after the summary was written).
    await Promise.all([
      withTimeout(usageLoops, Math.min(getConfig().measurement.probeTimeoutMs, 30_000)),
      this.drain(),
    ]);

    for (const t of this.timers) clearInterval(t);
    this.timers = [];
    await this.finalSweep();
    this.endedAt = Date.now();
    const failed = (this.phase as RunPhase) === "failed";
    if (!failed) this.phase = this.stopRequested ? "stopped" : "done";
    this.persist();
    this.log("info", `run ${this.id} ${this.phase}`);
  }

  stop() {
    this.stopRequested = true;
  }

  private async bulkLoop() {
    const spec = this.spec;
    const cap = Math.min(spec.totalEvents, spec.guards.hardCap);
    const maxInFlight = Math.min(128, Math.max(8, Math.ceil(spec.rateEps / 4)));
    let inFlight = 0;
    let seq = 0;
    const t0 = Date.now();

    while (seq < cap && !this.stopRequested) {
      const elapsed = (Date.now() - t0) / 1000;
      const planned = Math.min(cap, Math.floor(plannedBy(spec, elapsed)));
      while (seq < planned && inFlight < maxInFlight && !this.stopRequested) {
        const slot = this.plan[seq % this.plan.length]!;
        const n = seq++;
        inFlight++;
        void this.sendOne(
          slot.target,
          slot.variant,
          `${this.prefix}b${n}`,
          n,
          "bulk",
          spec.probeEvery > 0 && n % spec.probeEvery === 0,
        ).finally(() => {
          inFlight--;
        });
      }
      if (this.tripGuard()) break;
      await sleep(20);
    }
    // Let the last requests finish before we call sending over.
    const deadline = Date.now() + 15_000;
    while (inFlight > 0 && Date.now() < deadline) await sleep(50);
  }

  /** Serial probe stream: one outstanding usage probe at a time keeps attribution exact. */
  private async usageProbeLoop() {
    const t = this.probeTarget!;
    const cfg = getConfig().measurement;
    const probeVariants = buildVariants(t, this.spec.spread).variants;
    let n = 0;
    while (!this.stopRequested && !this.sendingDone) {
      const variant = probeVariants[n % probeVariants.length]!;
      const txid = `${this.prefix}p${n++}`;
      const rec = await this.sendOne(t, variant, txid, n, "probe", true);
      if (!rec?.ok) {
        await sleep(cfg.usagePollMs);
        continue;
      }
      // One event in flight, so the k-th watermark crossing IS this event.
      this.pushUsageExpectation(t, variant, rec.sentAt);
      this.usageExpected++;
      const mine = this.usagePairSentAt.length;
      const deadline = Date.now() + cfg.probeTimeoutMs;
      while (this.usageAttributed < mine && Date.now() < deadline && !this.stopRequested) {
        if (this.sendingDone && Date.now() - rec.sentAt > 30_000) break;
        await sleep(25);
      }
      if (this.usageAttributed >= mine) {
        rec.usageMs = (this.series.get("usage_visible")?.raw().at(-1) as number | undefined) ?? undefined;
      } else {
        this.counters.usageTimeouts++;
        this.log("warn", `usage probe ${txid} did not appear within ${cfg.probeTimeoutMs}ms`);
      }
    }
  }

  private pushUsageExpectation(target: Target, variant: EventVariant, sentAt: number) {
    const prev = this.usagePairCumUnits.at(-1) ?? 0;
    this.usagePairSentAt.push(sentAt);
    this.usagePairCumUnits.push(prev + unitsOfVariant(target, variant));
  }

  /**
   * One current_usage request. Attribution uses the MIDPOINT of send and receive
   * as the instant the count was observed: the server answered somewhere inside
   * that window, so the midpoint is the point estimate with the smallest
   * worst-case error (+/- RTT/2) — receive-time alone would inflate every usage
   * latency by a whole round trip.
   */
  private async pollUsageOnce(): Promise<void> {
    const t = this.probeTarget!;
    const t0 = Date.now();
    this.usagePolls.issued++;
    this.usagePolls.inFlight++;
    if (!this.usagePolls.firstAt) this.usagePolls.firstAt = t0;
    try {
      const { usage } = await currentUsage(t.customerExternalId, t.subscriptionExternalId);
      const t1 = Date.now();
      this.usagePolls.completed++;
      this.usagePolls.lastAt = t1;
      this.usageRtt.add(t1 - t0);
      const v = usageValue(usage, t.metricCode);
      const deltaUnits = v.units - this.usageUnitsBaseline;
      // How many of our events can this reading account for? The run knows the
      // exact unit total it has sent, so this is an exact question for sum and
      // count metrics. events_count is the fallback if units are not numeric.
      let byUnits = 0;
      const EPS = 1e-9;
      while (byUnits < this.usagePairCumUnits.length && this.usagePairCumUnits[byUnits]! <= deltaUnits + EPS) byUnits++;
      const byCount = v.eventsCount - this.usageBaseline;
      const observed = Number.isFinite(deltaUnits) && this.usagePairCumUnits.length > 0 ? byUnits : byCount;
      // Responses can land out of order; only ever advance the watermark.
      const upTo = Math.min(observed, this.usagePairSentAt.length);
      if (upTo <= this.usageAttributed) {
        // This poll did not advance the watermark, so it bounds the next
        // crossing from below. Keep the latest such start time.
        if (t0 > this.usageLastBelowT0) this.usageLastBelowT0 = t0;
        // Nothing moved although events are outstanding: candidate stale read.
        if (this.usagePairSentAt.length > this.usageAttributed) {
          this.usageStale.unchangedSincePolls++;
          if (!this.usageStale.unchangedSinceMs) this.usageStale.unchangedSinceMs = t1;
          const stuckFor = t1 - this.usageStale.unchangedSinceMs;
          if (this.usageStale.unchangedSincePolls === 25 || (stuckFor > 10_000 && this.usageStale.unchangedSincePolls % 100 === 0)) {
            this.log(
              "warn",
              `current_usage has not moved for ${Math.round(stuckFor / 1000)}s across ${this.usageStale.unchangedSincePolls} polls ` +
                `while ${this.usagePairSentAt.length - this.usageAttributed} event(s) are outstanding — ` +
                "the charge cache is probably serving this read (LAGO_RISINGWAVE_USAGE_ENABLED not true, or the charge is not realtime-eligible)",
            );
          }
        }
      } else {
        const lo = Math.min(this.usageLastBelowT0 || t0, t1);
        const observedAt = (lo + t1) / 2;
        this.usageBracket.add(Math.max(0, t1 - lo));
        const batch = upTo - this.usageAttributed;
        if (batch > this.usageStale.worstBatch) this.usageStale.worstBatch = batch;
        if (batch > 1) this.usageStale.batches++;
        while (this.usageAttributed < upTo) {
          const sentAt = this.usagePairSentAt[this.usageAttributed++]!;
          this.series.add("usage_visible", Math.max(0, observedAt - sentAt));
          this.counters.usageProbes++;
        }
        this.usageStale.unchangedSincePolls = 0;
        this.usageStale.unchangedSinceMs = 0;
        this.usageLastBelowT0 = t1;
      }
    } catch (e) {
      this.usagePolls.failed++;
      this.noteError(`current_usage: ${(e as Error).message}`);
    } finally {
      this.usagePolls.inFlight--;
    }
  }

  /**
   * Pipelined poller: issues a request every usagePollMs up to a concurrency
   * cap, instead of waiting for each response before starting the next. That
   * decouples the measurement's resolution from the endpoint's response time —
   * current_usage is a heavy read, and serial polling made the resolution
   * (interval + RTT) rather than just the interval.
   *
   * Drives BOTH attribution modes: watermark uses it directly, exact mode reads
   * the same watermark while additionally keeping one probe in flight, which is
   * what makes it exact.
   */
  private async usagePollLoop() {
    const cfg = getConfig().measurement;
    const maxInFlight = Math.max(1, cfg.usagePollConcurrency);
    const caughtUp = () => this.usageAttributed >= this.usagePairSentAt.length;
    let idleSince = 0;
    while (!this.stopRequested) {
      if (this.sendingDone && caughtUp()) break;
      if (this.sendingDone && !caughtUp()) {
        const last = this.usagePairSentAt.at(-1) ?? Date.now();
        if (Date.now() - last > cfg.probeTimeoutMs) {
          const missing = this.usagePairSentAt.length - this.usageAttributed;
          this.counters.usageTimeouts += missing;
          this.log("warn", `usage counter never reached ${missing} event(s) within the probe timeout`);
          break;
        }
      }
      // Nothing sent to the pair yet: idle politely rather than hammering.
      if (this.usagePairSentAt.length === 0) {
        idleSince = idleSince || Date.now();
        await sleep(cfg.usagePollMs);
        continue;
      }
      idleSince = 0;
      if (this.usagePolls.inFlight < maxInFlight) void this.pollUsageOnce();
      await sleep(cfg.usagePollMs);
    }
    // Let the last responses land so their samples are not lost.
    const deadline = Date.now() + 5_000;
    while (this.usagePolls.inFlight > 0 && Date.now() < deadline) await sleep(50);
  }

  private async sendOne(
    target: Target,
    variant: EventVariant,
    txid: string,
    seq: number,
    stream: "bulk" | "probe",
    isProbe: boolean,
  ): Promise<Rec | null> {
    const payload: EventPayload = {
      transaction_id: txid,
      external_subscription_id: target.subscriptionExternalId,
      code: target.metricCode,
      timestamp: Date.now() / 1000,
      properties: variant.properties,
    };
    const res = await postEvent(payload);
    const rec: Rec = {
      txid,
      seq,
      stream,
      targetId: target.id,
      metricCode: target.metricCode,
      subscriptionExternalId: target.subscriptionExternalId,
      isVisibilityProbe: isProbe && res.ok,
      sentAt: res.sentAt,
      apiMs: Math.round(res.apiMs * 1000) / 1000,
      ok: res.ok,
      status: res.status,
      seen: {},
      stamps: {},
      computed: new Set(),
    };
    this.recs.set(txid, rec);
    const slot = this.plan.find((p) => p.target.id === target.id && p.variant.key === variant.key);
    if (slot) slot.sent++;
    this.counters.sent++;
    this.rate.mark(nowSec(), !res.ok);
    if (res.ok) {
      this.counters.accepted++;
      if (
        this.usageMode === "watermark" &&
        this.probeTarget &&
        target.subscriptionExternalId === this.probeTarget.subscriptionExternalId &&
        target.metricCode === this.probeTarget.metricCode
      ) {
        this.pushUsageExpectation(target, variant, res.sentAt);
      }
      this.series.add("api_response", res.apiMs);
      if (isProbe) {
        this.counters.probes++;
        for (const s of this.enabledStages()) this.pending.get(s)!.add(txid);
      }
    } else {
      this.counters.failed++;
      this.noteError(`POST /events ${res.status}: ${res.error ?? "network"}`);
    }
    return rec;
  }

  private noteError(msg: string) {
    const key = msg.slice(0, 160);
    this.errors.set(key, (this.errors.get(key) ?? 0) + 1);
  }

  private tripGuard(): boolean {
    const { sent, failed } = this.counters;
    if (sent < 50) return false;
    const pct = (failed / sent) * 100;
    if (pct > this.spec.guards.maxErrorRatePct) {
      this.log("error", `error rate ${pct.toFixed(1)}% above ${this.spec.guards.maxErrorRatePct}% — stopping`);
      this.stopRequested = true;
      return true;
    }
    return false;
  }

  // ----------------------------------------------------------------- polling

  private async pollVisibility() {
    const now = Date.now();
    const cfg = getConfig().measurement;
    for (const stage of this.enabledStages()) {
      const set = this.pending.get(stage)!;
      if (set.size === 0) continue;
      const ids = [...set].slice(0, 200);
      try {
        if (isRwStage(stage)) {
          const rows = await rwSeen(stage, ids, this.caps(stage));
          for (const r of rows) {
            const rec = this.recs.get(r.txid);
            if (!rec) continue;
            this.markSeen(rec, stage, now);
            if (r.ingestedMs) rec.stamps.ingestedMs = r.ingestedMs;
            if (r.kafkaMs) rec.stamps.kafkaMs = r.kafkaMs;
            if (r.rwReceivedMs) rec.stamps.rwReceivedMs = r.rwReceivedMs;
            if (r.rwExpandedMs) rec.stamps.rwExpandedMs = r.rwExpandedMs;
            this.recomputeStamped(rec);
            set.delete(r.txid);
          }
        } else {
          const seen = await chSeen(stage as ChTableKey, ids, this.chScope());
          for (const [txid, at] of seen) {
            const rec = this.recs.get(txid);
            if (!rec) continue;
            this.markSeen(rec, stage, now);
            this.setChStamp(rec, stage, at);
            this.recomputeStamped(rec);
            set.delete(txid);
          }
        }
      } catch (e) {
        this.noteError(`poll ${stage}: ${(e as Error).message}`);
      }
      // Stop waiting on events that are never going to show up.
      for (const id of ids) {
        const rec = this.recs.get(id);
        if (rec && now - rec.sentAt > cfg.probeTimeoutMs) set.delete(id);
      }
    }
  }

  private markSeen(rec: Rec, stage: StageKey, now: number) {
    if (rec.seen[stage] != null) return;
    rec.seen[stage] = now;
    const key = VISIBLE_SEGMENT[stage];
    this.series.add(key, now - rec.sentAt);
  }

  private setChStamp(rec: Rec, stage: StageKey, at: number) {
    if (stage === "chRwEnriched") rec.stamps.chRwEnrichedMs ??= at;
    else if (stage === "chRwExpanded") rec.stamps.chRwExpandedMs ??= at;
    else if (stage === "chGoEnriched") rec.stamps.chGoEnrichedMs ??= at;
    else if (stage === "chGoExpanded") rec.stamps.chGoExpandedMs ??= at;
  }

  /** Stamp sweeps cover EVERY event, not just probes, watermarked so cost stays flat. */
  private async sweepStamps() {
    for (const stage of this.enabledStages()) {
      const wmKey = `sweep:${stage}`;
      const since = this.sweepWatermark.get(wmKey) ?? this.startedAt - 5_000;
      try {
        if (isRwStage(stage)) {
          const caps = this.caps(stage);
          if (!caps.rw && !caps.expanded) continue;
          const rows = await rwSweep(stage, this.prefix, since, caps);
          let max = since;
          for (const r of rows) {
            const rec = this.recs.get(r.txid);
            const wm = caps.expanded ? r.rwExpandedMs : r.rwReceivedMs;
            if (wm && wm > max) max = wm;
            if (!rec) continue;
            if (r.ingestedMs) rec.stamps.ingestedMs ??= r.ingestedMs;
            if (r.kafkaMs) rec.stamps.kafkaMs ??= r.kafkaMs;
            if (r.rwReceivedMs) rec.stamps.rwReceivedMs ??= r.rwReceivedMs;
            if (r.rwExpandedMs) rec.stamps.rwExpandedMs ??= r.rwExpandedMs;
            this.recomputeStamped(rec);
          }
          this.sweepWatermark.set(wmKey, max);
        } else {
          const rows = await chSweep(stage as ChTableKey, this.prefix, since, this.chScope());
          let max = since;
          for (const r of rows) {
            if (r.at > max) max = r.at;
            const rec = this.recs.get(r.txid);
            if (!rec) continue;
            this.setChStamp(rec, stage, r.at);
            this.recomputeStamped(rec);
          }
          this.sweepWatermark.set(wmKey, max);
        }
      } catch (e) {
        this.noteError(`sweep ${stage}: ${(e as Error).message}`);
      }
    }
  }

  private async countStages() {
    for (const stage of this.enabledStages()) {
      try {
        this.stageCounts[stage] = isRwStage(stage)
          ? await rwCount(stage, this.prefix)
          : await chCount(stage as ChTableKey, this.prefix, this.chScope());
      } catch (e) {
        this.noteError(`count ${stage}: ${(e as Error).message}`);
      }
    }
  }

  private recomputeStamped(rec: Rec) {
    const s = rec.stamps;
    const put = (key: string, a?: number, b?: number) => {
      if (a == null || b == null || rec.computed.has(key)) return;
      rec.computed.add(key);
      this.series.add(key, b - a);
    };
    put("ingest_to_broker", s.ingestedMs, s.kafkaMs);
    put("broker_to_rw", s.kafkaMs, s.rwReceivedMs);
    put("rw_to_ch", s.rwReceivedMs, s.chRwEnrichedMs);
    put("rw_enrich_to_expand", s.rwReceivedMs, s.rwExpandedMs);
    put("rw_expand_to_ch", s.rwExpandedMs, s.chRwExpandedMs);
    put("ingest_to_ch_rw_enriched", s.ingestedMs, s.chRwEnrichedMs);
    put("ingest_to_ch_rw_expanded", s.ingestedMs, s.chRwExpandedMs);
    put("ingest_to_ch_go_enriched", s.ingestedMs, s.chGoEnrichedMs);
    put("ingest_to_ch_go_expanded", s.ingestedMs, s.chGoExpandedMs);
  }

  /** After sending stops, keep polling until probes land or the timeout expires. */
  private async drain() {
    const cfg = getConfig().measurement;
    const deadline = Date.now() + cfg.probeTimeoutMs;
    const count = () => this.enabledStages().reduce((n, s) => n + this.pending.get(s)!.size, 0);
    let last = count();
    let lastProgress = Date.now();
    while (Date.now() < deadline) {
      const now = count();
      if (now === 0) return;
      if (now < last) {
        last = now;
        lastProgress = Date.now();
      }
      // A stage that errors on every poll never drains; waiting out the full
      // probe timeout for it just makes the run look hung.
      if (Date.now() - lastProgress > 15_000) {
        const stuck = this.enabledStages().filter((s) => this.pending.get(s)!.size > 0);
        this.log("warn", `giving up on ${now} probe(s) with no progress for 15s: ${stuck.join(", ")}`);
        for (const s of stuck) {
          if ((this.series.get(VISIBLE_SEGMENT[s])?.size ?? 0) === 0) this.unavailable.add(VISIBLE_SEGMENT[s]);
        }
        return;
      }
      await sleep(cfg.pollTickMs);
    }
    this.log("warn", `drain timed out with ${count()} probe(s) outstanding`);
  }

  private async finalSweep() {
    await this.sweepStamps().catch(() => {});
    await this.countStages().catch(() => {});
  }

  // --------------------------------------------------------------- reporting

  snapshot() {
    const elapsedMs = (this.endedAt || Date.now()) - (this.startedAt || Date.now());
    return {
      id: this.id,
      prefix: this.prefix,
      phase: this.phase,
      spec: this.spec,
      startedAt: this.startedAt,
      endedAt: this.endedAt,
      elapsedMs,
      counters: { ...this.counters, pendingProbes: this.enabledStages().reduce((n, s) => n + this.pending.get(s)!.size, 0) },
      stageCounts: this.stageCounts,
      stats: this.series.snapshot(),
      histograms: this.series.histograms(),
      rate: this.rate.series(),
      clocks: this.clocks,
      preflight: this.preflight,
      unavailable: [...this.unavailable],
      errors: [...this.errors.entries()].map(([msg, count]) => ({ msg, count })).sort((a, b) => b.count - a.count),
      logs: this.logs.slice(-80),
      usageMode: this.usageMode,
      usageFreshness: (() => {
        const attributed = this.usageAttributed;
        const worst = this.usageStale.worstBatch;
        // If one reading accounted for a large share of the run at once, the
        // percentiles describe a refresh, not per-event latency.
        const batchShare = attributed > 0 ? worst / attributed : 0;
        return {
          staleAtStart: this.usageStaleAtStart,
          worstBatch: worst,
          batches: this.usageStale.batches,
          batchShare: Math.round(batchShare * 1000) / 1000,
          stalePolls: this.usageStale.unchangedSincePolls,
          verdict:
            attributed === 0
              ? "unknown"
              : batchShare >= 0.25 || (worst > 20 && this.usageStale.batches <= 3)
                ? "batched"
                : worst > 5
                  ? "coarse"
                  : "incremental",
        };
      })(),
      usagePoll: (() => {
        const { issued, completed, failed, inFlight, firstAt, lastAt } = this.usagePolls;
        const spanMs = firstAt && lastAt > firstAt ? lastAt - firstAt : 0;
        const rtt = this.usageRtt.percentiles();
        const bracket = this.usageBracket.percentiles();
        return {
          issued,
          completed,
          failed,
          inFlight,
          perSecond: spanMs ? Math.round((completed / spanMs) * 1000 * 10) / 10 : 0,
          rttP50: rtt?.p50 ?? null,
          rttP95: rtt?.p95 ?? null,
          // Half the bracket each crossing was pinned inside: the actual
          // uncertainty of a usage sample, measured rather than assumed.
          resolutionMs: bracket ? Math.round(bracket.p50 / 2) : null,
          bracketP95Ms: bracket ? Math.round(bracket.p95) : null,
        };
      })(),
      probeTarget: this.probeTarget
        ? {
            subscription: this.probeTarget.subscriptionExternalId,
            metric: this.probeTarget.metricCode,
            baseline: this.usageBaseline,
            expected: this.usageMode === "watermark" ? this.usagePairSentAt.length : this.usageExpected,
            attributed: this.usageAttributed,
          }
        : null,
      targets: this.targets.map((t) => ({
        id: t.id,
        subscription: t.subscriptionExternalId,
        metric: t.metricCode,
        aggregation: t.aggregationType,
        filters: t.filters.length,
        groupKeys: t.groupKeys,
      })),
      spread: this.plan.map((p) => ({
        target: `${p.target.subscriptionExternalId}/${p.target.metricCode}`,
        label: p.variant.label,
        kind: p.variant.chargeFilterId ? "filter" : "default",
        grouped: Boolean(p.variant.groupLabel),
        properties: p.variant.properties,
        sent: p.sent,
      })),
      spreadTruncated: this.planTruncated,
    };
  }

  persist() {
    const dir = resolve(RUNS_DIR, this.id);
    writeFileSync(resolve(dir, "summary.json"), JSON.stringify(this.snapshot(), null, 2) + "\n");
    const lines: string[] = [];
    for (const r of this.recs.values()) {
      lines.push(
        JSON.stringify({
          txid: r.txid,
          stream: r.stream,
          target: r.targetId,
          ok: r.ok,
          status: r.status,
          sentAt: r.sentAt,
          apiMs: r.apiMs,
          seen: r.seen,
          stamps: r.stamps,
          usageMs: r.usageMs,
        }),
      );
    }
    appendFileSync(this.eventsFile, lines.join("\n") + (lines.length ? "\n" : ""));
  }
}

const VISIBLE_SEGMENT: Record<StageKey, string> = {
  rwEnriched: "rw_enriched_visible",
  rwExpanded: "rw_expanded_visible",
  chRwEnriched: "ch_rw_enriched_visible",
  chRwExpanded: "ch_rw_expanded_visible",
  chGoEnriched: "ch_go_enriched_visible",
  chGoExpanded: "ch_go_expanded_visible",
};

const fmtOff = (v: number | null) => (v == null ? "unknown" : `${v >= 0 ? "+" : ""}${v}ms`);
const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
const withTimeout = (p: Promise<unknown> | null, ms: number) =>
  p ? Promise.race([p, sleep(ms)]) : Promise.resolve();

function redactedTables() {
  const c = getConfig();
  return { risingwave: c.risingwave, clickhouse: { ...c.clickhouse, password: "***" }, measurement: c.measurement };
}
