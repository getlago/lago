import { test } from "node:test";
import assert from "node:assert/strict";
import { buildSeedMatrix, chargeFilterCount, DEFAULT_SEED, normalizeSeedSpec, wideFilterPlan } from "../seed.js";

test("the default matrix tiles every metric over the plans and keeps every lookup key distinct", () => {
  const m = buildSeedMatrix(DEFAULT_SEED);
  assert.equal(m.metrics.length, 32);
  assert.equal(m.plans.length, 8);
  assert.equal(m.subscriptions.length, 128);
  // 8 plans × 12 charges, no plan charges a metric twice → 96 distinct (plan, code) keys.
  assert.equal(m.planCodePairs, 96);
  for (const p of m.plans) assert.equal(new Set(p.metricIdx).size, p.metricIdx.length);
  // Every metric is charged by exactly 3 plans (96 / 32).
  const perMetric = new Map<number, number>();
  for (const p of m.plans) for (const i of p.metricIdx) perMetric.set(i, (perMetric.get(i) ?? 0) + 1);
  assert.equal(perMetric.size, 32);
  assert.ok([...perMetric.values()].every((n) => n === 3));
  // Every plan sees every metric kind, so every subscription exercises filters, defaults, group keys and a wide charge.
  for (const p of m.plans) {
    const kinds = new Set(p.metricIdx.map((i) => m.metrics[i]!.kind));
    assert.equal(kinds.size, 5);
  }
  // Subscriptions round-robin over plans: 16 each.
  const perPlan = new Map<number, number>();
  for (const s of m.subscriptions) perPlan.set(s.planIdx, (perPlan.get(s.planIdx) ?? 0) + 1);
  assert.ok([...perPlan.values()].every((n) => n === 16));
  assert.equal(m.targets, 128 * 12);
});

test("codes and external ids carry the prefix and are unique", () => {
  const m = buildSeedMatrix({ ...DEFAULT_SEED, prefix: "Fan-Out " });
  assert.equal(m.spec.prefix, "fan_out_");
  const codes = [...m.metrics.map((x) => x.code), ...m.plans.map((x) => x.code)];
  assert.equal(new Set(codes).size, codes.length);
  assert.ok(codes.every((c) => c.startsWith("fan_out_")));
  const ids = m.subscriptions.flatMap((s) => [s.externalId, s.customerExternalId]);
  assert.equal(new Set(ids).size, ids.length);
});

test("the wide charge is one filter per (model, token_type), with one model left for the default bucket", () => {
  const w = wideFilterPlan(60);
  assert.equal(w.chargedCombos.length, 60);
  assert.equal(w.models.length, 21); // 20 charged models + 1 uncovered
  assert.equal(new Set(w.chargedCombos.map((c) => `${c.model}|${c.tokenType}`)).size, 60);
  assert.ok(w.chargedCombos.every((c) => c.model !== w.models[w.models.length - 1]));
  // Not a multiple of 3: the last model is only partly charged, count still exact.
  const odd = wideFilterPlan(7);
  assert.equal(odd.chargedCombos.length, 7);
  assert.equal(odd.models.length, 4);

  const m = buildSeedMatrix({ billableMetrics: 5, plans: 1, chargesPerPlan: 5, subscriptions: 1, wideFilters: 60 });
  const wide = m.metrics.find((x) => x.kind === "sum_many_filters")!;
  assert.equal(wide.aggregationType, "sum_agg");
  assert.deepEqual(
    wide.filters.map((f) => [f.key, f.values.length]),
    [["model", 21], ["token_type", 3]],
  );
  assert.equal(chargeFilterCount(wide, m.spec), 60);
  // 2 + 2 + 60 filters across the plan's five charges.
  assert.equal(m.chargeFilters, 64);
});

test("metric kinds carry the shapes the pipeline needs to resolve", () => {
  const m = buildSeedMatrix({ billableMetrics: 5, plans: 1, chargesPerPlan: 5, subscriptions: 1 });
  const byKind = Object.fromEntries(m.metrics.map((x) => [x.kind, x]));
  assert.equal(byKind.count!.aggregationType, "count_agg");
  assert.deepEqual(byKind.count!.filters, []);
  assert.equal(byKind.count_filtered!.aggregationType, "count_agg");
  assert.deepEqual(byKind.count_filtered!.filters, [{ key: "tier", values: ["gold", "silver", "bronze"] }]);
  assert.equal(byKind.sum_filtered!.fieldName, "amount");
  assert.deepEqual(byKind.sum_grouped!.groupKeys, ["region"]);
});

test("a spec is clamped rather than refused: charges per plan cannot exceed the metric count", () => {
  const spec = normalizeSeedSpec({ billableMetrics: 5, chargesPerPlan: 50, plans: 0, subscriptions: -3, currency: "usd" });
  assert.equal(spec.chargesPerPlan, 5);
  assert.equal(spec.plans, 1);
  assert.equal(spec.subscriptions, 1);
  assert.equal(spec.currency, "USD");
  const m = buildSeedMatrix(spec);
  assert.equal(m.planCodePairs, 5);
  // More plans than metrics: windows overlap, but keys stay distinct within a plan.
  const wide = buildSeedMatrix({ billableMetrics: 3, plans: 10, chargesPerPlan: 3, subscriptions: 10 });
  assert.equal(wide.planCodePairs, 30);
  for (const p of wide.plans) assert.equal(new Set(p.metricIdx).size, 3);
});
