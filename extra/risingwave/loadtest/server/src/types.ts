/** Stage keys that can be polled for visibility. */
export type StageKey =
  | "rwEnriched"
  | "rwExpanded"
  | "chRwEnriched"
  | "chRwExpanded"
  | "chGoEnriched"
  | "chGoExpanded";

export type SegmentKind = "polled" | "stamped";

export type Segment = {
  key: string;
  label: string;
  kind: SegmentKind;
  /** Which stage's arrival closes this segment (polled segments only). */
  stage?: StageKey;
  group: "api" | "risingwave" | "clickhouse-rw" | "clickhouse-go" | "usage" | "breakdown";
  /** Plain-language statement of exactly what the two endpoints are. */
  from: string;
  to: string;
  /** Clocks the two endpoints are read from — one clock means skew-free. */
  clocks: string[];
  note?: string;
};

/**
 * The measurement catalog. The UI renders itself from this, so what the dashboard
 * claims and what the server computes cannot drift apart.
 *
 * POLLED segments are the trustworthy end-to-end numbers: both endpoints are read
 * from this app's clock (send time, and the tick on which a query first saw the
 * row), so no cross-cloud clock skew enters. Their resolution is the poll tick.
 *
 * STAMPED segments come from timestamps the pipeline itself recorded. They cover
 * every event rather than the probe sample and pinpoint which hop cost the time,
 * but each one spans two different machines' clocks — read them together with the
 * clock-offset panel.
 */
export const SEGMENTS: Segment[] = [
  {
    key: "api_response",
    label: "API response",
    kind: "polled",
    group: "api",
    from: "request left this app",
    to: "Lago answered 200",
    clocks: ["loadtest"],
    note: "Pure ingest cost. Included in every end-to-end number below.",
  },
  {
    key: "rw_enriched_visible",
    label: "→ queryable in RisingWave events_enriched",
    kind: "polled",
    stage: "rwEnriched",
    group: "risingwave",
    from: "request left this app",
    to: "row answered a pgwire SELECT",
    clocks: ["loadtest"],
    note: "Stage 0: billable-metric join + 32-day dedup, committed and readable.",
  },
  {
    key: "rw_expanded_visible",
    label: "→ queryable in RisingWave events_expanded",
    kind: "polled",
    stage: "rwExpanded",
    group: "risingwave",
    from: "request left this app",
    to: "row answered a pgwire SELECT",
    clocks: ["loadtest"],
    note: "Stage 1+2: subscription/charge/filter resolution, committed and readable.",
  },
  {
    key: "ch_rw_enriched_visible",
    label: "→ queryable in ClickHouse (RW shadow, enriched)",
    kind: "polled",
    stage: "chRwEnriched",
    group: "clickhouse-rw",
    from: "request left this app",
    to: "row answered a ClickHouse SELECT",
    clocks: ["loadtest"],
  },
  {
    key: "ch_rw_expanded_visible",
    label: "→ queryable in ClickHouse (RW shadow, expanded)",
    kind: "polled",
    stage: "chRwExpanded",
    group: "clickhouse-rw",
    from: "request left this app",
    to: "row answered a ClickHouse SELECT",
    clocks: ["loadtest"],
  },
  {
    key: "ch_go_enriched_visible",
    label: "→ queryable in ClickHouse (Go path, events_enriched)",
    kind: "polled",
    stage: "chGoEnriched",
    group: "clickhouse-go",
    from: "request left this app",
    to: "row answered a ClickHouse SELECT",
    clocks: ["loadtest"],
    note: "The baseline the RisingWave path is being compared against.",
  },
  {
    key: "ch_go_expanded_visible",
    label: "→ queryable in ClickHouse (Go path, events_enriched_expanded)",
    kind: "polled",
    stage: "chGoExpanded",
    group: "clickhouse-go",
    from: "request left this app",
    to: "row answered a ClickHouse SELECT",
    clocks: ["loadtest"],
    note: "The baseline the RisingWave path is being compared against.",
  },
  {
    key: "usage_visible",
    label: "→ reflected in the customer's current usage",
    kind: "polled",
    group: "usage",
    from: "request left this app",
    to: "GET /current_usage counted it",
    clocks: ["loadtest"],
    note:
      "What a customer actually sees. current_usage has no per-event handle, so attribution uses the metric's monotonic events_count: EXACT mode (probe target free of bulk traffic) sends one probe at a time; WATERMARK mode (probe target shares traffic, e.g. an instance with a single subscription) attributes the k-th count increment to the k-th event sent to that pair. Which mode ran is shown on the run.",
  },

  // ---- stamped breakdown (all events, cross-clock) ----
  {
    key: "ingest_to_broker",
    label: "Lago ingest → Redpanda append",
    kind: "stamped",
    group: "breakdown",
    from: "ingested_at (stamped by Lago)",
    to: "kafka_timestamp (broker append time)",
    clocks: ["lago", "redpanda"],
  },
  {
    key: "broker_to_rw",
    label: "Redpanda append → RisingWave picked it up",
    kind: "stamped",
    group: "breakdown",
    from: "kafka_timestamp",
    to: "rw_received_at (proctime at the source)",
    clocks: ["redpanda", "risingwave"],
    note: "rw_received_at is barrier-aligned and can read up to one barrier interval EARLY, so this leg is slightly optimistic.",
  },
  {
    key: "rw_enrich_to_expand",
    label: "RisingWave stage 0 → stage 1+2 emitted",
    kind: "stamped",
    group: "breakdown",
    from: "rw_received_at (source pickup)",
    to: "rw_expanded_at (barrier that emitted the expanded row)",
    clocks: ["risingwave"],
    note: "The subscription/charge/filter resolution itself. ONE clock at both ends, so this stamped leg is skew-free — but both are barrier-aligned, so its floor is barrier_interval_ms.",
  },
  {
    key: "rw_expand_to_ch",
    label: "Stage 1+2 emitted → ClickHouse insert (RW shadow, expanded)",
    kind: "stamped",
    group: "breakdown",
    from: "rw_expanded_at",
    to: "enriched_at (stamped by ClickHouse)",
    clocks: ["risingwave", "clickhouse"],
    note: "Sink and insert cost, separated from the pipeline compute for the first time.",
  },
  {
    key: "rw_to_ch",
    label: "RisingWave pickup → ClickHouse insert (RW shadow)",
    kind: "stamped",
    group: "breakdown",
    from: "rw_received_at",
    to: "enriched_at (stamped by ClickHouse)",
    clocks: ["risingwave", "clickhouse"],
  },
  {
    key: "ingest_to_ch_rw_enriched",
    label: "Lago ingest → ClickHouse insert (RW shadow, enriched)",
    kind: "stamped",
    group: "breakdown",
    from: "ingested_at",
    to: "enriched_at",
    clocks: ["lago", "clickhouse"],
  },
  {
    key: "ingest_to_ch_rw_expanded",
    label: "Lago ingest → ClickHouse insert (RW shadow, expanded)",
    kind: "stamped",
    group: "breakdown",
    from: "ingested_at",
    to: "enriched_at",
    clocks: ["lago", "clickhouse"],
  },
  {
    key: "ingest_to_ch_go_enriched",
    label: "Lago ingest → ClickHouse insert (Go path, enriched)",
    kind: "stamped",
    group: "breakdown",
    from: "ingested_at",
    to: "enriched_at",
    clocks: ["lago", "clickhouse"],
  },
  {
    key: "ingest_to_ch_go_expanded",
    label: "Lago ingest → ClickHouse insert (Go path, expanded)",
    kind: "stamped",
    group: "breakdown",
    from: "ingested_at",
    to: "enriched_at",
    clocks: ["lago", "clickhouse"],
  },
];

export type RunSpec = {
  /** Steady-state target rate. */
  rateEps: number;
  totalEvents: number;
  ramp: { enabled: boolean; fromEps: number; overSec: number };
  /** Every Nth event becomes a visibility probe. 0 disables probing. */
  probeEvery: number;
  targetIds: string[];
  /** Target whose current_usage is polled. May also be in targetIds (watermark mode). */
  probeTargetId: string | null;
  stages: Record<StageKey, boolean>;
  guards: { maxErrorRatePct: number; hardCap: number };
  /** How widely to spread events across charge filters and pricing group keys. */
  spread: { groupKeyValues: number; includeDefaultBucket: boolean; maxVariantsPerTarget: number };
};

export type RunPhase = "idle" | "preflight" | "sending" | "draining" | "done" | "stopped" | "failed";

export type Percentiles = {
  count: number;
  min: number;
  p50: number;
  p95: number;
  p99: number;
  max: number;
  mean: number;
};

export type StatsSnapshot = Record<string, Percentiles | undefined>;

export type FunnelCounts = {
  sent: number;
  accepted: number;
  failed: number;
  stages: Partial<Record<StageKey, number>>;
};

export type ClockOffsets = {
  /** Positive = that system's clock is AHEAD of this app's clock, in ms. */
  lago: number | null;
  risingwave: number | null;
  clickhouse: number | null;
  measuredAt: number;
};
