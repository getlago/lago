import { Series } from "./stats.js";

/**
 * How many attributed entries may sit at the head of the arrays before they are
 * spliced off. Everything below `attributed` is dead — nothing reads it again —
 * so without this a 100k/s run keeps one pair of numbers per event sent for the
 * whole run.
 */
const COMPACT_AT = 8_192;

/**
 * Ceiling on OUTSTANDING (recorded but not yet attributed) entries. A read path
 * that stalls while the sender runs at 100k/s would otherwise grow these arrays
 * without bound and take the process down — which is a load-generator bug
 * reported as a pipeline result.
 *
 * Past the cap the tracker FOLDS: a new event is summed into the last entry,
 * which keeps the older send time. Attribution stays exact in value terms (the
 * cumulative total is still the truth), and the latency it reports for a folded
 * group is the oldest member's — an upper bound, the same reading `refresh`
 * mode already publishes. `saturated` says it happened rather than letting the
 * percentiles quietly become upper bounds.
 */
const MAX_OUTSTANDING = 500_000;

/**
 * Attribution for a read path that exposes no per-event handle — only a
 * monotonic number (a metric's units, a wallet's ongoing usage) that this run is
 * the sole writer of.
 *
 * Events are recorded in send order together with the cumulative value the run
 * expects the reading to hold once that event is accounted for. A poll then says
 * "the reading is X", which covers the first k events, and the k-th crossing is
 * attributed to the k-th event.
 *
 * Two things make the result trustworthy rather than plausible:
 *
 *  - BRACKETING. A poll that comes back still short of event k proves the
 *    crossing had not happened when that request *started*; the poll that does
 *    see it bounds the crossing by when its response *arrived*. The sample is
 *    placed in the middle of that window and half the window is reported as the
 *    measurement's own uncertainty — measured per run, never assumed.
 *  - COALESCING IS COUNTED, NOT AVERAGED. If one reading accounts for many
 *    events at once, that is a batch refresh rather than per-event latency, and
 *    `worstBatch` / `batches` say so instead of letting it melt into a
 *    percentile.
 *
 * Both the current_usage measurement and the wallet measurement run on this, so
 * "usage latency" and "wallet latency" cannot drift into meaning different
 * things.
 */
export class CrossingTracker {
  /** Send time of each recorded event, in order, from global index `base`. */
  private sentAt: number[] = [];
  /** Cumulative expected reading after each recorded event. */
  private cum: number[] = [];
  /** Global index of `sentAt[0]`: entries before it were attributed and dropped. */
  private base = 0;
  /** Cumulative total carried across a compaction, so `cum` stays absolute. */
  private droppedCum = 0;
  /** Events folded into an earlier entry because the read path fell too far behind. */
  folded = 0;
  attributed = 0;
  /**
   * Start time of the most recent poll that came back NOT yet seeing the next
   * event: a hard lower bound on the next crossing.
   */
  private lastBelowT0 = 0;
  readonly bracket = new Series();
  stale = { unchangedSincePolls: 0, unchangedSinceMs: 0, worstBatch: 0, batches: 0 };

  get pushed(): number {
    return this.base + this.sentAt.length;
  }

  get outstanding(): number {
    return this.pushed - this.attributed;
  }

  get caughtUp(): boolean {
    return this.attributed >= this.pushed;
  }

  get saturated(): boolean {
    return this.folded > 0;
  }

  get lastSentAt(): number | undefined {
    return this.sentAt.at(-1);
  }

  /** Cumulative expected reading after the last recorded event. */
  private get total(): number {
    return this.cum.length ? this.cum[this.cum.length - 1]! : this.droppedCum;
  }

  /** Record one accepted event and what it should add to the reading. */
  push(sentAt: number, delta: number) {
    if (this.outstanding >= MAX_OUTSTANDING && this.cum.length > 0) {
      // Fold into the last entry: its (older) send time is kept, so the sample
      // this group eventually produces is an upper bound rather than a fiction.
      this.cum[this.cum.length - 1] = this.total + delta;
      this.folded++;
      return;
    }
    this.sentAt.push(sentAt);
    this.cum.push(this.total + delta);
  }

  /** Drop the attributed head. Amortised O(1) per event. */
  private compact() {
    const drop = this.attributed - this.base;
    if (drop < COMPACT_AT) return;
    this.droppedCum = this.cum[drop - 1]!;
    this.sentAt.splice(0, drop);
    this.cum.splice(0, drop);
    this.base = this.attributed;
  }

  /**
   * How many recorded events a reading of `value` accounts for. Tolerance covers
   * the rounding a derived reading picks up (cents through taxes, for instance);
   * it is a fraction of one event's step, never a whole one, so it can never
   * credit an event that has not landed.
   */
  coveredByValue(value: number, tolerance = 1e-9): number {
    // Start at the watermark, not at zero. `cum` is non-decreasing and
    // `attributed` only ever advances, so everything below it is already known
    // to be covered — scanning from 0 on every poll made the cost of a poll grow
    // with the run and turned a 100k/s run's polling into a quadratic.
    let k = this.attributed - this.base;
    while (k < this.cum.length && this.cum[k]! <= value + tolerance) k++;
    return this.base + k;
  }

  /**
   * Feed one completed poll. `covered` is how many recorded events the reading
   * accounts for; `t0`/`t1` are when the request left and its response arrived.
   * Returns the latency samples this poll resolved, in event order.
   */
  observe(t0: number, t1: number, covered: number): { samples: number[]; batch: number } {
    // Responses can land out of order; the watermark only ever advances.
    const upTo = Math.min(covered, this.pushed);
    if (upTo <= this.attributed) {
      if (t0 > this.lastBelowT0) this.lastBelowT0 = t0;
      if (this.outstanding > 0) {
        this.stale.unchangedSincePolls++;
        if (!this.stale.unchangedSinceMs) this.stale.unchangedSinceMs = t1;
      }
      return { samples: [], batch: 0 };
    }
    const lo = Math.min(this.lastBelowT0 || t0, t1);
    const observedAt = (lo + t1) / 2;
    this.bracket.add(Math.max(0, t1 - lo));
    const batch = upTo - this.attributed;
    if (batch > this.stale.worstBatch) this.stale.worstBatch = batch;
    if (batch > 1) this.stale.batches++;
    const samples: number[] = [];
    while (this.attributed < upTo) samples.push(Math.max(0, observedAt - this.sentAt[this.attributed++ - this.base]!));
    this.compact();
    this.stale.unchangedSincePolls = 0;
    this.stale.unchangedSinceMs = 0;
    this.lastBelowT0 = t1;
    return { samples, batch };
  }

  /** How long the reading has been stuck while events were outstanding. */
  stuckForMs(now: number): number {
    return this.stale.unchangedSinceMs ? now - this.stale.unchangedSinceMs : 0;
  }

  /**
   * Was one reading responsible for a large share of the run? If so the
   * percentiles describe a refresh, not per-event latency.
   */
  freshness(): {
    worstBatch: number;
    batches: number;
    batchShare: number;
    stalePolls: number;
    folded: number;
    verdict: "unknown" | "incremental" | "coarse" | "batched";
  } {
    const worst = this.stale.worstBatch;
    const share = this.attributed > 0 ? worst / this.attributed : 0;
    return {
      worstBatch: worst,
      batches: this.stale.batches,
      batchShare: Math.round(share * 1000) / 1000,
      stalePolls: this.stale.unchangedSincePolls,
      folded: this.folded,
      verdict:
        this.attributed === 0
          ? "unknown"
          : share >= 0.25 || (worst > 20 && this.stale.batches <= 3)
            ? "batched"
            : worst > 5
              ? "coarse"
              : "incremental",
    };
  }
}

/**
 * Pipelined poll driver: issues a request every `intervalMs` up to
 * `concurrency` in flight, rather than waiting for each response before
 * starting the next. That decouples the measurement's resolution from the
 * endpoint's response time, which matters because current_usage is a heavy read.
 */
export class PollStats {
  issued = 0;
  completed = 0;
  failed = 0;
  inFlight = 0;
  firstAt = 0;
  lastAt = 0;
  readonly rtt = new Series();

  begin(t0: number) {
    this.issued++;
    this.inFlight++;
    if (!this.firstAt) this.firstAt = t0;
  }

  end(t0: number, t1: number, ok: boolean) {
    if (ok) {
      this.completed++;
      this.lastAt = t1;
      this.rtt.add(t1 - t0);
    } else {
      this.failed++;
    }
    this.inFlight--;
  }

  snapshot(bracket: Series) {
    const spanMs = this.firstAt && this.lastAt > this.firstAt ? this.lastAt - this.firstAt : 0;
    const rtt = this.rtt.percentiles();
    const b = bracket.percentiles();
    return {
      issued: this.issued,
      completed: this.completed,
      failed: this.failed,
      inFlight: this.inFlight,
      perSecond: spanMs ? Math.round((this.completed / spanMs) * 1000 * 10) / 10 : 0,
      rttP50: rtt?.p50 ?? null,
      rttP95: rtt?.p95 ?? null,
      // Half the bracket each crossing was pinned inside: the actual uncertainty
      // of a sample, measured rather than assumed.
      resolutionMs: b ? Math.round(b.p50 / 2) : null,
      bracketP95Ms: b ? Math.round(b.p95) : null,
    };
  }
}
