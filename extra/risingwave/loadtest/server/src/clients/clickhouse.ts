import { getConfig } from "../config.js";
import { describeFetchError } from "./lago.js";

/** Single-quote escape. Transaction ids are app-generated, this is belt-and-braces. */
export const q = (s: string) => `'${s.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}'`;

/**
 * What a query is for, stamped on it so ClickHouse can say who is asking. The
 * load test, the Lago API and Grafana all connect as the same user, so without
 * this a "who is burning CPU" question against system.query_log cannot tell
 * them apart — and in one 20k/s run it mattered (see chSweep). Lands in
 * `log_comment` as `lago-rw-loadtest:<purpose>` and in `http_user_agent`.
 */
export type ChPurpose = "health" | "clock" | "schema" | "probe-seen" | "stamp-sweep" | "funnel-count";

export const CH_USER_AGENT = "lago-rw-loadtest";

async function exec(sql: string, purpose: ChPurpose): Promise<string> {
  const c = getConfig().clickhouse;
  const url = new URL(c.url);
  url.searchParams.set("database", c.database);
  // Cloud rejects mutations from a read-only role; these are all SELECTs anyway.
  url.searchParams.set("default_format", "JSONCompact");
  url.searchParams.set("log_comment", `${CH_USER_AGENT}:${purpose}`);
  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: {
        "X-ClickHouse-User": c.user,
        "X-ClickHouse-Key": c.password,
        "Content-Type": "text/plain; charset=utf-8",
        "User-Agent": `${CH_USER_AGENT}/${purpose}`,
      },
      body: sql,
    });
  } catch (e) {
    throw new Error(describeFetchError(e, url));
  }
  const text = await res.text();
  if (!res.ok) {
    const hint = res.status === 401 || res.status === 403 ? " — check the ClickHouse user/password" : "";
    throw new Error(`ClickHouse ${res.status}${hint}: ${text.slice(0, 400)}`);
  }
  return text;
}

/** Returns rows as arrays, in the column order of the SELECT. */
export async function chQuery(sql: string, purpose: ChPurpose): Promise<unknown[][]> {
  const text = await exec(`${sql} FORMAT JSONCompact`, purpose);
  if (!text.trim()) return [];
  return (JSON.parse(text) as { data: unknown[][] }).data;
}

export async function chNowMs(): Promise<number> {
  const rows = await chQuery("SELECT toUnixTimestamp64Milli(now64(3))", "clock");
  return Number(rows[0]?.[0] ?? 0);
}

export async function chHealth(): Promise<{ ok: boolean; version?: string; error?: string }> {
  try {
    const rows = await chQuery("SELECT version()", "health");
    return { ok: true, version: String(rows[0]?.[0] ?? "") };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

export type ChTableKey = "chRwEnriched" | "chRwExpanded" | "chGoEnriched" | "chGoExpanded";

export function chTable(key: ChTableKey): { name: string } {
  const c = getConfig().clickhouse;
  switch (key) {
    case "chRwEnriched":
      return { name: c.rwEnrichedTable };
    case "chRwExpanded":
      return { name: c.rwExpandedTable };
    case "chGoEnriched":
      return { name: c.goEnrichedTable };
    case "chGoExpanded":
      return { name: c.goExpandedTable };
  }
}

/**
 * Narrows a lookup onto the PRIMARY KEY prefix of both table shapes
 * (organization_id, code, external_subscription_id, ..., toDate(timestamp)).
 *
 * Without this, "WHERE transaction_id = ..." is a full scan — survivable on a
 * shadow table, fatal on the production events_enriched_expanded (240M rows in
 * dev alone): the poll times out, the connection drops, and the stage silently
 * reports nothing. The run knows which subscriptions and metric codes it is
 * sending to and when it started, so it can hand the index everything it needs.
 *
 * NOTE ON `FINAL`: deliberately absent. Deduplication is irrelevant to every
 * question asked here — existence is existence, min(enriched_at) returns the
 * FIRST insert either way, and uniqExact() dedupes counts by itself. FINAL would
 * force a merge on every poll for no gain in correctness.
 */
export type ChScope = {
  /** The organization: FIRST column of both keys. Without it the index is only
   * usable through generic exclusion on the later columns. Null when preflight
   * could not read it — the lookups still work, just less selectively. */
  orgId: string | null;
  subs: string[];
  codes: string[];
  /**
   * Lower bound on the EVENT timestamp, which IS in the key (after
   * toDate(timestamp), which ClickHouse derives from it). This is the only
   * predicate that bounds a scan in time: `enriched_at`, the stamp every sweep
   * and dashboard wants to filter on, is not in the key at all. Callers pass
   * the run start for whole-run questions and a moving floor for anything
   * that only cares about recent rows.
   */
  sinceMs: number;
};

export function scopeClause(scope: ChScope | undefined): string {
  if (!scope) return "";
  const parts: string[] = [];
  if (scope.orgId) parts.push(`organization_id = ${q(scope.orgId)}`);
  if (scope.subs.length) parts.push(`external_subscription_id IN (${scope.subs.map(q).join(",")})`);
  if (scope.codes.length) parts.push(`code IN (${scope.codes.map(q).join(",")})`);
  if (scope.sinceMs) parts.push(`timestamp >= fromUnixTimestamp64Milli(toInt64(${Math.floor(scope.sinceMs)}))`);
  return parts.length ? ` AND ${parts.join(" AND ")}` : "";
}

/** Does the table exist and carry the columns we read? Checked before a run. */
export async function chTableCheck(key: ChTableKey) {
  const { name } = chTable(key);
  const db = getConfig().clickhouse.database;
  try {
    const rows = await chQuery(
      `SELECT name FROM system.columns WHERE database = ${q(db)} AND table = ${q(name)}`,
    "schema",
    );
    const cols = new Set(rows.map((r) => String(r[0])));
    if (cols.size === 0) return { key, table: name, ok: false, error: "table not found" };
    const missing = ["transaction_id", "enriched_at"].filter((c) => !cols.has(c));
    return missing.length
      ? { key, table: name, ok: false, error: `missing column(s): ${missing.join(", ")}` }
      : { key, table: name, ok: true };
  } catch (e) {
    return { key, table: name, ok: false, error: (e as Error).message };
  }
}

/**
 * First-seen lookup for a small set of in-flight probe transaction ids.
 * The expanded tables hold one row per (event, charge), hence the min()/GROUP BY:
 * the event is "there" as soon as its first row is.
 */
export async function chSeen(
  key: ChTableKey,
  txids: string[],
  scope?: ChScope,
): Promise<Map<string, number>> {
  if (txids.length === 0) return new Map();
  const { name } = chTable(key);
  const rows = await chQuery(
    `SELECT transaction_id, min(toUnixTimestamp64Milli(enriched_at)) AS at
     FROM ${name}
     WHERE transaction_id IN (${txids.map(q).join(",")})${scopeClause(scope)}
     GROUP BY transaction_id`,
    "probe-seen",
  );
  return new Map(rows.map((r) => [String(r[0]), Number(r[1])]));
}

/**
 * Incremental stamp sweep for every event of a run: only rows stamped after the
 * previous sweep come back.
 *
 * "Come back" is not "get scanned". `enriched_at` is not in the key, so on its
 * own this predicate makes ClickHouse read every row the scope admits — and a
 * scope bounded at the run start grows with the run: at 20k events/s that was
 * 12M rows per table rescanned every 2 s after ten minutes, which showed up as
 * ClickHouse spending 3.6 cores on reads while writes cost 0.17 (measured
 * 2026-09-07). The caller therefore hands in a scope whose `sinceMs` is a
 * MOVING floor on the event timestamp (in the key), so the scan is bounded by
 * how late a row can still be, not by how long the run has been going.
 *
 * Each returned row is a transaction id whose FIRST stamp falls in this window
 * (rows of one event share the insert stamp), so the row count is also the
 * per-window funnel count — no separate uniqExact() over the whole run.
 */
export async function chSweep(
  key: ChTableKey,
  prefix: string,
  sinceMs: number,
  scope?: ChScope,
): Promise<{ txid: string; at: number }[]> {
  const { name } = chTable(key);
  const rows = await chQuery(
    `SELECT transaction_id, min(toUnixTimestamp64Milli(enriched_at)) AS at
     FROM ${name}
     WHERE transaction_id LIKE ${q(prefix + "%")}
       AND enriched_at > fromUnixTimestamp64Milli(toInt64(${sinceMs}))${scopeClause(scope)}
     GROUP BY transaction_id`,
    "stamp-sweep",
  );
  return rows.map((r) => ({ txid: String(r[0]), at: Number(r[1]) }));
}

/**
 * How many distinct events of this run have reached the table. Exact, and
 * priced accordingly: it reads every row of the run, so it runs ONCE at the
 * end — the live funnel is accumulated from the sweeps instead.
 */
export async function chCount(key: ChTableKey, prefix: string, scope?: ChScope): Promise<number> {
  const { name } = chTable(key);
  const rows = await chQuery(
    `SELECT uniqExact(transaction_id) FROM ${name}
     WHERE transaction_id LIKE ${q(prefix + "%")}${scopeClause(scope)}`,
    "funnel-count",
  );
  return Number(rows[0]?.[0] ?? 0);
}
