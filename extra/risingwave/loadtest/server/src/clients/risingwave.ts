import pg from "pg";
import { getConfig } from "../config.js";

let pool: pg.Pool | null = null;
let poolUrl = "";

/**
 * RisingWave speaks pgwire. Cloud requires TLS and presents a cert chain node's
 * default verifier often rejects, so sslmode=require means "encrypt, don't verify"
 * here — same posture as `psql sslmode=require`, which also does not verify.
 */
function getPool(): pg.Pool {
  const url = getConfig().risingwave.url;
  if (pool && poolUrl === url) return pool;
  if (pool) void pool.end().catch(() => {});
  const wantsSsl = /sslmode=(require|verify-ca|verify-full)/.test(url) || /\.risingwave\.cloud/.test(url);
  pool = new pg.Pool({
    connectionString: url,
    ssl: wantsSsl ? { rejectUnauthorized: false } : undefined,
    max: 4,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 10_000,
    // Timestamps are compared as epoch millis computed server-side; make sure the
    // session agrees with the naive-UTC convention the pipeline stores.
    options: "-c timezone=UTC",
  });
  pool.on("error", () => {});
  poolUrl = url;
  return pool;
}

export async function rwQuery<T extends pg.QueryResultRow = pg.QueryResultRow>(
  sql: string,
  params: unknown[] = [],
): Promise<T[]> {
  const res = await getPool().query<T>(sql, params);
  return res.rows;
}

export async function rwNowMs(): Promise<number> {
  const rows = await rwQuery<{ ms: string }>("SELECT (extract(epoch from now())*1000)::bigint AS ms");
  return Number(rows[0]?.ms ?? 0);
}

export async function rwHealth(): Promise<{ ok: boolean; version?: string; error?: string }> {
  try {
    const rows = await rwQuery<{ version: string }>("SELECT version() AS version");
    return { ok: true, version: String(rows[0]?.version ?? "") };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

export type RwTableKey = "rwEnriched" | "rwExpanded";

const rwTable = (key: RwTableKey) =>
  key === "rwEnriched" ? getConfig().risingwave.enrichedTable : getConfig().risingwave.expandedTable;

/**
 * Which clocks does this relation actually carry? Detected rather than assumed,
 * because the two firewall tables differ and adding a clock column is a schema
 * change: events_enriched has kafka_timestamp + rw_received_at, events_expanded
 * additionally has rw_expanded_at (its own emit barrier).
 */
export async function rwTableCheck(key: RwTableKey) {
  const name = rwTable(key);
  try {
    const rows = await rwQuery<{ name: string }>(
      `SELECT column_name AS name FROM information_schema.columns WHERE table_name = $1`,
      [name],
    );
    const cols = new Set(rows.map((r) => r.name));
    if (cols.size === 0) return { key, table: name, ok: false, error: "relation not found", columns: [] as string[] };
    if (!cols.has("transaction_id"))
      return { key, table: name, ok: false, error: "missing transaction_id", columns: [...cols] };
    return {
      key,
      table: name,
      ok: true,
      hasRwReceivedAt: cols.has("rw_received_at"),
      hasKafkaTimestamp: cols.has("kafka_timestamp"),
      hasIngestedAt: cols.has("ingested_at"),
      hasRwExpandedAt: cols.has("rw_expanded_at"),
      columns: [...cols],
    };
  } catch (e) {
    return { key, table: name, ok: false, error: (e as Error).message, columns: [] as string[] };
  }
}

export type RwStamps = {
  txid: string;
  ingestedMs: number | null;
  kafkaMs: number | null;
  rwReceivedMs: number | null;
  rwExpandedMs: number | null;
};

const MS = (col: string) => `(extract(epoch from ${col})*1000)::bigint`;

export type RwCaps = { rw: boolean; kafka: boolean; ingested: boolean; expanded: boolean };

function stampSelect(caps: RwCaps) {
  return [
    "transaction_id AS txid",
    caps.ingested ? `min(${MS("ingested_at")})::bigint AS ingested_ms` : "NULL::bigint AS ingested_ms",
    caps.kafka ? `min(${MS("kafka_timestamp")})::bigint AS kafka_ms` : "NULL::bigint AS kafka_ms",
    caps.rw ? `min(${MS("rw_received_at")})::bigint AS rw_ms` : "NULL::bigint AS rw_ms",
    caps.expanded ? `min(${MS("rw_expanded_at")})::bigint AS rw_expanded_ms` : "NULL::bigint AS rw_expanded_ms",
  ].join(", ");
}

const row2stamps = (r: Record<string, unknown>): RwStamps => ({
  txid: String(r.txid),
  ingestedMs: r.ingested_ms == null ? null : Number(r.ingested_ms),
  kafkaMs: r.kafka_ms == null ? null : Number(r.kafka_ms),
  rwReceivedMs: r.rw_ms == null ? null : Number(r.rw_ms),
  rwExpandedMs: r.rw_expanded_ms == null ? null : Number(r.rw_expanded_ms),
});

/** Visibility + stamps for the in-flight probe ids. GROUP BY: expanded fans out per charge. */
export async function rwSeen(
  key: RwTableKey,
  txids: string[],
  caps: RwCaps,
): Promise<RwStamps[]> {
  if (txids.length === 0) return [];
  const rows = await rwQuery(
    `SELECT ${stampSelect(caps)} FROM ${rwTable(key)}
     WHERE transaction_id = ANY($1::varchar[]) GROUP BY transaction_id`,
    [txids],
  );
  return rows.map(row2stamps);
}

/**
 * Incremental stamp sweep over a whole run, watermarked on rw_received_at. Only
 * available where that column exists; the caller falls back to counts otherwise.
 */
export async function rwSweep(
  key: RwTableKey,
  prefix: string,
  sinceMs: number,
  caps: RwCaps,
): Promise<RwStamps[]> {
  // Watermark on the stage's own emit clock when it has one (monotone with
  // processing); fall back to the carried source pickup time.
  const wmCol = caps.expanded ? "rw_expanded_at" : caps.rw ? "rw_received_at" : null;
  if (!wmCol) return [];
  const rows = await rwQuery(
    `SELECT ${stampSelect(caps)} FROM ${rwTable(key)}
     WHERE transaction_id LIKE $1 AND ${wmCol} > to_timestamp($2::double precision / 1000)
     GROUP BY transaction_id`,
    [prefix + "%", sinceMs],
  );
  return rows.map(row2stamps);
}

export async function rwCount(key: RwTableKey, prefix: string): Promise<number> {
  const rows = await rwQuery<{ n: string }>(
    `SELECT count(DISTINCT transaction_id) AS n FROM ${rwTable(key)} WHERE transaction_id LIKE $1`,
    [prefix + "%"],
  );
  return Number(rows[0]?.n ?? 0);
}

export async function rwClose() {
  if (pool) await pool.end().catch(() => {});
  pool = null;
}
