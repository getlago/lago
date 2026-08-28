import type { Percentiles, StatsSnapshot } from "../types.js";

const MAX_SAMPLES = 200_000;

/**
 * Exact percentiles over retained samples (no reservoir estimate) — at these
 * volumes an array plus a sort is both cheaper and more honest than a sketch.
 * Above MAX_SAMPLES a segment stops retaining, which is recorded as `dropped`
 * rather than silently skewing the tail.
 */
export class Series {
  private samples: number[] = [];
  dropped = 0;

  add(v: number) {
    if (!Number.isFinite(v)) return;
    if (this.samples.length >= MAX_SAMPLES) {
      this.dropped++;
      return;
    }
    this.samples.push(v);
  }

  get size() {
    return this.samples.length;
  }

  percentiles(): Percentiles | undefined {
    const n = this.samples.length;
    if (n === 0) return undefined;
    const s = [...this.samples].sort((a, b) => a - b);
    const at = (p: number) => s[Math.min(n - 1, Math.max(0, Math.ceil((p / 100) * n) - 1))]!;
    let sum = 0;
    for (const v of s) sum += v;
    return {
      count: n,
      min: s[0]!,
      p50: at(50),
      p95: at(95),
      p99: at(99),
      max: s[n - 1]!,
      mean: sum / n,
    };
  }

  /** Fixed-width histogram for the distribution view. */
  histogram(buckets = 32): { edges: number[]; counts: number[] } | undefined {
    const n = this.samples.length;
    if (n === 0) return undefined;
    let lo = Infinity;
    let hi = -Infinity;
    for (const v of this.samples) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (hi === lo) hi = lo + 1;
    const width = (hi - lo) / buckets;
    const counts = new Array<number>(buckets).fill(0);
    for (const v of this.samples) {
      const i = Math.min(buckets - 1, Math.floor((v - lo) / width));
      counts[i] = (counts[i] ?? 0) + 1;
    }
    return { edges: Array.from({ length: buckets + 1 }, (_, i) => lo + i * width), counts };
  }

  raw(): readonly number[] {
    return this.samples;
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

/** Rolling per-second throughput, for the live rate chart. */
export class RateTracker {
  private buckets = new Map<number, { sent: number; failed: number }>();

  mark(sec: number, failed: boolean) {
    let b = this.buckets.get(sec);
    if (!b) this.buckets.set(sec, (b = { sent: 0, failed: 0 }));
    b.sent++;
    if (failed) b.failed++;
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
