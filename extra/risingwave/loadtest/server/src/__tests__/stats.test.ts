import { test } from "node:test";
import assert from "node:assert/strict";
import { RateTracker, Series } from "../run/stats.js";
import { CrossingTracker } from "../run/crossing.js";

test("percentiles are exact below the retention cap", () => {
  const s = new Series();
  for (let i = 1; i <= 1000; i++) s.add(i);
  const p = s.percentiles()!;
  assert.equal(p.count, 1000);
  assert.equal(p.min, 1);
  assert.equal(p.max, 1000);
  assert.equal(p.p50, 500);
  assert.equal(p.p95, 950);
  assert.equal(p.p99, 990);
  assert.equal(p.mean, 500.5);
});

test("the histogram counts every retained sample", () => {
  const s = new Series();
  for (let i = 0; i < 1000; i++) s.add(i % 10);
  const h = s.histogram(8)!;
  assert.equal(
    h.counts.reduce((a, b) => a + b, 0),
    1000,
  );
  assert.equal(h.edges.length, 9);
});

test("memory stays flat past the cap and the count stays honest", () => {
  const s = new Series();
  const n = 600_000;
  for (let i = 0; i < n; i++) s.add(i);
  assert.equal(s.size, n, "every offered sample is counted");
  assert.equal(s.retained, 200_000, "but only the cap is retained");
  assert.equal(s.dropped, n - 200_000);
  const p = s.percentiles()!;
  assert.equal(p.count, n);
  // A reservoir over a uniform ramp estimates the median near the true one.
  // Loose bound: this asserts "not biased to the warm-up", not an exact value.
  assert.ok(Math.abs(p.p50 - n / 2) < n * 0.05, `p50 ${p.p50} should be near ${n / 2}`);
  assert.ok(p.max > n * 0.9, `max ${p.max} should come from the late samples`);
});

test("last() is the most recent sample, not the most recent retained one", () => {
  const s = new Series();
  for (let i = 0; i < 300_000; i++) s.add(i);
  assert.equal(s.last(), 299_999);
});

test("the rate tracker prunes buckets outside the window", () => {
  const r = new RateTracker();
  for (let sec = 0; sec < 5_000; sec++) r.markMany(sec, 100, 1);
  assert.ok(r.series(10_000).length <= 1_100, "old buckets are dropped");
});

test("markMany and mark agree", () => {
  const a = new RateTracker();
  const b = new RateTracker();
  const now = Math.floor(Date.now() / 1000);
  a.markMany(now, 10, 3);
  for (let i = 0; i < 10; i++) b.mark(now, i < 3);
  assert.deepEqual(a.recent(2), b.recent(2));
});

test("crossing attribution survives compaction", () => {
  const c = new CrossingTracker();
  const t0 = 1_000_000;
  // 50 000 events, each worth one unit, attributed a few hundred at a time.
  for (let i = 0; i < 50_000; i++) c.push(t0 + i, 1);
  let seen = 0;
  for (let k = 500; k <= 50_000; k += 500) {
    const covered = c.coveredByValue(k);
    assert.equal(covered, k, "the reading covers exactly k events");
    const { samples } = c.observe(t0 + 60_000, t0 + 60_001, covered);
    seen += samples.length;
  }
  assert.equal(seen, 50_000);
  assert.equal(c.attributed, 50_000);
  assert.ok(c.caughtUp);
});

test("a stalled read path folds instead of growing without bound", () => {
  const c = new CrossingTracker();
  const n = 700_000;
  for (let i = 0; i < n; i++) c.push(1_000_000 + i, 1);
  assert.equal(c.outstanding, 500_000, "outstanding is capped");
  assert.equal(c.folded, n - 500_000);
  assert.ok(c.saturated);
  // The cumulative total is still the truth, so a reading of n covers everything.
  assert.equal(c.coveredByValue(n), 500_000);
  const { samples } = c.observe(2_000_000, 2_000_001, c.coveredByValue(n));
  assert.equal(samples.length, 500_000);
  assert.ok(c.caughtUp);
});

test("a reading that has not moved attributes nothing", () => {
  const c = new CrossingTracker();
  c.push(1_000, 1);
  c.push(1_001, 1);
  const { samples } = c.observe(2_000, 2_001, c.coveredByValue(0));
  assert.equal(samples.length, 0);
  assert.equal(c.outstanding, 2);
});
