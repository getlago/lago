import {
  createBillableMetric,
  createPlan,
  createSubscription,
  getBillableMetric,
  getPlan,
  listSubscriptions,
  upsertCustomer,
  type ChargeInput,
  type LagoBillableMetric,
} from "./clients/lago.js";

/**
 * Seeding a fixture matrix wide enough to FAN OUT the pipeline.
 *
 * Why width matters: every lookup in the RisingWave pipeline is a temporal join,
 * and a temporal join hash-shuffles the event stream on its lookup key so that
 * the actor holding a key's dimension row is the one that processes its events.
 * The number of DISTINCT keys is therefore what bounds how many actors can be
 * busy at once — one subscription and one metric code means one actor does all
 * the work whatever the cluster's parallelism, and the ceiling that shows is
 * the ceiling of a single core, not of the pipeline.
 *
 *   stage 0   billable_metrics   ON (organization_id, code)          → distinct METRIC CODES
 *   stage 1   subscriptions_agg  ON (organization_id, external_id)   → distinct SUBSCRIPTIONS
 *   stage 1   flat_filters_agg   ON (organization_id, plan_id, code) → distinct (PLAN, CODE) PAIRS
 *
 * Downstream, usage_buckets_15m groups on (subscription, charge, filter,
 * grouped_by), so the same width also spreads the aggregation state.
 *
 * Hashing is not dealing: with K keys over P actors the busiest actor holds
 * noticeably more than K/P until K is several times P. The defaults are sized
 * for a cluster of up to 16 actors per fragment (the compute tiers the POC has
 * run on): 32 codes, 96 (plan, code) pairs and 128 subscriptions give every
 * fragment at least 2× its actor count in keys, and 8× on the subscription
 * join, which is the one the ROADMAP measured as the hot fragment. Everything
 * is a knob, so a run can also deliberately collapse one dimension to see that
 * fragment become the bottleneck.
 *
 * What the matrix contains (all standard charges, price 1 per unit, so the
 * wallet watermark stays priceable):
 *
 *   metric kind (rotates by index)  aggregation      charge shape
 *   count                           count_agg        no filters
 *   count_filtered                  count_agg        BM filter tier ∈ {gold, silver, bronze};
 *                                                    charge filters on gold and silver → bronze
 *                                                    is the default bucket
 *   sum_filtered                    sum_agg(amount)  same filters as above
 *   sum_grouped                     sum_agg(amount)  pricing_group_keys ["region"]
 *   sum_many_filters                sum_agg(amount)  the AI-company shape: BM filters model ∈
 *                                                    {model_01..model_N} × token_type ∈ {input,
 *                                                    output, cached_input}; ONE charge filter per
 *                                                    combination (`wideFilters` of them, default
 *                                                    60), each at its own price; the last model
 *                                                    is left uncovered → default bucket
 *
 * The wide kind is what makes matching_filter() earn its keep: the candidate
 * array for such a charge holds dozens of filters, every event has to be
 * scored against all of them, and flat_filters_agg's JSONB row for the charge
 * is correspondingly large — exactly the per-charge cost an LLM vendor's
 * catalog (a price per model per token type) puts on the pipeline.
 *
 * Each plan charges a contiguous window of `chargesPerPlan` metrics starting at
 * plan_index × (metrics / plans), so every metric is charged by roughly the same
 * number of plans and every plan sees every kind. Subscriptions round-robin over
 * plans; each gets its own customer.
 *
 * Idempotent: a metric or plan whose code already exists is kept as is (and
 * reported), POST /customers is an upsert, and subscriptions already active are
 * skipped from a single listing rather than re-posted one by one.
 */

export type SeedSpec = {
  /** Every code and external id starts with this, so the fixtures are recognisable and selectable as a set. */
  prefix: string;
  billableMetrics: number;
  plans: number;
  chargesPerPlan: number;
  subscriptions: number;
  /** Charge filters on each `sum_many_filters` charge (model × token_type combinations). */
  wideFilters: number;
  currency: string;
};

export const DEFAULT_SEED: SeedSpec = {
  prefix: "lt_",
  billableMetrics: 32,
  plans: 8,
  chargesPerPlan: 12,
  subscriptions: 128,
  wideFilters: 60,
  currency: "EUR",
};

export const SEED_LIMITS = {
  billableMetrics: 500,
  plans: 100,
  chargesPerPlan: 100,
  subscriptions: 2000,
  wideFilters: 600,
};

export type MetricKind = "count" | "count_filtered" | "sum_filtered" | "sum_grouped" | "sum_many_filters";
export const KINDS: MetricKind[] = ["count", "count_filtered", "sum_filtered", "sum_grouped", "sum_many_filters"];

export const FILTER_KEY = "tier";
export const FILTER_VALUES = ["gold", "silver", "bronze"] as const;
/** Values that get a charge filter; the last BM filter value stays uncovered → default bucket. */
export const CHARGED_FILTER_VALUES = ["gold", "silver"] as const;
export const GROUP_KEY = "region";
export const SUM_FIELD = "amount";

/** The wide kind's two filter keys. Token types are fixed; models scale with `wideFilters`. */
export const MODEL_KEY = "model";
export const TOKEN_TYPE_KEY = "token_type";
export const TOKEN_TYPES = ["input", "output", "cached_input"] as const;

/**
 * The wide charge's filters: one per (model, token_type), models numbered
 * `model_01`.., as many as `wideFilters` needs — plus ONE extra model declared
 * on the metric but charged by no filter, so events for it fall into the
 * default bucket like any not-yet-priced model would.
 */
export function wideFilterPlan(wideFilters: number): {
  models: string[];
  chargedCombos: { model: string; tokenType: string }[];
} {
  const covered = Math.max(1, Math.ceil(wideFilters / TOKEN_TYPES.length));
  const w = String(covered + 1).length;
  const models = Array.from({ length: covered + 1 }, (_, i) => `model_${pad(i + 1, w)}`);
  const chargedCombos: { model: string; tokenType: string }[] = [];
  for (const model of models.slice(0, covered))
    for (const tokenType of TOKEN_TYPES) chargedCombos.push({ model, tokenType });
  return { models, chargedCombos: chargedCombos.slice(0, wideFilters) };
}

export type SeedMetric = {
  index: number;
  code: string;
  name: string;
  kind: MetricKind;
  aggregationType: "count_agg" | "sum_agg";
  fieldName: string | null;
  filters: { key: string; values: string[] }[];
  groupKeys: string[];
};

export type SeedPlan = {
  index: number;
  code: string;
  name: string;
  /** Indexes into `metrics`, in charge order. */
  metricIdx: number[];
};

export type SeedSubscription = {
  index: number;
  externalId: string;
  customerExternalId: string;
  planIdx: number;
};

export type SeedMatrix = {
  spec: SeedSpec;
  metrics: SeedMetric[];
  plans: SeedPlan[];
  subscriptions: SeedSubscription[];
  /** Distinct (plan, code) lookup keys stage 1 will hash on. */
  planCodePairs: number;
  /** Targets discovery will offer: one per (subscription, charge). */
  targets: number;
  /** Charge filters over every plan — the size of the candidate arrays stage 1 scores against. */
  chargeFilters: number;
};

const pad = (n: number, width: number) => String(n).padStart(width, "0");

export function normalizeSeedSpec(input: Partial<SeedSpec> | undefined): SeedSpec {
  const clampInt = (v: unknown, min: number, max: number, dflt: number) => {
    const n = Math.floor(Number(v));
    return Number.isFinite(n) ? Math.max(min, Math.min(max, n)) : dflt;
  };
  // Lower-case, [a-z0-9_] only, and always ending in "_" so the prefix reads as
  // a separator in every code it produces (lt_count_01, not ltcount_01).
  let prefix = (typeof input?.prefix === "string" ? input.prefix : DEFAULT_SEED.prefix)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "_");
  if (!prefix) prefix = DEFAULT_SEED.prefix;
  if (!prefix.endsWith("_")) prefix += "_";
  const billableMetrics = clampInt(input?.billableMetrics, 1, SEED_LIMITS.billableMetrics, DEFAULT_SEED.billableMetrics);
  return {
    prefix,
    billableMetrics,
    plans: clampInt(input?.plans, 1, SEED_LIMITS.plans, DEFAULT_SEED.plans),
    // A plan cannot charge the same metric twice, so the window is capped at the metric count.
    chargesPerPlan: Math.min(
      billableMetrics,
      clampInt(input?.chargesPerPlan, 1, SEED_LIMITS.chargesPerPlan, DEFAULT_SEED.chargesPerPlan),
    ),
    subscriptions: clampInt(input?.subscriptions, 1, SEED_LIMITS.subscriptions, DEFAULT_SEED.subscriptions),
    wideFilters: clampInt(input?.wideFilters, 1, SEED_LIMITS.wideFilters, DEFAULT_SEED.wideFilters),
    currency: (typeof input?.currency === "string" && /^[A-Za-z]{3}$/.test(input.currency.trim())
      ? input.currency.trim()
      : DEFAULT_SEED.currency
    ).toUpperCase(),
  };
}

/** The whole matrix as data, before anything is created — what Preflight-style reporting and the test pin. */
export function buildSeedMatrix(raw: Partial<SeedSpec> | undefined): SeedMatrix {
  const spec = normalizeSeedSpec(raw);
  const mw = String(spec.billableMetrics).length;
  const pw = String(spec.plans).length;
  const sw = String(spec.subscriptions).length;

  const wide = wideFilterPlan(spec.wideFilters);
  const metrics: SeedMetric[] = [];
  for (let i = 0; i < spec.billableMetrics; i++) {
    const kind = KINDS[i % KINDS.length]!;
    const filtered = kind === "count_filtered" || kind === "sum_filtered";
    const sum = kind !== "count" && kind !== "count_filtered";
    metrics.push({
      index: i,
      code: `${spec.prefix}${kind}_${pad(i + 1, mw)}`,
      name: `LT ${kind.replace(/_/g, " ")} ${pad(i + 1, mw)}`,
      kind,
      aggregationType: sum ? "sum_agg" : "count_agg",
      fieldName: sum ? SUM_FIELD : null,
      filters: filtered
        ? [{ key: FILTER_KEY, values: [...FILTER_VALUES] }]
        : kind === "sum_many_filters"
          ? [
              { key: MODEL_KEY, values: [...wide.models] },
              { key: TOKEN_TYPE_KEY, values: [...TOKEN_TYPES] },
            ]
          : [],
      groupKeys: kind === "sum_grouped" ? [GROUP_KEY] : [],
    });
  }

  // Each plan's window starts `stride` metrics after the previous plan's, so the
  // windows tile the metric list: with 32 metrics, 8 plans and 12 charges each
  // metric is charged by exactly 3 plans and every window holds 3 of each kind.
  const stride = Math.max(1, Math.floor(spec.billableMetrics / spec.plans));
  const plans: SeedPlan[] = [];
  for (let p = 0; p < spec.plans; p++) {
    const metricIdx: number[] = [];
    for (let j = 0; j < spec.chargesPerPlan; j++) metricIdx.push((p * stride + j) % spec.billableMetrics);
    plans.push({ index: p, code: `${spec.prefix}plan_${pad(p + 1, pw)}`, name: `LT plan ${pad(p + 1, pw)}`, metricIdx });
  }

  const subscriptions: SeedSubscription[] = [];
  for (let s = 0; s < spec.subscriptions; s++) {
    subscriptions.push({
      index: s,
      externalId: `${spec.prefix}sub_${pad(s + 1, sw)}`,
      customerExternalId: `${spec.prefix}cust_${pad(s + 1, sw)}`,
      planIdx: s % spec.plans,
    });
  }

  const pairs = new Set<string>();
  for (const p of plans) for (const m of p.metricIdx) pairs.add(`${p.index}:${m}`);
  let targets = 0;
  for (const s of subscriptions) targets += plans[s.planIdx]!.metricIdx.length;
  let chargeFilters = 0;
  for (const p of plans) for (const i of p.metricIdx) chargeFilters += chargeFilterCount(metrics[i]!, spec);

  return { spec, metrics, plans, subscriptions, planCodePairs: pairs.size, targets, chargeFilters };
}

/** Charge filters one charge of this metric carries. */
export function chargeFilterCount(m: SeedMetric, spec: SeedSpec): number {
  switch (m.kind) {
    case "count_filtered":
    case "sum_filtered":
      return CHARGED_FILTER_VALUES.length;
    case "sum_many_filters":
      return wideFilterPlan(spec.wideFilters).chargedCombos.length;
    default:
      return 0;
  }
}

// ------------------------------------------------------------------ execution

export type SeedCounter = { total: number; created: number; existing: number; failed: number };

export type SeedStatus = {
  phase: "idle" | "running" | "done" | "failed";
  spec: SeedSpec | null;
  matrix: {
    metrics: number;
    plans: number;
    planCodePairs: number;
    subscriptions: number;
    targets: number;
    chargeFilters: number;
  } | null;
  startedAt: number | null;
  endedAt: number | null;
  steps: { metrics: SeedCounter; plans: SeedCounter; customers: SeedCounter; subscriptions: SeedCounter };
  /** Newest last; bounded. */
  log: { t: number; level: "info" | "warn" | "error"; msg: string }[];
  error: string | null;
};

const counter = (total = 0): SeedCounter => ({ total, created: 0, existing: 0, failed: 0 });

let status: SeedStatus = {
  phase: "idle",
  spec: null,
  matrix: null,
  startedAt: null,
  endedAt: null,
  steps: { metrics: counter(), plans: counter(), customers: counter(), subscriptions: counter() },
  log: [],
  error: null,
};

export const seedStatus = (): SeedStatus => status;
export const seedRunning = () => status.phase === "running";

function log(level: SeedStatus["log"][number]["level"], msg: string) {
  status.log.push({ t: Date.now(), level, msg });
  if (status.log.length > 300) status.log.splice(0, status.log.length - 300);
}

/** Run `f` over `items` with at most `width` in flight; failures are collected, never thrown. */
async function pooled<T>(items: T[], width: number, f: (item: T) => Promise<void>): Promise<void> {
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const item = items[next++]!;
      await f(item);
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, Math.min(width, items.length)) }, worker));
}

function chargeFor(m: SeedMetric, bmId: string, spec: SeedSpec): ChargeInput {
  const c: ChargeInput = {
    billable_metric_id: bmId,
    charge_model: "standard",
    pay_in_advance: false,
    invoiceable: true,
    properties: { amount: "1" },
  };
  if (m.groupKeys.length) c.properties.pricing_group_keys = [...m.groupKeys];
  if (m.kind === "sum_many_filters") {
    // One filter per (model, token_type), each at its own integer price so a
    // mis-attributed filter shows up in the wallet cents; integers keep the
    // watermark prediction exact.
    c.filters = wideFilterPlan(spec.wideFilters).chargedCombos.map(({ model, tokenType }, i) => ({
      invoice_display_name: `${model} ${tokenType}`,
      properties: { amount: String(1 + (i % 9)) },
      values: { [MODEL_KEY]: [model], [TOKEN_TYPE_KEY]: [tokenType] },
    }));
  } else if (m.filters.length) {
    // Distinct prices per filter, same reason.
    c.filters = CHARGED_FILTER_VALUES.map((v, i) => ({
      invoice_display_name: v,
      properties: { amount: String(i + 2) },
      values: { [FILTER_KEY]: [v] },
    }));
  }
  return c;
}

/**
 * Creates the matrix through the Lago API. Concurrency is modest on purpose:
 * this runs against the same API a run will later load, and a seed is a one-off
 * that should finish in seconds against a dev stack, not stress anything.
 */
export async function runSeed(raw: Partial<SeedSpec> | undefined): Promise<SeedStatus> {
  if (status.phase === "running") throw new Error("a seed is already running");
  const matrix = buildSeedMatrix(raw);
  const { spec } = matrix;
  status = {
    phase: "running",
    spec,
    matrix: {
      metrics: matrix.metrics.length,
      plans: matrix.plans.length,
      planCodePairs: matrix.planCodePairs,
      subscriptions: matrix.subscriptions.length,
      targets: matrix.targets,
      chargeFilters: matrix.chargeFilters,
    },
    startedAt: Date.now(),
    endedAt: null,
    steps: {
      metrics: counter(matrix.metrics.length),
      plans: counter(matrix.plans.length),
      customers: counter(matrix.subscriptions.length),
      subscriptions: counter(matrix.subscriptions.length),
    },
    log: [],
    error: null,
  };
  log(
    "info",
    `seeding ${matrix.metrics.length} billable metrics, ${matrix.plans.length} plans × ${spec.chargesPerPlan} charges ` +
      `(${matrix.planCodePairs} distinct plan/code pairs, ${matrix.chargeFilters} charge filters, ` +
      `${spec.wideFilters} per wide charge), ${matrix.subscriptions.length} customers + subscriptions ` +
      `→ ${matrix.targets} targets, prefix "${spec.prefix}"`,
  );

  try {
    // 1. Billable metrics. Plans need their lago_id, so this step is a hard gate.
    const bmByIndex = new Map<number, LagoBillableMetric>();
    await pooled(matrix.metrics, 8, async (m) => {
      try {
        const existing = await getBillableMetric(m.code);
        if (existing) {
          bmByIndex.set(m.index, existing);
          status.steps.metrics.existing++;
          if (existing.aggregation_type !== m.aggregationType)
            log(
              "warn",
              `${m.code} exists as ${existing.aggregation_type}, expected ${m.aggregationType} — kept as is; ` +
                "delete it or change the prefix for a clean matrix",
            );
          return;
        }
        const created = await createBillableMetric({
          name: m.name,
          code: m.code,
          aggregation_type: m.aggregationType,
          ...(m.fieldName ? { field_name: m.fieldName } : {}),
          ...(m.filters.length ? { filters: m.filters } : {}),
        });
        bmByIndex.set(m.index, created);
        status.steps.metrics.created++;
      } catch (e) {
        status.steps.metrics.failed++;
        log("error", `billable metric ${m.code}: ${(e as Error).message}`);
      }
    });
    log(
      "info",
      `billable metrics: ${status.steps.metrics.created} created, ${status.steps.metrics.existing} existing, ${status.steps.metrics.failed} failed`,
    );
    if (bmByIndex.size < matrix.metrics.length) throw new Error("not every billable metric is available — plans cannot be built");

    // 2. Plans. An existing plan is kept as is: rewriting charges under a plan
    // that already has subscriptions is not what a seed should do silently.
    const planOk = new Set<number>();
    await pooled(matrix.plans, 4, async (p) => {
      try {
        const existing = await getPlan(p.code);
        if (existing) {
          planOk.add(p.index);
          status.steps.plans.existing++;
          const have = existing.charges?.length ?? 0;
          if (have !== p.metricIdx.length)
            log("warn", `${p.code} exists with ${have} charge(s), expected ${p.metricIdx.length} — kept as is`);
          return;
        }
        await createPlan({
          name: p.name,
          code: p.code,
          interval: "monthly",
          amount_cents: 0,
          amount_currency: spec.currency,
          pay_in_advance: false,
          charges: p.metricIdx.map((i) => chargeFor(matrix.metrics[i]!, bmByIndex.get(i)!.lago_id, spec)),
        });
        planOk.add(p.index);
        status.steps.plans.created++;
      } catch (e) {
        status.steps.plans.failed++;
        log("error", `plan ${p.code}: ${(e as Error).message}`);
      }
    });
    log(
      "info",
      `plans: ${status.steps.plans.created} created, ${status.steps.plans.existing} existing, ${status.steps.plans.failed} failed`,
    );
    if (planOk.size === 0) throw new Error("no plan is available — nothing to subscribe to");

    // 3. Customers + subscriptions. One listing decides what already exists;
    // the rest is created with a small pool so the API is not hammered.
    const existingSubs = new Map<string, string>();
    for (const s of await listSubscriptions()) if (s.status === "active") existingSubs.set(s.external_id, s.plan_code);
    const todo = matrix.subscriptions.filter((s) => {
      if (!planOk.has(s.planIdx)) {
        status.steps.customers.failed++;
        status.steps.subscriptions.failed++;
        return false;
      }
      const have = existingSubs.get(s.externalId);
      if (have) {
        status.steps.customers.existing++;
        status.steps.subscriptions.existing++;
        if (have !== matrix.plans[s.planIdx]!.code)
          log("warn", `${s.externalId} is active on ${have}, expected ${matrix.plans[s.planIdx]!.code} — kept as is`);
        return false;
      }
      return true;
    });
    await pooled(todo, 8, async (s) => {
      const plan = matrix.plans[s.planIdx]!;
      try {
        await upsertCustomer({ external_id: s.customerExternalId, name: `LT customer ${s.index + 1}`, currency: spec.currency });
        status.steps.customers.created++;
      } catch (e) {
        status.steps.customers.failed++;
        status.steps.subscriptions.failed++;
        log("error", `customer ${s.customerExternalId}: ${(e as Error).message}`);
        return;
      }
      try {
        await createSubscription({
          external_customer_id: s.customerExternalId,
          plan_code: plan.code,
          external_id: s.externalId,
          name: `LT subscription ${s.index + 1}`,
          billing_time: "calendar",
        });
        status.steps.subscriptions.created++;
      } catch (e) {
        status.steps.subscriptions.failed++;
        log("error", `subscription ${s.externalId}: ${(e as Error).message}`);
      }
    });
    log(
      "info",
      `subscriptions: ${status.steps.subscriptions.created} created, ${status.steps.subscriptions.existing} existing, ` +
        `${status.steps.subscriptions.failed} failed`,
    );

    const anyFailed = Object.values(status.steps).some((c) => c.failed > 0);
    status.phase = anyFailed ? "failed" : "done";
    if (anyFailed) status.error = "some fixtures could not be created — see the log";
    else
      log(
        "info",
        "done. The CDC snapshot into RisingWave lags Postgres by a few seconds; rescan, then select the seeded " +
          "subscriptions and leave one out if the usage probe should run in exact mode.",
      );
  } catch (e) {
    status.phase = "failed";
    status.error = (e as Error).message;
    log("error", status.error);
  }
  status.endedAt = Date.now();
  return status;
}
