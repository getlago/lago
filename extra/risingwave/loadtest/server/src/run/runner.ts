import { randomBytes } from "node:crypto";
import { mkdirSync, writeFileSync, appendFileSync } from "node:fs";
import { resolve } from "node:path";
import { getConfig, RUNS_DIR } from "../config.js";
import type { Target } from "../discovery.js";
import { buildVariants, centsOfVariant, unitsOfVariant, type EventVariant } from "../variants.js";
import {
  currentUsage,
  customerWallets,
  fetchOrganization,
  MAX_EVENT_BATCH,
  usageValue,
  walletReading,
  lagoHealth,
  lagoServerTimeMs,
  type EventPayload,
  type SendResult,
  type WalletReading,
} from "../clients/lago.js";
import { MAX_KAFKA_BATCH, sendEvents, type Transport } from "../clients/events.js";
import { disconnectProducer, redpandaHealth, type RawEventEnvelope } from "../clients/redpanda.js";
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
import { CrossingTracker, PollStats } from "./crossing.js";
import { RateTracker, SeriesSet } from "./stats.js";
import type { ClockOffsets, RunPhase, RunSpec, StageKey } from "../types.js";

const RW_STAGES: RwTableKey[] = ["rwEnriched", "rwExpanded"];
const CH_STAGES: ChTableKey[] = ["chRwEnriched", "chRwExpanded", "chGoEnriched", "chGoExpanded"];
const isRwStage = (s: StageKey): s is RwTableKey => (RW_STAGES as StageKey[]).includes(s);

/** One event queued for a request, before it has a response to be recorded with. */
type SendEntry = {
  target: Target;
  variant: EventVariant;
  txid: string;
  seq: number;
  stream: "bulk" | "probe";
  isProbe: boolean;
};

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
  walletMs?: number;
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

/**
 * A wallet's ongoing usage reads back as a WHOLE number of cents, so a canary
 * event worth a fraction of one cannot be observed to land at all: the balance
 * rounds back to where it started and the check times out blaming the pipeline
 * for a resolution problem. The canary is scaled until it is worth at least
 * this much, which also keeps it clear of the cent of rounding that tax and the
 * wallet's rate_amount can eat.
 */
const WALLET_CANARY_MIN_CENTS = 5;

/** Trailing window the error-rate stop guard judges the send path on. */
const GUARD_WINDOW_SEC = 10;
/** Below this many sends in the window the ratio is too noisy to act on. */
const GUARD_MIN_SAMPLES = 50;

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
  /** Smoothed POST round trip, in ms. Seeds the in-flight budget before the
   * first response lands, then tracks it: throughput IS in-flight / round trip,
   * so the budget has to follow the round trip actually being observed. */
  private apiEwmaMs = 200;
  private pending = new Map<StageKey, Set<string>>();
  private sweepWatermark = new Map<string, number>();
  private counters = {
    sent: 0,
    accepted: 0,
    failed: 0,
    probes: 0,
    usageProbes: 0,
    usageTimeouts: 0,
    walletProbes: 0,
    walletTimeouts: 0,
  };
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
  /**
   * Everything a direct produce has to stamp that the API would have stamped:
   * the organization UUID the whole pipeline joins on, the `source`, and
   * `api_post_processed`. Resolved from Lago in preflight, so it is read rather
   * than guessed. Null on the API transport, where Lago stamps them itself.
   */
  private envelope: RawEventEnvelope | null = null;
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
  private usage = new CrossingTracker();
  private usageUnitsBaseline = 0;
  /** Set when the preflight canary proved the read path was not live. */
  usageStaleAtStart = false;
  private usagePolls = new PollStats();

  /**
   * Wallet attribution. `GET /wallets` exposes no per-event handle either — only
   * `ongoing_usage_balance_cents`, which this run is the sole writer of.
   *
   *  exact     the wallet's customer receives no bulk traffic and its events come
   *            from the serial usage probe, so exactly one event is outstanding
   *            and the n-th increase IS the n-th event. Needs no price at all.
   *
   *  watermark the customer also carries bulk traffic AND every shape sent to it
   *            is priced linearly (standard charge), so the run can predict the
   *            cents the reading must reach after k events — the same arithmetic
   *            as the usage watermark, one calibration factor apart.
   *
   *  refresh   the customer carries bulk traffic and at least one shape is not
   *            linearly priced (graduated, package, percentage, volume). Each
   *            observed refresh is then timed against the oldest outstanding
   *            event, which is an UPPER bound: a refresh coalesces every event
   *            whose bucket had landed, so the ones behind it were already
   *            covered and are charged for the next refresh instead.
   */
  walletMode: "exact" | "watermark" | "refresh" | "off" = "off";
  private wallet = new CrossingTracker();
  private walletPolls = new PollStats();
  private walletBaselineCents = 0;
  /**
   * Predicted cents are pre-tax, in plan currency; the reading is post-tax, in
   * wallet currency, divided by the wallet's rate. One factor measured on a real
   * event by the canary absorbs all of that, so nothing has to be modelled.
   */
  private walletCentsFactor = 1;
  private walletPerEventCents: number | null = null;
  private walletCanaryDetail = "";
  /** Distinct increases of the reading: in exact mode, one per event. */
  private walletIncreases = 0;
  private walletLastValue = Number.NEGATIVE_INFINITY;
  /** Refreshes counted from last_ongoing_balance_sync_at, when Lago exposes it. */
  private walletRefreshes = 0;
  private walletSyncStampSeen = false;
  private walletLastSyncMs = 0;
  walletStaleAtStart = false;
  /**
   * True when the wallet probe and the usage probe are the same target, so both
   * trackers record the SAME events in the same order and index i means one
   * event on both sides — which is what makes the per-event usage → wallet split
   * meaningful rather than a difference of unrelated percentiles.
   */
  private walletAligned = false;
  private usageLatency: number[] = [];
  private walletLatency: number[] = [];
  private pairEmitted = new Set<number>();
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
    readonly walletTarget: Target | null = null,
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
    const all = [
      ...this.targets,
      ...(this.probeTarget ? [this.probeTarget] : []),
      ...(this.walletTarget ? [this.walletTarget] : []),
    ];
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

    checks.push(...(await this.transportPreflight()));

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

    checks.push(...(await this.walletPreflight()));

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
      // No size ceiling: a load test that refuses to run big is useless. The
      // only guard left is the windowed error-rate stop, and 0 disables it.
      ok: true,
      detail:
        `total ${this.spec.totalEvents} events, no size cap; ` +
        (this.spec.guards.maxErrorRatePct > 0
          ? `stop above ${this.spec.guards.maxErrorRatePct}% errors over ${GUARD_WINDOW_SEC}s`
          : "error-rate stop disabled"),
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
   * What the send path is, and — on the kafka transport — everything a direct
   * produce has to reproduce that the API would otherwise have done.
   *
   * Three things are checked rather than assumed:
   *
   *  1. the broker is reachable AND the topic exists. Auto-creation is off, so a
   *     typo would otherwise produce happily into a topic no consumer reads,
   *     and every stage would report "nothing arrived" with no reason why.
   *  2. the organization UUID, read from Lago. It is the join key the whole
   *     pipeline resolves subscriptions, charges and filters on; a wrong one
   *     produces valid JSON that enriches into nothing.
   *  3. what the API does that Kafka cannot. For a Postgres events store the API
   *     also writes the `events` row and runs PostProcessJob, so any read path
   *     not served by the realtime buckets will not move for these events — and
   *     that has to be said BEFORE the run, not discovered as flat usage after.
   */
  private async transportPreflight(): Promise<PreflightCheck[]> {
    if (this.transport !== "kafka") {
      return [
        {
          name: "Send transport",
          ok: true,
          detail:
            "Lago API (POST /events). Every latency below includes Lago's ingest cost, and the achievable rate is " +
            "capped by its round trip — switch to direct produce to push past that.",
          gates: ["everything"],
        },
      ];
    }

    const checks: PreflightCheck[] = [];
    const k = getConfig().kafka;

    let organizationId = k.organizationId.trim();
    let apiPostProcessed = true;
    let orgDetail = "";
    try {
      const org = await fetchOrganization();
      const clickhouseStore = org.events_store === "clickhouse";
      apiPostProcessed = !clickhouseStore;
      if (!organizationId) organizationId = org.lago_id;
      orgDetail =
        `${org.name} ${organizationId}` +
        (k.organizationId.trim() ? " (overridden in Setup)" : " (read from GET /organizations)") +
        `, events store ${org.events_store ?? "unknown"} → source_metadata.api_post_processed=${apiPostProcessed}`;
      checks.push({
        name: "Organization (direct produce)",
        ok: Boolean(organizationId),
        detail: organizationId ? orgDetail : "no organization id — the pipeline joins on it, so nothing would enrich",
        gates: ["everything"],
      });
      if (!clickhouseStore) {
        checks.push({
          name: "What direct produce skips",
          ok: true,
          detail:
            "this organization stores events in POSTGRES, so the API would also have written the events row and run " +
            "PostProcessJob. A direct produce does neither: the RisingWave and ClickHouse stages are unaffected, but " +
            "any current_usage read NOT served by the realtime 15-minute buckets has nothing to read. Check the " +
            "freshness canary below before trusting the usage and wallet numbers.",
          gates: ["usage_visible", "wallet_visible"],
        });
      }
    } catch (e) {
      checks.push({
        name: "Organization (direct produce)",
        ok: Boolean(organizationId),
        detail: organizationId
          ? `using the id configured in Setup; GET /organizations failed (${(e as Error).message}), so api_post_processed defaults to true`
          : `GET /organizations failed and no organization id is configured in Setup: ${(e as Error).message}`,
        gates: ["everything"],
      });
    }

    const health = await redpandaHealth();
    checks.push({
      name: "Redpanda (direct produce)",
      ok: health.ok,
      detail: health.ok
        ? `${health.topic} has ${health.partitions} partition(s); cluster ${health.clusterId ?? "?"} advertises ${health.brokers}`
        : `${health.error} (configured brokers: ${k.brokers || "none"})` +
          (health.brokers ? ` — the cluster advertises ${health.brokers}, which is what a client actually dials` : ""),
      gates: ["everything"],
    });

    if (health.ok && organizationId) {
      this.envelope = { organizationId, source: k.source || "http_ruby", apiPostProcessed };
    }
    checks.push({
      name: "Send transport",
      ok: Boolean(this.envelope),
      detail: this.envelope
        ? `DIRECT PRODUCE to ${k.topic}, ${
            k.partitionKey === "subscription"
              ? "keyed by <organization_id>-<external_subscription_id> (so this run reaches at most " +
                `${new Set(this.targets.map((x) => x.subscriptionExternalId)).size} of the topic's partitions)`
              : "UNKEYED, round-robin over every partition"
          }, acks=${k.acks}` +
          `${k.compression === "none" ? "" : `, ${k.compression}`}, source=${this.envelope.source}. The Lago API is out of ` +
          "the send path, so \"API response\" below is the broker ack and ingested_at is stamped by this app." +
          (k.acks === 0 ? " acks=0: nothing is acked, so a rejected batch cannot be reported and the ack latency is local only." : "")
        : "direct produce requested but not initialised — see the checks above",
      gates: ["everything"],
    });
    return checks;
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
    const res = await this.send([
      {
        transaction_id: txid,
        external_subscription_id: t.subscriptionExternalId,
        code: t.metricCode,
        timestamp: Date.now() / 1000,
        properties: variant.properties,
      },
    ]);
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

  // ------------------------------------------------------------ wallet preflight

  /**
   * Decide what the wallet measurement can honestly claim, before a single bulk
   * event is sent. Three things have to line up: the customer must hold an
   * active wallet, some traffic must reach that customer, and the refresh path
   * has to actually be running — and each of them fails in a way that looks like
   * "the wallet is just slow" if it is not named up front.
   */
  private async walletPreflight(): Promise<PreflightCheck[]> {
    const checks: PreflightCheck[] = [];
    const gates = ["wallet_visible", "usage_to_wallet"];
    const off = (detail: string, ok = false): PreflightCheck[] => {
      this.walletMode = "off";
      for (const g of gates) this.unavailable.add(g);
      return [{ name: "Wallet probe", ok, detail, gates }];
    };

    const t = this.walletTarget;
    if (!t) {
      return off(
        "no wallet probe target selected — the run will not measure the wallet ongoing balance. " +
          "Pick a target whose customer holds an active wallet on the Targets tab.",
        true,
      );
    }
    if (t.wallets.length === 0) {
      return off(`customer ${t.customerExternalId} holds no active wallet, so there is no ongoing balance to watch`);
    }

    // Which of this run's traffic can move this wallet at all?
    const feeds = this.targets.filter((x) => x.customerExternalId === t.customerExternalId);
    const probeFeeds = this.probeTarget?.customerExternalId === t.customerExternalId;
    if (feeds.length === 0 && !probeFeeds) {
      return off(
        `nothing in this run sends events to ${t.customerExternalId}, so its wallet cannot move. ` +
          "Select a bulk target for that customer, or point the usage probe at it.",
      );
    }

    // Alignment: every event that can move this wallet goes to the usage probe's
    // own pair. That is what makes the per-event usage → wallet split a
    // comparison of one event with itself rather than of two distributions.
    this.walletAligned = Boolean(
      this.probeTarget &&
        probeFeeds &&
        feeds.every(
          (x) =>
            x.subscriptionExternalId === this.probeTarget!.subscriptionExternalId &&
            x.metricCode === this.probeTarget!.metricCode,
        ),
    );
    if (!this.walletAligned) this.unavailable.add("usage_to_wallet");

    // Priceable? Only a standard charge is linear in units, and only a linear
    // charge lets the run predict the reading after k events.
    const walletPlan = this.plan.filter((slot) => slot.target.customerExternalId === t.customerExternalId);
    const priced = walletPlan.map((slot) => centsOfVariant(slot.target, slot.variant));
    const unpriceable = walletPlan.filter((_, i) => priced[i] == null);
    const serial = this.walletAligned && this.usageMode === "exact";
    this.walletMode = serial ? "exact" : unpriceable.length === 0 && priced.length > 0 ? "watermark" : "refresh";
    this.walletPerEventCents = priced.reduce<number | null>(
      (min, c) => (c == null || c <= 0 ? min : min == null ? c : Math.min(min, c)),
      null,
    );

    checks.push({
      name: "Wallet attribution",
      ok: true,
      detail:
        this.walletMode === "exact"
          ? `EXACT mode: ${t.customerExternalId} receives only the serial usage probe, so exactly one event is ` +
            "outstanding and the n-th increase of the ongoing balance IS the n-th event. No price is needed."
          : this.walletMode === "watermark"
            ? `WATERMARK mode: ${t.customerExternalId} also carries bulk traffic, and every shape sent to it is priced ` +
              `linearly (standard charge), so the cents the reading must reach after k events is predictable — ` +
              "calibrated on a real event below. Every event yields a sample."
            : `REFRESH mode: ${t.customerExternalId} carries bulk traffic and ${unpriceable.length} shape(s) are not ` +
              "linearly priced (only standard charges are), so each observed refresh is timed against the oldest " +
              "outstanding event. That is an UPPER bound: a refresh covers every event whose bucket had landed, so the " +
              "events behind it are charged to the next refresh instead of to this one.",
      gates,
    });

    const restricted = t.wallets.filter((w) => w.metricCodes.length > 0 && !w.metricCodes.includes(t.metricCode));
    if (restricted.length > 0 && restricted.length === t.wallets.length) {
      return off(
        `every active wallet of ${t.customerExternalId} is restricted to metrics ${[
          ...new Set(restricted.flatMap((w) => w.metricCodes)),
        ].join(", ")}, which excludes ${t.metricCode} — its ongoing balance can never move for these events`,
      );
    }

    try {
      const { wallets } = await customerWallets(t.customerExternalId);
      const r = walletReading(wallets);
      this.walletBaselineCents = r.ongoingUsageCents;
      this.walletLastValue = r.ongoingUsageCents;
      this.walletLastSyncMs = r.syncedAtMs ?? 0;
      this.walletSyncStampSeen = r.syncedAtMs != null;
      checks.push({
        name: "Wallet baseline",
        ok: true,
        detail:
          `${r.wallets} active wallet(s) read ongoing usage ${r.ongoingUsageCents} cents, ongoing balance ` +
          `${r.ongoingBalanceCents} cents at start of run` +
          (r.syncedAtMs == null
            ? " — this Lago does not serialize last_ongoing_balance_sync_at, so refreshes are counted from amount changes only"
            : ""),
        gates,
      });
    } catch (e) {
      return off(`wallet baseline could not be read: ${(e as Error).message}`);
    }

    checks.push(await this.walletFreshnessCanary());
    return checks;
  }

  /**
   * Poll until the ongoing balance stops moving, and return where it settled.
   * Bounded: a wallet that genuinely never settles is not worth waiting for, and
   * the canary that follows will say so.
   */
  private async settleWallet(customerExternalId: string): Promise<number> {
    const cfg = getConfig().measurement;
    const deadline = Date.now() + 5_000;
    let last = this.walletBaselineCents;
    let stable = 0;
    while (Date.now() < deadline && stable < 4) {
      await sleep(cfg.walletPollMs);
      try {
        const { wallets } = await customerWallets(customerExternalId);
        const v = walletReading(wallets).ongoingUsageCents;
        stable = v === last ? stable + 1 : 0;
        last = v;
      } catch {
        stable = 0;
      }
    }
    this.walletBaselineCents = last;
    this.walletLastValue = last;
    return last;
  }

  /**
   * Fatten ONE canary event until its predicted movement clears the wallet's
   * integer-cent resolution.
   *
   * Only the canary is scaled, never the bulk plan: bulk variants carry exactly
   * one unit per event, which is what makes the run's expected unit total exact
   * and its usage attribution checkable. The canary is a single calibration
   * event and its units are carried into `predicted` either way, so scaling it
   * costs the measurement nothing.
   *
   * A count metric adds one unit per event by definition and cannot be scaled
   * by fattening a property — it needs a dearer charge or several events, which
   * the failure detail says. Same for a variant with no priced field.
   */
  private scaleCanaryVariant(t: Target, v: EventVariant): EventVariant {
    const field = t.fieldName?.trim();
    const per = centsOfVariant(t, v);
    if (!field || t.aggregationType === "count_agg" || per == null || per <= 0) return v;
    const factor = Math.ceil(WALLET_CANARY_MIN_CENTS / per);
    if (factor <= 1) return v;
    return {
      ...v,
      properties: { ...v.properties, [field]: String(unitsOfVariant(t, v) * factor) },
    };
  }

  /**
   * Send ONE event and watch the wallet, for the same reason the usage canary
   * exists: a wallet path that is not wired up (no refresh consumer, a wallet
   * restricted away from this metric, triggers not sinking) does not fail — it
   * silently produces "latencies" that are really the clock sweep, or nothing at
   * all after a long wait.
   *
   * It doubles as the calibration for WATERMARK mode. Predicted cents are
   * pre-tax, in plan currency, per event; the reading is a rounded post-tax total
   * in wallet currency divided by the wallet's rate. Measuring one real event and
   * keeping the ratio absorbs every one of those conversions, so none of them has
   * to be modelled — and a ratio far from 1 is itself worth seeing.
   */
  private async walletFreshnessCanary(): Promise<PreflightCheck> {
    const t = this.walletTarget!;
    const gates = ["wallet_visible", "usage_to_wallet"];
    const budgetMs = Math.min(getConfig().measurement.probeTimeoutMs, 20_000);
    // Let anything already in flight land first — the usage canary ran moments
    // ago on the same customer, and its refresh arriving during this one would
    // make a stranger's event look like the calibration event.
    const before = await this.settleWallet(t.customerExternalId);
    const base = buildVariants(t, this.spec.spread).variants[0]!;
    const variant = this.scaleCanaryVariant(t, base);
    const predicted = centsOfVariant(t, variant);
    const scaledFrom = variant === base ? null : centsOfVariant(t, base);
    const res = await this.send([
      {
        transaction_id: `${this.prefix}wcanary`,
        external_subscription_id: t.subscriptionExternalId,
        code: t.metricCode,
        timestamp: Date.now() / 1000,
        properties: variant.properties,
      },
    ]);
    if (!res.ok) {
      return { name: "Wallet refresh path", ok: false, detail: `canary event rejected: ${res.error ?? res.status}`, gates };
    }

    const deadline = Date.now() + budgetMs;
    let seenAt = 0;
    let observed = 0;
    while (Date.now() < deadline) {
      await sleep(getConfig().measurement.walletPollMs);
      try {
        const { wallets } = await customerWallets(t.customerExternalId);
        const r = walletReading(wallets);
        if (r.ongoingUsageCents > before) {
          seenAt = Date.now();
          observed = r.ongoingUsageCents - before;
          // Adopt the post-canary reading as the run's baseline, so the canary's
          // own movement can never be attributed to the first bulk event.
          this.walletBaselineCents = r.ongoingUsageCents;
          this.walletLastValue = r.ongoingUsageCents;
          this.walletLastSyncMs = r.syncedAtMs ?? this.walletLastSyncMs;
          break;
        }
      } catch {
        /* counted by the poller's error handling during the run */
      }
    }

    if (!seenAt) {
      this.walletStaleAtStart = true;
      const tooSmall = predicted != null && predicted < 1;
      this.walletCanaryDetail = "no movement";
      return {
        name: "Wallet refresh path",
        ok: false,
        detail:
          `the canary event did NOT move the ongoing usage balance off ${before} cents within ${budgetMs}ms. ` +
          (tooSmall
            ? `It is worth ~${predicted!.toFixed(3)} cents, which rounds to nothing against a balance read in whole ` +
              `cents, and it could not be scaled up: ${
                t.aggregationType === "count_agg"
                  ? `${t.metricCode} is a count metric, so every event is worth exactly one unit`
                  : "this variant has no priced field to fatten"
              }. Point the wallet probe at a sum metric, or raise the charge price so one event clears a cent.`
            : "Check that the wallet refresh consumer is running (LAGO_KAFKA_WALLET_REFRESH_TRIGGERS_TOPIC set and " +
              "karafka consuming wallet_refresh_triggers), that the RisingWave wallet_refresh_triggers_sink exists, and " +
              "that current_usage itself is live — the refresh reads usage, so a dead usage path is a dead wallet path."),
        gates,
      };
    }

    if (this.walletMode === "watermark" && predicted && predicted > 0) {
      this.walletCentsFactor = observed / predicted;
    }
    this.walletCanaryDetail =
      `${observed} cents in ${seenAt - res.sentAt}ms` +
      (predicted ? ` (predicted ${predicted.toFixed(2)} pre-tax, factor ${(observed / predicted).toFixed(3)})` : "");
    return {
      name: "Wallet refresh path",
      ok: true,
      detail:
        `the canary moved the ongoing usage balance by ${observed} cents in ${seenAt - res.sentAt}ms, so the trigger → ` +
        "consumer → refresh path is live" +
        (scaledFrom != null
          ? `. It was scaled to ~${predicted!.toFixed(2)} cents (one plain event of this shape is worth ` +
            `${scaledFrom.toFixed(3)}, below the wallet's whole-cent resolution)`
          : "") +
        (this.walletMode === "watermark" && predicted
          ? `. Predicted ${predicted.toFixed(2)} cents pre-tax, so the calibration factor is ` +
            `${this.walletCentsFactor.toFixed(3)} (taxes, currency subunit and the wallet's rate, measured rather than modelled)`
          : ""),
      gates,
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
    const walletLoop = this.walletMode === "off" ? null : this.walletPollLoop();
    await this.bulkLoop();

    this.phase = "draining";
    this.sendingDone = true; // stops NEW usage probes; the outstanding one may finish
    this.log("info", "sending done — draining in-flight probes");
    // Bounded: an outstanding usage probe gets a fair chance to land, but a
    // wedged read path must not hold the run open (it used to be raced against
    // 2s, so a probe that landed later was recorded after the summary was written).
    const readPathBudget = Math.min(getConfig().measurement.probeTimeoutMs, 30_000);
    await Promise.all([
      withTimeout(usageLoops, readPathBudget),
      withTimeout(walletLoop, readPathBudget),
      this.drain(),
    ]);

    // With acks > 0 every send has already been acked, but acks=0 only queues
    // the write — so the producer is flushed (and its socket released) once no
    // loop can still be sending, and before anything is declared missing.
    if (this.transport === "kafka") await disconnectProducer().catch(() => {});
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

  /**
   * How many requests may be outstanding at once.
   *
   * Little's law is the whole story of this loadtest's send ceiling: the rate a
   * sender achieves is its in-flight request count divided by the round trip.
   * Against a remote Lago at ~160ms that means 128 outstanding requests cap out
   * near 800 events/s no matter what rate the run asks for — which is why this
   * is derived from the rate and the round trip rather than being a constant.
   */
  private inFlightBudget(batchSize: number): number {
    const fixed = this.spec.send.maxInFlight;
    if (fixed > 0) return fixed;
    const requestsPerSec = this.spec.rateEps / batchSize;
    // 1.5x headroom absorbs the jitter between the p50 the EWMA tracks and the
    // tail; without it the loop idles at exactly the wrong moments.
    const need = Math.ceil((requestsPerSec * this.apiEwmaMs * 1.5) / 1000) + 2;
    return Math.max(8, Math.min(1024, need));
  }

  private async bulkLoop() {
    const spec = this.spec;
    const cap = spec.totalEvents;
    const batchSize = Math.max(1, Math.min(this.maxBatch(), spec.send.batchSize));
    let inFlight = 0; // requests, not events — that is what the round trip gates
    let seq = 0;
    const t0 = Date.now();

    while (seq < cap && !this.stopRequested) {
      const elapsed = (Date.now() - t0) / 1000;
      const planned = Math.min(cap, Math.floor(plannedBy(spec, elapsed)));
      const maxInFlight = this.inFlightBudget(batchSize);
      while (seq < planned && inFlight < maxInFlight && !this.stopRequested) {
        const take = Math.min(batchSize, planned - seq);
        const entries: SendEntry[] = [];
        for (let i = 0; i < take; i++) {
          const slot = this.plan[seq % this.plan.length]!;
          const n = seq++;
          entries.push({
            target: slot.target,
            variant: slot.variant,
            txid: `${this.prefix}b${n}`,
            seq: n,
            stream: "bulk",
            isProbe: spec.probeEvery > 0 && n % spec.probeEvery === 0,
          });
        }
        inFlight++;
        void this.sendMany(entries).finally(() => {
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
      const mine = this.usage.pushed;
      const mineWallet = this.wallet.pushed;
      // The wallet is downstream of usage, so releasing the next probe as soon as
      // usage caught up would leave several events outstanding on the wallet side
      // and quietly turn its EXACT attribution into a coalesced one.
      //
      // A read path the preflight canary proved DEAD is not waited on at all: it
      // would never advance, so the serial stream would send one event and then
      // block for the whole probe timeout — starving the other read path of
      // samples. Measured against a local API whose current_usage was cache-served
      // while the wallet path was live: one wallet sample instead of a run's worth.
      const waitsForUsage = !this.usageStaleAtStart;
      const waitsForWallet = this.walletMode === "exact" && !this.walletStaleAtStart;
      const done = () =>
        (!waitsForUsage || this.usage.attributed >= mine) && (!waitsForWallet || this.wallet.attributed >= mineWallet);
      const deadline = Date.now() + cfg.probeTimeoutMs;
      while (!done() && Date.now() < deadline && !this.stopRequested) {
        if (this.sendingDone && Date.now() - rec.sentAt > 30_000) break;
        await sleep(25);
      }
      // A dead read path must not pace the stream, but it must not silently pace
      // it at full speed either: without a gap the probe stream becomes a second
      // bulk sender aimed at the probe target.
      if (!waitsForUsage && !waitsForWallet) await sleep(cfg.usagePollMs);
      if (this.usage.attributed >= mine) {
        rec.usageMs = (this.series.get("usage_visible")?.raw().at(-1) as number | undefined) ?? undefined;
      } else {
        this.counters.usageTimeouts++;
        this.log("warn", `usage probe ${txid} did not appear within ${cfg.probeTimeoutMs}ms`);
      }
      if (waitsForWallet && this.wallet.attributed >= mineWallet) {
        rec.walletMs = (this.series.get("wallet_visible")?.raw().at(-1) as number | undefined) ?? undefined;
      }
    }
  }

  private pushUsageExpectation(target: Target, variant: EventVariant, sentAt: number) {
    this.usage.push(sentAt, unitsOfVariant(target, variant));
  }

  private pushWalletExpectation(target: Target, variant: EventVariant, sentAt: number) {
    const cents = centsOfVariant(target, variant);
    this.wallet.push(sentAt, cents == null ? 0 : cents * this.walletCentsFactor);
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
    this.usagePolls.begin(t0);
    try {
      const { usage } = await currentUsage(t.customerExternalId, t.subscriptionExternalId);
      const t1 = Date.now();
      this.usagePolls.end(t0, t1, true);
      const v = usageValue(usage, t.metricCode);
      const deltaUnits = v.units - this.usageUnitsBaseline;
      // How many of our events can this reading account for? The run knows the
      // exact unit total it has sent, so this is an exact question for sum and
      // count metrics. events_count is the fallback if units are not numeric.
      const covered =
        Number.isFinite(deltaUnits) && this.usage.pushed > 0
          ? this.usage.coveredByValue(deltaUnits)
          : v.eventsCount - this.usageBaseline;
      const from = this.usage.attributed;
      const { samples } = this.usage.observe(t0, t1, covered);
      for (const [i, latency] of samples.entries()) {
        this.series.add("usage_visible", latency);
        this.counters.usageProbes++;
        this.notePairLeg("usage", from + i, latency);
      }
      if (samples.length === 0) this.warnStuckUsage(t1);
    } catch (e) {
      this.usagePolls.end(t0, Date.now(), false);
      this.noteError(`current_usage: ${(e as Error).message}`);
    }
  }

  /** A read path that never moves while events arrive is a cache, not latency. */
  private warnStuckUsage(now: number) {
    const stale = this.usage.stale;
    if (this.usage.outstanding === 0) return;
    const stuckFor = this.usage.stuckForMs(now);
    if (stale.unchangedSincePolls === 25 || (stuckFor > 10_000 && stale.unchangedSincePolls % 100 === 0)) {
      this.log(
        "warn",
        `current_usage has not moved for ${Math.round(stuckFor / 1000)}s across ${stale.unchangedSincePolls} polls ` +
          `while ${this.usage.outstanding} event(s) are outstanding — ` +
          "the charge cache is probably serving this read (LAGO_RISINGWAVE_USAGE_ENABLED not true, or the charge is not realtime-eligible)",
      );
    }
  }

  /**
   * One leg of the per-event usage → wallet split. Both legs are measured from
   * the same send time on the same clock, so their difference is exactly the gap
   * between the two observations — no third clock, no second send time.
   *
   * Clamped at zero: both are midpoint estimates inside their own poll bracket,
   * so a wallet reading that landed within the usage sample's uncertainty is
   * reported as "no measurable gap" rather than as negative time.
   */
  private notePairLeg(leg: "usage" | "wallet", index: number, latency: number) {
    if (!this.walletAligned) return;
    if (leg === "usage") this.usageLatency[index] = latency;
    else this.walletLatency[index] = latency;
    const u = this.usageLatency[index];
    const w = this.walletLatency[index];
    if (u == null || w == null || this.pairEmitted.has(index)) return;
    this.pairEmitted.add(index);
    this.series.add("usage_to_wallet", Math.max(0, w - u));
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
    await this.pollLoop({
      tracker: this.usage,
      polls: this.usagePolls,
      intervalMs: cfg.usagePollMs,
      concurrency: cfg.usagePollConcurrency,
      once: () => this.pollUsageOnce(),
      onTimeout: (missing) => {
        this.counters.usageTimeouts += missing;
        this.log("warn", `usage counter never reached ${missing} event(s) within the probe timeout`);
      },
    });
  }

  /**
   * The shared pipelined poll driver for both read paths: a request goes out
   * every `intervalMs` up to `concurrency` in flight instead of waiting for each
   * response, which decouples the resolution of the measurement from the
   * endpoint's own response time.
   */
  private async pollLoop(o: {
    tracker: CrossingTracker;
    polls: PollStats;
    intervalMs: number;
    concurrency: number;
    once: () => Promise<void>;
    onTimeout: (missing: number) => void;
  }) {
    const cfg = getConfig().measurement;
    const maxInFlight = Math.max(1, o.concurrency);
    while (!this.stopRequested) {
      if (this.sendingDone && o.tracker.caughtUp) break;
      if (this.sendingDone && !o.tracker.caughtUp) {
        const last = o.tracker.lastSentAt ?? Date.now();
        if (Date.now() - last > cfg.probeTimeoutMs) {
          o.onTimeout(o.tracker.outstanding);
          break;
        }
      }
      // Nothing recorded yet: idle politely rather than hammering the endpoint.
      if (o.tracker.pushed === 0) {
        await sleep(o.intervalMs);
        continue;
      }
      if (o.polls.inFlight < maxInFlight) void o.once();
      await sleep(o.intervalMs);
    }
    // Let the last responses land so their samples are not lost.
    const deadline = Date.now() + 5_000;
    while (o.polls.inFlight > 0 && Date.now() < deadline) await sleep(50);
  }

  /**
   * One `GET /wallets` for the probe's customer. The reading is the sum of
   * `ongoing_usage_balance_cents` over the customer's active wallets — a plain
   * column the refresh writes, so this poll never triggers the computation it is
   * timing.
   */
  private async pollWalletOnce(): Promise<void> {
    const t = this.walletTarget!;
    const t0 = Date.now();
    this.walletPolls.begin(t0);
    try {
      const { wallets } = await customerWallets(t.customerExternalId);
      const t1 = Date.now();
      this.walletPolls.end(t0, t1, true);
      const r = walletReading(wallets);
      this.noteWalletRefresh(r);
      const covered =
        this.walletMode === "watermark"
          ? this.wallet.coveredByValue(r.ongoingUsageCents - this.walletBaselineCents, this.walletTolerance())
          : // exact / refresh: the reading carries no per-event quantity, so the
            // n-th observed increase is the n-th crossing.
            this.walletIncreases;
      const from = this.wallet.attributed;
      const { samples } = this.wallet.observe(t0, t1, covered);
      for (const [i, latency] of samples.entries()) {
        this.series.add("wallet_visible", latency);
        this.counters.walletProbes++;
        this.notePairLeg("wallet", from + i, latency);
      }
      if (samples.length === 0) this.warnStuckWallet(t1);
    } catch (e) {
      this.walletPolls.end(t0, Date.now(), false);
      this.noteError(`GET /wallets: ${(e as Error).message}`);
    }
  }

  /**
   * Tolerance on the predicted cents. Predictions are pre-tax and per event
   * while the reading is a rounded post-tax total, so a fraction of one event's
   * step absorbs the rounding — deliberately a fraction, never a whole step, so
   * it can never credit an event that has not landed.
   */
  private walletTolerance(): number {
    const step = (this.walletPerEventCents ?? 0) * this.walletCentsFactor;
    return Math.max(0.5, step * 0.25);
  }

  /**
   * Count refreshes, which is a different question from counting crossings: the
   * consumer collapses every trigger for one customer in a batch into a single
   * refresh, so events-per-refresh is the coalescing factor the wallet path is
   * built around. `last_ongoing_balance_sync_at` counts them exactly when Lago
   * serializes it; otherwise a change in the amount is the only evidence there
   * is, which undercounts refreshes that recomputed the same number.
   */
  private noteWalletRefresh(r: WalletReading) {
    if (r.syncedAtMs != null) {
      this.walletSyncStampSeen = true;
      if (r.syncedAtMs > this.walletLastSyncMs) {
        if (this.walletLastSyncMs) this.walletRefreshes++;
        this.walletLastSyncMs = r.syncedAtMs;
      }
    }
    if (r.ongoingUsageCents > this.walletLastValue) {
      this.walletLastValue = r.ongoingUsageCents;
      this.walletIncreases++;
      if (r.syncedAtMs == null) this.walletRefreshes++;
    }
  }

  private warnStuckWallet(now: number) {
    const stale = this.wallet.stale;
    if (this.wallet.outstanding === 0) return;
    const stuckFor = this.wallet.stuckForMs(now);
    if (stale.unchangedSincePolls === 40 || (stuckFor > 15_000 && stale.unchangedSincePolls % 200 === 0)) {
      this.log(
        "warn",
        `the wallet ongoing balance has not moved for ${Math.round(stuckFor / 1000)}s across ${stale.unchangedSincePolls} polls ` +
          `while ${this.wallet.outstanding} event(s) are outstanding — check that the wallet refresh consumer is running ` +
          "(LAGO_KAFKA_WALLET_REFRESH_TRIGGERS_TOPIC set, karafka up) and that the wallet is not restricted away from this metric",
      );
    }
  }

  private async walletPollLoop() {
    const cfg = getConfig().measurement;
    await this.pollLoop({
      tracker: this.wallet,
      polls: this.walletPolls,
      intervalMs: cfg.walletPollMs,
      concurrency: cfg.walletPollConcurrency,
      once: () => this.pollWalletOnce(),
      onTimeout: (missing) => {
        this.counters.walletTimeouts += missing;
        this.log("warn", `the wallet balance never accounted for ${missing} event(s) within the probe timeout`);
      },
    });
  }

  private get transport(): Transport {
    return this.spec.send.transport;
  }

  /** Events per request: Lago's own limit on the API, this app's on the producer. */
  private maxBatch(): number {
    return this.transport === "kafka" ? MAX_KAFKA_BATCH : MAX_EVENT_BATCH;
  }

  /**
   * Send one request through whichever transport the run chose. Preflight's
   * canaries go through here too, so "the event was accepted" means the same
   * thing for them as for the bulk stream.
   */
  private send(payloads: EventPayload[]): Promise<SendResult> {
    return sendEvents(this.transport, payloads, this.envelope);
  }

  /** One event's worth of intent, before it is put on a request. */
  private buildPayload(e: SendEntry): EventPayload {
    return {
      transaction_id: e.txid,
      external_subscription_id: e.target.subscriptionExternalId,
      code: e.target.metricCode,
      timestamp: Date.now() / 1000,
      properties: e.variant.properties,
    };
  }

  /**
   * Send one HTTP request carrying `entries` and record every event on it.
   *
   * All of them share the request's `sentAt` and round trip, which is exactly
   * what a batching integration hands the API: the batch is the moment the
   * events were submitted, and every downstream latency is measured from it.
   */
  private async sendMany(entries: SendEntry[]): Promise<Rec[]> {
    if (entries.length === 0) return [];
    const res = await this.send(entries.map((e) => this.buildPayload(e)));
    // One request, one sample: batching must not multiply the API latency
    // histogram by the batch size.
    this.series.add("api_response", res.apiMs);
    this.apiEwmaMs = this.apiEwmaMs * 0.9 + res.apiMs * 0.1;
    if (!res.ok) {
      const what =
        this.transport === "kafka"
          ? `PRODUCE ${getConfig().kafka.topic}[${entries.length}]`
          : entries.length > 1
            ? `POST /events/batch[${entries.length}]`
            : "POST /events";
      this.noteError(`${what} ${res.status}: ${res.error ?? "network"}`);
    }
    return entries.map((e) => this.record(e, res));
  }

  private record(e: SendEntry, res: SendResult): Rec {
    const rec: Rec = {
      txid: e.txid,
      seq: e.seq,
      stream: e.stream,
      targetId: e.target.id,
      metricCode: e.target.metricCode,
      subscriptionExternalId: e.target.subscriptionExternalId,
      isVisibilityProbe: e.isProbe && res.ok,
      sentAt: res.sentAt,
      apiMs: Math.round(res.apiMs * 1000) / 1000,
      ok: res.ok,
      status: res.status,
      seen: {},
      stamps: {},
      computed: new Set(),
    };
    this.recs.set(e.txid, rec);
    const slot = this.plan.find((p) => p.target.id === e.target.id && p.variant.key === e.variant.key);
    if (slot) slot.sent++;
    this.counters.sent++;
    this.rate.mark(nowSec(), !res.ok);
    if (res.ok) {
      this.counters.accepted++;
      if (
        this.usageMode === "watermark" &&
        this.probeTarget &&
        e.target.subscriptionExternalId === this.probeTarget.subscriptionExternalId &&
        e.target.metricCode === this.probeTarget.metricCode
      ) {
        this.pushUsageExpectation(e.target, e.variant, res.sentAt);
      }
      // Any event for the wallet's customer moves its ongoing usage, whichever
      // subscription or metric it went to — so every one of them is recorded,
      // otherwise the predicted reading would run behind the real one.
      if (this.walletMode !== "off" && e.target.customerExternalId === this.walletTarget?.customerExternalId) {
        this.pushWalletExpectation(e.target, e.variant, res.sentAt);
      }
      if (e.isProbe) {
        this.counters.probes++;
        for (const st of this.enabledStages()) this.pending.get(st)!.add(e.txid);
      }
    } else {
      this.counters.failed++;
    }
    return rec;
  }

  private async sendOne(
    target: Target,
    variant: EventVariant,
    txid: string,
    seq: number,
    stream: "bulk" | "probe",
    isProbe: boolean,
  ): Promise<Rec | null> {
    const [rec] = await this.sendMany([{ target, variant, txid, seq, stream, isProbe }]);
    return rec ?? null;
  }

  private noteError(msg: string) {
    const key = msg.slice(0, 160);
    this.errors.set(key, (this.errors.get(key) ?? 0) + 1);
  }

  /**
   * Abort the run when the send path is failing badly enough that whatever it
   * measures is worthless.
   *
   * WINDOWED, not cumulative. A load test exists to push the pipeline until it
   * breaks, so the only actionable question is "is the send path failing NOW?".
   * Averaging over the whole run answers a different one and gets it wrong in
   * both directions: a burst of failures during warm-up poisons the ratio for
   * every healthy minute that follows, and a run that degrades at the very end
   * never trips because the early clean traffic dilutes it.
   *
   * 0 disables the guard. That is the only way to express "do not stop me" and
   * it is what the field's minimum has always allowed you to type; the previous
   * reading (zero tolerance, trip on the first failed request) made a 500k-event
   * run impossible to finish on any real network.
   */
  private tripGuard(): boolean {
    const limit = this.spec.guards.maxErrorRatePct;
    if (limit <= 0) return false;
    const { sent, failed } = this.rate.recent(GUARD_WINDOW_SEC);
    if (sent < GUARD_MIN_SAMPLES) return false;
    const pct = (failed / sent) * 100;
    if (pct > limit) {
      this.log(
        "error",
        `error rate ${pct.toFixed(1)}% over the last ${GUARD_WINDOW_SEC}s ` +
          `(${failed}/${sent}) above ${limit}% — stopping`,
      );
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
      usageFreshness: { staleAtStart: this.usageStaleAtStart, ...this.usage.freshness() },
      usagePoll: this.usagePolls.snapshot(this.usage.bracket),
      probeTarget: this.probeTarget
        ? {
            subscription: this.probeTarget.subscriptionExternalId,
            metric: this.probeTarget.metricCode,
            baseline: this.usageBaseline,
            expected: this.usageMode === "watermark" ? this.usage.pushed : this.usageExpected,
            attributed: this.usage.attributed,
          }
        : null,
      walletMode: this.walletMode,
      walletFreshness: { staleAtStart: this.walletStaleAtStart, ...this.wallet.freshness() },
      walletPoll: this.walletPolls.snapshot(this.wallet.bracket),
      walletProbe: this.walletTarget
        ? {
            customer: this.walletTarget.customerExternalId,
            subscription: this.walletTarget.subscriptionExternalId,
            metric: this.walletTarget.metricCode,
            wallets: this.walletTarget.wallets.length,
            baselineCents: this.walletBaselineCents,
            aligned: this.walletAligned,
            centsFactor: Math.round(this.walletCentsFactor * 1000) / 1000,
            perEventCents: this.walletPerEventCents,
            canary: this.walletCanaryDetail,
            // How many events one refresh covered on average: the consumer
            // collapses every trigger for a customer in a batch into one
            // refresh, so this is the coalescing the wallet path relies on.
            refreshes: this.walletRefreshes,
            eventsPerRefresh: this.walletRefreshes
              ? Math.round((this.wallet.pushed / this.walletRefreshes) * 10) / 10
              : null,
            refreshesExact: this.walletSyncStampSeen,
            expected: this.wallet.pushed,
            attributed: this.wallet.attributed,
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
          walletMs: r.walletMs,
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
