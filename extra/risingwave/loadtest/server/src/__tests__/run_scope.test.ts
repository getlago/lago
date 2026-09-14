import { test } from "node:test";
import assert from "node:assert/strict";
import { CH_STAGE_KEYS, RW_STAGE_KEYS, runScope, SEGMENTS, type RunSpec, type StageKey } from "../types.js";
import { SEGMENTS_NEEDING_STAGE } from "../run/runner.js";

const spec = (patch: Partial<RunSpec> = {}): RunSpec => ({
  rateEps: 1000,
  totalEvents: 100_000,
  ramp: { enabled: false, fromEps: 10, overSec: 30 },
  probeEvery: 20,
  send: { transport: "api", batchSize: 1, maxInFlight: 0 },
  targetIds: ["t1"],
  probeTargetId: "t1",
  walletProbeTargetId: "t1",
  stages: Object.fromEntries([...RW_STAGE_KEYS, ...CH_STAGE_KEYS].map((s) => [s, true])) as Record<
    StageKey,
    boolean
  >,
  guards: { maxErrorRatePct: 5 },
  spread: { groupKeyValues: 2, includeDefaultBucket: true, maxVariantsPerTarget: 8 },
  ...patch,
});

const stages = (on: StageKey[]) =>
  Object.fromEntries([...RW_STAGE_KEYS, ...CH_STAGE_KEYS].map((s) => [s, on.includes(s)])) as Record<
    StageKey,
    boolean
  >;

test("the default run touches everything", () => {
  const s = runScope(spec());
  assert.deepEqual(
    { rw: s.risingwave, ch: s.clickhouse, lago: s.lago },
    { rw: true, ch: true, lago: true },
  );
  assert.deepEqual(s.reads, ["RisingWave", "ClickHouse", "Lago current_usage", "Lago /wallets"]);
});

test("direct produce with no probe target and no ClickHouse stage touches neither Lago nor ClickHouse", () => {
  const s = runScope(
    spec({
      send: { transport: "kafka", batchSize: 500, maxInFlight: 0 },
      probeTargetId: null,
      walletProbeTargetId: null,
      stages: stages(RW_STAGE_KEYS),
    }),
  );
  assert.equal(s.lago, false);
  assert.equal(s.clickhouse, false);
  assert.equal(s.risingwave, true);
  assert.deepEqual(s.reads, ["RisingWave"]);
});

// The whole reason the scope is derived rather than declared: this is the knob
// users reach for to mean "stop touching everything else", and it does not.
test("disabling the probe does not narrow the scope on its own", () => {
  const s = runScope(spec({ probeEvery: 0 }));
  assert.equal(s.lago, true, "the usage and wallet reads are governed by their probe TARGETS");
  assert.equal(s.clickhouse, true, "the stamp sweeps read every ticked stage whether or not probes are enrolled");
});

test("a kafka run keeps Lago in scope while either read path has a target", () => {
  const kafka = { transport: "kafka" as const, batchSize: 500, maxInFlight: 0 };
  assert.equal(runScope(spec({ send: kafka, walletProbeTargetId: null })).lago, true);
  assert.equal(runScope(spec({ send: kafka, probeTargetId: null })).lago, true);
});

test("an API run stays in Lago's scope even with both probes cleared — the events go through it", () => {
  const s = runScope(spec({ probeTargetId: null, walletProbeTargetId: null, stages: stages([]) }));
  assert.equal(s.lago, true);
  assert.deepEqual(s.reads, [], "nothing is read; the run measures send throughput only");
});

test("what an unticked stage costs is named in segments that exist, and covers every stage", () => {
  // A typo in SEGMENTS_NEEDING_STAGE does not fail anything at runtime: it just
  // silently stops reporting a segment as unavailable, so the dashboard shows an
  // empty histogram for something the run never asked about.
  const keys = new Set(SEGMENTS.map((s) => s.key));
  for (const [stage, segs] of Object.entries(SEGMENTS_NEEDING_STAGE)) {
    for (const seg of segs) assert.ok(keys.has(seg), `${stage} names ${seg}, which is not in the catalog`);
  }
  for (const stage of [...RW_STAGE_KEYS, ...CH_STAGE_KEYS])
    assert.ok(SEGMENTS_NEEDING_STAGE[stage]?.length, `${stage} lists no segments`);
});

test("a stage's own polled segment is what it costs first", () => {
  // The catalog says which stage closes each polled segment; the two tables have
  // to agree, or unticking a stage leaves its own latency claimed as measurable.
  for (const s of SEGMENTS) {
    if (!s.stage) continue;
    assert.ok(
      SEGMENTS_NEEDING_STAGE[s.stage].includes(s.key),
      `${s.key} is closed by ${s.stage}, but unticking ${s.stage} does not mark it unavailable`,
    );
  }
});
