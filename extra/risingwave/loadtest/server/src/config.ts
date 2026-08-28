import { existsSync, readFileSync, renameSync } from "node:fs";
import { resolve } from "node:path";
import { ROOT, RUNS_DIR } from "./paths.js";
import { getSetting, putSetting, settingUpdatedAt, DB_PATH } from "./store/db.js";

export { ROOT, RUNS_DIR };

/**
 * Everything the app needs to reach the three clouds, plus the knobs that decide
 * how latency is measured.
 *
 * Owned by the Setup screen and stored in SQLite (loadtest.db). There is no
 * dotfile to keep in sync: the UI is the only way in, and `GET /api/config`
 * never returns a secret.
 */
export type Config = {
  lago: { apiUrl: string; apiKey: string };
  risingwave: { url: string; enrichedTable: string; expandedTable: string };
  clickhouse: {
    url: string;
    user: string;
    password: string;
    database: string;
    rwEnrichedTable: string;
    rwExpandedTable: string;
    goEnrichedTable: string;
    goExpandedTable: string;
  };
  /**
   * Direct produce to Redpanda, for when the Lago API is the throughput ceiling
   * rather than the thing being measured. Only used when a run's transport is
   * `kafka`; the read paths (usage, wallets, discovery) always go through Lago.
   */
  kafka: {
    /** Comma-separated host:port. From outside Docker this is the EXTERNAL
     * listener (localhost:19092 in the dev stack), not redpanda:9092. */
    brokers: string;
    /** Must be the topic the pipeline consumes — LAGO_KAFKA_RAW_EVENTS_TOPIC. */
    topic: string;
    clientId: string;
    /** -1 all replicas, 1 leader only, 0 fire-and-forget (no ack, so no round
     * trip to measure and no error to report — throughput only). */
    acks: number;
    compression: "none" | "gzip";
    /**
     * How produced messages are partitioned.
     *
     *  subscription  key = `<organization_id>-<external_subscription_id>`, exactly
     *                what Events::KafkaProducerService writes. Faithful, but the
     *                key set is only as wide as the run's target list — 2 targets
     *                means 2 keys, which land on at most 2 partitions no matter
     *                how many the topic has, and cap RisingWave's source
     *                parallelism at the same number.
     *  none          no key, so kafkajs round-robins every message across all
     *                partitions. Nothing downstream is partition-affine (stage-0
     *                dedup shuffles on the event identity), so this changes only
     *                the spread — and it is the only way a load test can reach
     *                every partition. Default, because that is what load runs
     *                need; switch to `subscription` to reproduce the API's own
     *                partitioning.
     */
    partitionKey: "subscription" | "none";
    ssl: boolean;
    sasl: { mechanism: "" | "plain" | "scram-sha-256" | "scram-sha-512"; username: string; password: string };
    /** Blank = read the UUID from GET /api/v1/organizations at preflight. */
    organizationId: string;
    /** The `source` the API stamps. Both consumers read `http_ruby` as "custom
     * expressions already evaluated", so changing it measures another path. */
    source: string;
  };
  /** How the sender talks HTTP to Lago. Shared by every request the app makes. */
  http: {
    /** Max TCP connections to the Lago origin. With h2 each one multiplexes
     * many requests, so a handful is plenty; without it this IS the in-flight
     * ceiling, whatever the run asks for. */
    connections: number;
    /** Offer HTTP/2 in the TLS handshake. Falls back to 1.1 when not offered. */
    h2: boolean;
  };
  measurement: {
    /** Visibility poll tick. This IS the resolution of every polled latency. */
    pollTickMs: number;
    /** Stamp sweep + funnel count cadence. Cheaper than the tick, so slower. */
    sweepMs: number;
    /** Give up waiting for a probe after this long and record it as a timeout. */
    probeTimeoutMs: number;
    /** current_usage poll interval. With pipelining this, not the API's
     * response time, is what sets the resolution of the usage measurement. */
    usagePollMs: number;
    /** How many current_usage requests may be in flight at once. */
    usagePollConcurrency: number;
    /** GET /wallets poll interval. The reading is a stored column, so polling
     * never triggers the refresh being timed — but the index endpoint serves the
     * whole wallet payload, so measured RTT can rival current_usage. */
    walletPollMs: number;
    /** How many /wallets requests may be in flight at once. */
    walletPollConcurrency: number;
  };
};

const SETTINGS_KEY = "config";

/**
 * Table names default to the POC's own naming so a fresh install only has to
 * fill in three URLs and two secrets. Everything else is a placeholder that
 * fails its health check loudly rather than silently measuring the wrong thing.
 */
const DEFAULTS: Config = {
  lago: { apiUrl: "", apiKey: "" },
  risingwave: { url: "", enrichedTable: "events_enriched", expandedTable: "events_expanded" },
  clickhouse: {
    url: "",
    user: "default",
    password: "",
    database: "default",
    rwEnrichedTable: "events_enriched_rw_shadow",
    rwExpandedTable: "events_enriched_expanded_rw_shadow",
    goEnrichedTable: "events_enriched",
    goExpandedTable: "events_enriched_expanded",
  },
  kafka: {
    brokers: "localhost:19092",
    topic: "events-raw",
    clientId: "lago-rw-loadtest",
    acks: 1,
    compression: "none",
    partitionKey: "none",
    ssl: false,
    sasl: { mechanism: "", username: "", password: "" },
    organizationId: "",
    source: "http_ruby",
  },
  http: { connections: 64, h2: true },
  measurement: {
    pollTickMs: 200,
    sweepMs: 2000,
    probeTimeoutMs: 120_000,
    usagePollMs: 100,
    usagePollConcurrency: 4,
    walletPollMs: 100,
    walletPollConcurrency: 4,
  },
};

const merge = (base: Config, patch: Partial<Config> | null): Config => ({
  lago: { ...base.lago, ...patch?.lago },
  risingwave: { ...base.risingwave, ...patch?.risingwave },
  clickhouse: { ...base.clickhouse, ...patch?.clickhouse },
  kafka: { ...base.kafka, ...patch?.kafka, sasl: { ...base.kafka.sasl, ...patch?.kafka?.sasl } },
  http: { ...base.http, ...patch?.http },
  measurement: { ...base.measurement, ...patch?.measurement },
});

/**
 * One-time import for installs that predate the SQLite store: an existing
 * config.json or .env is read once, written into the database, and then left
 * alone (the .env is renamed so it cannot drift into being a second source of
 * truth). After this, Setup is the only way to change anything.
 */
function importLegacy(): { config: Config; imported: string | null } {
  const jsonPath = resolve(ROOT, "config.json");
  if (existsSync(jsonPath)) {
    try {
      const saved = JSON.parse(readFileSync(jsonPath, "utf8")) as Partial<Config>;
      renameSync(jsonPath, `${jsonPath}.imported`);
      return { config: merge(DEFAULTS, saved), imported: "config.json" };
    } catch {
      /* fall through to .env */
    }
  }

  const envPath = resolve(ROOT, ".env");
  if (existsSync(envPath)) {
    try {
      const env: Record<string, string> = {};
      for (const line of readFileSync(envPath, "utf8").split("\n")) {
        const m = /^\s*([A-Z0-9_]+)\s*=\s*(.*)$/.exec(line);
        if (m?.[1]) env[m[1]] = (m[2] ?? "").trim().replace(/^["']|["']$/g, "");
      }
      const c = merge(DEFAULTS, {
        lago: { apiUrl: env.LAGO_API_URL ?? "", apiKey: env.LAGO_API_KEY ?? "" },
        risingwave: {
          url: env.RW_URL ?? "",
          enrichedTable: env.RW_ENRICHED_TABLE ?? DEFAULTS.risingwave.enrichedTable,
          expandedTable: env.RW_EXPANDED_TABLE ?? DEFAULTS.risingwave.expandedTable,
        },
        clickhouse: {
          url: env.CH_URL ?? "",
          user: env.CH_USER ?? DEFAULTS.clickhouse.user,
          password: env.CH_PASSWORD ?? "",
          database: env.CH_DATABASE ?? DEFAULTS.clickhouse.database,
          rwEnrichedTable: env.CH_RW_ENRICHED_TABLE ?? DEFAULTS.clickhouse.rwEnrichedTable,
          rwExpandedTable: env.CH_RW_EXPANDED_TABLE ?? DEFAULTS.clickhouse.rwExpandedTable,
          goEnrichedTable: env.CH_GO_ENRICHED_TABLE ?? DEFAULTS.clickhouse.goEnrichedTable,
          goExpandedTable: env.CH_GO_EXPANDED_TABLE ?? DEFAULTS.clickhouse.goExpandedTable,
        },
      });
      if (c.lago.apiUrl || c.risingwave.url || c.clickhouse.url) {
        renameSync(envPath, `${envPath}.imported`);
        return { config: c, imported: ".env" };
      }
    } catch {
      /* ignore and start empty */
    }
  }
  return { config: DEFAULTS, imported: null };
}

let current: Config;
let importedFrom: string | null = null;

{
  const stored = getSetting<Partial<Config>>(SETTINGS_KEY);
  if (stored) {
    current = merge(DEFAULTS, stored);
  } else {
    const { config, imported } = importLegacy();
    current = config;
    importedFrom = imported;
    if (imported) putSetting(SETTINGS_KEY, current);
  }
}

export function getConfig(): Config {
  return current;
}

export function saveConfig(patch: Partial<Config>): Config {
  current = merge(current, patch);
  putSetting(SETTINGS_KEY, current);
  return current;
}

/** Enough to attempt a run? The UI sends the user to Setup when this is false. */
export function isConfigured(): boolean {
  return Boolean(current.lago.apiUrl && current.lago.apiKey && current.risingwave.url && current.clickhouse.url);
}

export function storeInfo() {
  return {
    dbPath: DB_PATH,
    savedAt: settingUpdatedAt(SETTINGS_KEY),
    importedFrom,
    configured: isConfigured(),
  };
}

/** Secrets never leave the server; the UI gets a masked view. */
export function redact(c: Config) {
  const mask = (s: string) => (s ? `${s.slice(0, 4)}…${s.slice(-2)} (${s.length} chars)` : "");
  return {
    ...c,
    lago: { ...c.lago, apiKey: mask(c.lago.apiKey), apiKeySet: Boolean(c.lago.apiKey) },
    risingwave: { ...c.risingwave, url: c.risingwave.url.replace(/\/\/([^:]+):[^@]*@/, "//$1:***@") },
    clickhouse: { ...c.clickhouse, password: mask(c.clickhouse.password), passwordSet: Boolean(c.clickhouse.password) },
    kafka: {
      ...c.kafka,
      sasl: {
        ...c.kafka.sasl,
        password: mask(c.kafka.sasl.password),
        passwordSet: Boolean(c.kafka.sasl.password),
      },
    },
  };
}
