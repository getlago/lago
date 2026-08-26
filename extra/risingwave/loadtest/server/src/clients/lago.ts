import { Agent, fetch } from "undici";
import { getConfig } from "../config.js";

export type LagoError = { status: number; body: string };

/**
 * One tuned connection pool for every call to Lago, instead of Node's built-in
 * fetch pool.
 *
 * At a high send rate the number of requests a sender can have outstanding IS
 * its throughput ceiling (rate = in-flight / round trip), so the pool has to
 * hold hundreds of concurrent requests against a remote API without opening one
 * TLS connection per request. HTTP/2 is what makes that cheap — hundreds of
 * streams over a handful of sockets — and it is negotiated by ALPN, so a Lago
 * that only speaks HTTP/1.1 transparently falls back to `connections` sockets.
 *
 * Node's own fetch cannot be pointed at this pool (its undici is a separate
 * module instance), which is why the client imports undici's fetch directly.
 */
let pool: Agent | null = null;
let poolKey = "";

function dispatcher(): Agent {
  const { connections, h2 } = getConfig().http;
  const key = `${connections}:${h2}`;
  if (pool && poolKey === key) return pool;
  const previous = pool;
  pool = new Agent({
    connections: Math.max(1, connections),
    allowH2: h2,
    keepAliveTimeout: 60_000,
    keepAliveMaxTimeout: 600_000,
    connect: { timeout: 15_000 },
  });
  poolKey = key;
  void previous?.close().catch(() => {});
  return pool;
}

/**
 * Node's fetch throws a bare "fetch failed" and hides the real reason in
 * `cause`. Unwrap it, because "fetch failed" is useless in a UI: a wrong
 * hostname, a closed port, an expired certificate and a timeout all look
 * identical and have completely different fixes.
 */
export function describeFetchError(e: unknown, target: URL | string): string {
  const url = typeof target === "string" ? target : target.toString();
  const host = (() => {
    try {
      return new URL(url).host;
    } catch {
      return url;
    }
  })();
  const err = e as { message?: string; cause?: { code?: string; message?: string; errno?: number } };
  const cause = err?.cause;
  const code = cause?.code;
  const detail = cause?.message ?? err?.message ?? String(e);
  switch (code) {
    case "ENOTFOUND":
    case "EAI_AGAIN":
      return `cannot resolve host "${host}" (DNS ${code}) — check the URL; note that *.example.com is a reserved placeholder and never resolves`;
    case "ECONNREFUSED":
      return `nothing is listening on "${host}" (connection refused) — check the port, and whether this machine can reach it`;
    case "ETIMEDOUT":
    case "UND_ERR_CONNECT_TIMEOUT":
      return `timed out connecting to "${host}" — usually a firewall, VPN or IP allowlist between here and the cloud`;
    case "CERT_HAS_EXPIRED":
    case "UNABLE_TO_VERIFY_LEAF_SIGNATURE":
    case "DEPTH_ZERO_SELF_SIGNED_CERT":
      return `TLS verification failed for "${host}" (${code})`;
    case "ECONNRESET":
      return `connection to "${host}" was reset — often a proxy or an over-long query`;
    default:
      return `request to "${host}" failed: ${code ? `${code} — ` : ""}${detail}`;
  }
}

function url(path: string, params: Record<string, string | number | undefined> = {}) {
  const base = getConfig().lago.apiUrl.replace(/\/+$/, "");
  const u = new URL(base + path);
  for (const [k, v] of Object.entries(params)) if (v !== undefined) u.searchParams.set(k, String(v));
  return u;
}

function headers() {
  return {
    Authorization: `Bearer ${getConfig().lago.apiKey}`,
    "Content-Type": "application/json",
  };
}

async function get<T>(path: string, params?: Record<string, string | number | undefined>): Promise<T> {
  const target = url(path, params);
  let res: Awaited<ReturnType<typeof fetch>>;
  try {
    res = await fetch(target, { headers: headers(), dispatcher: dispatcher() });
  } catch (e) {
    throw new Error(`GET ${path} — ${describeFetchError(e, target)}`);
  }
  const text = await res.text();
  if (!res.ok) {
    const hint =
      res.status === 401 || res.status === 403
        ? " — check the API key"
        : res.status === 404
          ? " — check the API URL (is /api/v1 reachable at this host?)"
          : "";
    throw Object.assign(new Error(`GET ${path} → ${res.status}${hint}: ${text.slice(0, 200)}`), { status: res.status });
  }
  return JSON.parse(text) as T;
}

/** Walks Lago's `meta.next_page` pagination to the end (bounded, so a bad meta can't spin). */
async function getAll<T>(path: string, collection: string, perPage = 100, maxPages = 25): Promise<T[]> {
  const out: T[] = [];
  let page = 1;
  for (let i = 0; i < maxPages; i++) {
    const body = await get<Record<string, unknown>>(path, { page, per_page: perPage });
    const items = (body[collection] as T[] | undefined) ?? [];
    out.push(...items);
    const next = (body.meta as { next_page?: number | null } | undefined)?.next_page;
    if (!next || next === page) break;
    page = next;
  }
  return out;
}

export type LagoSubscription = {
  lago_id: string;
  external_id: string;
  external_customer_id: string;
  plan_code: string;
  status: string;
  name?: string | null;
};

/** `amount` is the per-unit price of a standard charge, in currency units. */
export type LagoChargeProperties = {
  pricing_group_keys?: string[];
  grouped_by?: string[];
  amount?: string | number;
};

export type LagoChargeFilter = {
  values?: Record<string, string[]>;
  invoice_display_name?: string | null;
  /** Per-filter pricing group keys and price override the charge's. */
  properties?: LagoChargeProperties;
};

export type LagoCharge = {
  lago_id: string;
  billable_metric_code: string;
  charge_model: string;
  filters?: LagoChargeFilter[];
  properties?: LagoChargeProperties;
};

/** pricing_group_keys, tolerating the deprecated grouped_by alias. */
export const groupKeysOf = (p?: { pricing_group_keys?: string[]; grouped_by?: string[] }): string[] =>
  (p?.pricing_group_keys ?? p?.grouped_by ?? []).filter((k) => typeof k === "string" && k.length > 0);

/** Per-unit price in currency units, or null when this charge has none declared. */
export const amountOf = (p?: LagoChargeProperties): number | null => {
  const n = Number(p?.amount);
  return Number.isFinite(n) ? n : null;
};

export type LagoPlan = { lago_id: string; code: string; name: string; interval: string; charges?: LagoCharge[] };

export type LagoBillableMetric = {
  lago_id: string;
  code: string;
  name: string;
  aggregation_type: string;
  field_name?: string | null;
  recurring?: boolean;
};

export const listSubscriptions = () =>
  getAll<LagoSubscription>("/api/v1/subscriptions", "subscriptions");
export const listPlans = () => getAll<LagoPlan>("/api/v1/plans", "plans");
export const listBillableMetrics = () => getAll<LagoBillableMetric>("/api/v1/billable_metrics", "billable_metrics");

export type LagoOrganization = {
  lago_id: string;
  name: string;
  /** "postgres" or "clickhouse" — decides `source_metadata.api_post_processed`
   * and, more importantly, whether the API is doing anything a direct produce
   * would skip (the Postgres events row and PostProcessJob). */
  events_store?: string;
};

/**
 * The organization behind the API key. Direct produce needs its UUID, because
 * `organization_id` is the join key the whole pipeline resolves subscriptions,
 * charges and filters on — the API stamps it, so a Kafka producer has to too.
 */
export const fetchOrganization = async (): Promise<LagoOrganization> =>
  (await get<{ organization: LagoOrganization }>("/api/v1/organizations")).organization;

export async function lagoHealth(): Promise<{ ok: boolean; error?: string; metrics?: number }> {
  try {
    const body = await get<{ meta?: { total_count?: number } }>("/api/v1/billable_metrics", { per_page: 1 });
    return { ok: true, metrics: body.meta?.total_count };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

export type EventPayload = {
  transaction_id: string;
  external_subscription_id: string;
  code: string;
  timestamp: number;
  properties?: Record<string, string | number>;
  precise_total_amount_cents?: string;
};

export type SendResult = {
  ok: boolean;
  status: number;
  /** Wall-clock ms just before the request left, and the round trip in ms. */
  sentAt: number;
  apiMs: number;
  error?: string;
};

/** Lago refuses a batch longer than this (LAGO_EVENTS_BATCH_MAX_LENGTH). */
export const MAX_EVENT_BATCH = 100;

/**
 * One HTTP request carrying one or many events.
 *
 * A single event goes to POST /events and many to POST /events/batch, so a
 * batch of one is byte-for-byte the request a customer's integration sends —
 * batching changes how many requests carry the load, never what the API is
 * asked to do with each event.
 */
export async function postEvents(payloads: EventPayload[]): Promise<SendResult> {
  const batched = payloads.length > 1;
  const path = batched ? "/api/v1/events/batch" : "/api/v1/events";
  const body = batched ? { events: payloads } : { event: payloads[0] };
  const sentAt = Date.now();
  const t0 = performance.now();
  const target = url(path);
  try {
    const res = await fetch(target, {
      method: "POST",
      headers: headers(),
      body: JSON.stringify(body),
      dispatcher: dispatcher(),
    });
    const apiMs = performance.now() - t0;
    if (!res.ok) {
      const text = await res.text();
      return { ok: false, status: res.status, sentAt, apiMs, error: text.slice(0, 200) };
    }
    // Drain the body so the connection is reusable by keep-alive.
    await res.arrayBuffer();
    return { ok: true, status: res.status, sentAt, apiMs };
  } catch (e) {
    return { ok: false, status: 0, sentAt, apiMs: performance.now() - t0, error: describeFetchError(e, target) };
  }
}

export const postEvent = (payload: EventPayload): Promise<SendResult> => postEvents([payload]);

export type ChargeUsage = {
  units: string;
  events_count: number;
  amount_cents: number;
  billable_metric: { code: string; aggregation_type?: string };
};

export type CurrentUsage = {
  from_datetime: string;
  to_datetime: string;
  amount_cents: number;
  charges_usage: ChargeUsage[];
};

/**
 * What the API serves right now for one subscription. This is the read path the
 * "reflected in current usage" latency measures, whatever backs it.
 */
export async function currentUsage(
  customerExternalId: string,
  subscriptionExternalId: string,
): Promise<{ usage: CurrentUsage; apiMs: number }> {
  const t0 = performance.now();
  const body = await get<{ customer_usage: CurrentUsage }>(
    `/api/v1/customers/${encodeURIComponent(customerExternalId)}/current_usage`,
    { external_subscription_id: subscriptionExternalId },
  );
  return { usage: body.customer_usage, apiMs: performance.now() - t0 };
}

/**
 * What one metric currently reads on the customer's usage. `units` is the
 * aggregated value (the sum for a sum metric), which is what attribution keys
 * on: the run knows exactly how many units it has sent, so "has usage reached
 * my expected total?" is an exact question. events_count is kept as a fallback
 * for metrics whose units are not a plain number.
 */
export function usageValue(usage: CurrentUsage, metricCode: string): { units: number; eventsCount: number } {
  const rows = (usage.charges_usage ?? []).filter((c) => c.billable_metric?.code === metricCode);
  return {
    units: rows.reduce((n, c) => n + (Number(c.units) || 0), 0),
    eventsCount: rows.reduce((n, c) => n + (Number(c.events_count) || 0), 0),
  };
}

export type LagoWallet = {
  lago_id: string;
  external_customer_id: string;
  code: string | null;
  name: string | null;
  status: string;
  currency: string;
  balance_cents: number;
  ongoing_balance_cents: number;
  ongoing_usage_balance_cents: number;
  credits_ongoing_usage_balance: string | number;
  rate_amount: string | number;
  /** Touched on EVERY refresh, so it moves even when the amount does not.
   * Present only on a Lago that serializes it (added for this POC). */
  last_ongoing_balance_sync_at?: string | null;
  applies_to?: { fee_types?: string[] | null; billable_metric_codes?: string[] | null };
};

/** Every wallet of the organization, so discovery can say who holds one. */
export const listWallets = () => getAll<LagoWallet>("/api/v1/wallets", "wallets");

/**
 * The wallets of ONE customer. This is the read path the "reflected in the
 * customer's wallet" latency measures: `ongoing_usage_balance_cents` is a plain
 * column, written by the wallet refresh the pipeline triggers, so this GET is a
 * cheap row read and never recomputes anything itself.
 */
export async function customerWallets(
  customerExternalId: string,
): Promise<{ wallets: LagoWallet[]; apiMs: number }> {
  const t0 = performance.now();
  const body = await get<{ wallets: LagoWallet[] }>("/api/v1/wallets", {
    external_customer_id: customerExternalId,
    per_page: 100,
  });
  return { wallets: body.wallets ?? [], apiMs: performance.now() - t0 };
}

export type WalletReading = {
  /** Ongoing (unbilled) usage allocated across the customer's active wallets. */
  ongoingUsageCents: number;
  /** balance - ongoing usage: what the customer is shown as remaining. */
  ongoingBalanceCents: number;
  credits: number;
  /** Latest refresh stamp across those wallets, if this Lago exposes it. */
  syncedAtMs: number | null;
  wallets: number;
};

/**
 * One number per reading, summed over the customer's ACTIVE wallets.
 *
 * Summing is the correct aggregation rather than a convenience: ongoing usage is
 * distributed across wallets in priority order and the last applicable wallet
 * absorbs the overflow (it is allowed to go negative), so the total tracks total
 * ongoing usage even when an individual wallet's credits run out mid-run.
 */
export function walletReading(wallets: LagoWallet[]): WalletReading {
  const active = wallets.filter((w) => w.status === "active");
  let syncedAtMs: number | null = null;
  for (const w of active) {
    const t = w.last_ongoing_balance_sync_at ? new Date(w.last_ongoing_balance_sync_at).getTime() : NaN;
    if (Number.isFinite(t)) syncedAtMs = Math.max(syncedAtMs ?? 0, t);
  }
  return {
    ongoingUsageCents: active.reduce((n, w) => n + (Number(w.ongoing_usage_balance_cents) || 0), 0),
    ongoingBalanceCents: active.reduce((n, w) => n + (Number(w.ongoing_balance_cents) || 0), 0),
    credits: active.reduce((n, w) => n + (Number(w.credits_ongoing_usage_balance) || 0), 0),
    syncedAtMs,
    wallets: active.length,
  };
}

/** Server-clock reading from the Date response header, for the skew panel. */
export async function lagoServerTimeMs(): Promise<{ serverMs: number; rttMs: number } | null> {
  const t0 = performance.now();
  try {
    const res = await fetch(url("/api/v1/billable_metrics", { per_page: 1 }), {
      headers: headers(),
      dispatcher: dispatcher(),
    });
    const rttMs = performance.now() - t0;
    await res.arrayBuffer();
    const date = res.headers.get("date");
    if (!date) return null;
    return { serverMs: new Date(date).getTime(), rttMs };
  } catch {
    return null;
  }
}
