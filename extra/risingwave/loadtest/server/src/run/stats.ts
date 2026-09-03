import type { Percentiles, StatsSnapshot } from "../types.js";

/**
 * How many samples one segment retains. At 8 bytes each (a Float64Array, not a
 * boxed JS array) a segment costs 1.6MB flat, whatever the run's rate — which is
 * the point: a 100k/s run offers tens of millions of samples per segment and the
 * heap must not be a function of that.
 */
const MAX_SAMPLES = 200_000;

/**
 * Recomputing percentiles means sorting a copy of the retained samples. The SSE
 * stream asks every 500ms and there are a dozen segments, so without a floor on
 * how often that can happen the reporting path alone sorts millions of numbers a
 * second and starves the sender it is supposed to be measuring.
 */
const RECOMPUTE_MS = 1_000;

/**
 * Exact percentiles over retained samples (no sketch) — at these volumes an
 * array plus a sort is both cheaper and more honest.
 *
 * Above MAX_SAMPLES the segment switches to RESERVOIR sampling rather than
 * refusing new samples: a load test's interesting minutes are the late ones, and
 * "keep the first 200k, discard the rest" reports the warm-up as if it were the
 * whole run. Every offered sample has an equal chance of being retained, so the
 * percentiles stay unbiased estimates of the whole run at a fixed memory cost.
 * `dropped` counts the samples not retained, so the dilution is visible.
 */
export class Series {
  private buf = new Float64Array(1_024);
  /** Retained samples, `buf[0..n)`. */
  private n = 0;
  /** Total offered — the reservoir's denominator, and the honest count. */
  private offered = 0;
  dropped = 0;
  private lastV: number | undefined;

  private cachedPct: Percentiles | undefined;
  private cachedHist: { edges: number[]; counts: number[] } | undefined;
  private cachedAt = 0;
  private dirty = false;

  add(v: number) {
    if (!Number.isFinite(v)) return;
    this.lastV = v;
    this.offered++;
    if (this.n < MAX_SAMPLES) {
      if (this.n === this.buf.length) {
        const grown = new Float64Array(Math.min(MAX_SAMPLES, this.buf.length * 2));
        grown.set(this.buf);
        this.buf = grown;
      }
      this.buf[this.n++] = v;
    } else {
      const j = Math.floor(Math.random() * this.offered);
      if (j < MAX_SAMPLES) this.buf[j] = v;
      this.dropped++;
    }
    this.dirty = true;
  }

  /** Samples offered, retained or not. */
  get size() {
    return this.offered;
  }

  get retained() {
    return this.n;
  }

  /** Most recent sample, without materialising the buffer. */
  last(): number | undefined {
    return this.lastV;
  }

  /**
   * Sort once per RECOMPUTE_MS and serve both the percentiles and the histogram
   * from it. Returns null when the segment is empty.
   */
  private compute(buckets: number): boolean {
    const now = Date.now();
    if (!this.dirty && this.cachedAt) return this.n > 0;
    if (this.cachedAt && now - this.cachedAt < RECOMPUTE_MS) return this.n > 0;
    this.cachedAt = now;
    this.dirty = false;
    if (this.n === 0) {
      this.cachedPct = undefined;
      this.cachedHist = undefined;
      return false;
    }
    const s = this.buf.slice(0, this.n).sort();
    const n = this.n;
    const at = (p: number) => s[Math.min(n - 1, Math.max(0, Math.ceil((p / 100) * n) - 1))]!;
    let sum = 0;
    for (let i = 0; i < n; i++) sum += s[i]!;
    this.cachedPct = {
      // The honest population, not the retained sample — a percentile over a
      // reservoir still describes every event that was offered to it.
      count: this.offered,
      min: s[0]!,
      p50: at(50),
      p95: at(95),
      p99: at(99),
      max: s[n - 1]!,
      mean: sum / n,
    };
    const lo = s[0]!;
    let hi = s[n - 1]!;
    if (hi === lo) hi = lo + 1;
    const width = (hi - lo) / buckets;
    const counts = new Array<number>(buckets).fill(0);
    // Sorted, so the bucket index only ever moves forward: one linear walk.
    let bucket = 0;
    for (let i = 0; i < n; i++) {
      const target = Math.min(buckets - 1, Math.floor((s[i]! - lo) / width));
      if (target > bucket) bucket = target;
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    this.cachedHist = { edges: Array.from({ length: buckets + 1 }, (_, i) => lo + i * width), counts };
    return true;
  }

  percentiles(): Percentiles | undefined {
    this.compute(32);
    return this.cachedPct;
  }

  /** Fixed-width histogram for the distribution view. */
  histogram(buckets = 32): { edges: number[]; counts: number[] } | undefined {
    this.compute(buckets);
    return this.cachedHist;
  }
}

export class SeriesSet {
  private map = new Map<string, Series>();

  add(key: string, v: number) {
    let s = this.map.get(key);
    if (!s) this.map.set(key, (s = new Series()));
    s.add(v);
  }

  get(key: string): Series | undefined {
    return this.map.get(key);
  }

  snapshot(): StatsSnapshot {
    const out: StatsSnapshot = {};
    for (const [k, s] of this.map) out[k] = s.percentiles();
    return out;
  }

  histograms(buckets = 32) {
    const out: Record<string, { edges: number[]; counts: number[] } | undefined> = {};
    for (const [k, s] of this.map) out[k] = s.histogram(buckets);
    return out;
  }

  keys() {
    return [...this.map.keys()];
  }
}

/** How many whole seconds of per-second throughput are kept for the live chart. */
const RATE_WINDOW_SEC = 900;

/** Rolling per-second throughput, for the live rate chart. */
export class RateTracker {
  private buckets = new Map<number, { sent: number; failed: number }>();

  mark(sec: number, failed: boolean) {
    this.markMany(sec, 1, failed ? 1 : 0);
  }

  /**
   * One call per REQUEST rather than per event. At 100k events/s a per-event
   * call is 100k map lookups a second for a number that is only ever read one
   * bucket at a time; the whole batch shares a second and a verdict anyway.
   */
  markMany(sec: number, sent: number, failed: number) {
    let b = this.buckets.get(sec);
    if (!b) {
      this.buckets.set(sec, (b = { sent: 0, failed: 0 }));
      // The map is otherwise unbounded: an hour-long run keeps 3 600 buckets
      // even though nothing reads past the last RATE_WINDOW_SEC. The slack
      // means the scan runs once per 128 new buckets rather than every second.
      if (this.buckets.size > RATE_WINDOW_SEC + 128) {
        const cutoff = sec - RATE_WINDOW_SEC;
        for (const t of this.buckets.keys()) if (t < cutoff) this.buckets.delete(t);
      }
    }
    b.sent += sent;
    b.failed += failed;
  }

  /**
   * Totals over the last `windowSec` whole seconds. This is what the stop guard
   * reads: buckets are keyed by second, so walking the window costs
   * `windowSec` lookups regardless of how long the run has been going.
   */
  recent(windowSec: number): { sent: number; failed: number } {
    const now = Math.floor(Date.now() / 1000);
    let sent = 0;
    let failed = 0;
    for (let t = now - windowSec; t <= now; t++) {
      const b = this.buckets.get(t);
      if (!b) continue;
      sent += b.sent;
      failed += b.failed;
    }
    return { sent, failed };
  }

  series(limit = 300): { t: number; sent: number; failed: number }[] {
    return [...this.buckets.entries()]
      .sort((a, b) => a[0] - b[0])
      .slice(-limit)
      .map(([t, v]) => ({ t, sent: v.sent, failed: v.failed }));
  }
}
