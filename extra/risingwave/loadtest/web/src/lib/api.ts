import { useEffect, useRef, useState } from "react";

export type Percentiles = {
  count: number;
  min: number;
  p50: number;
  p95: number;
  p99: number;
  max: number;
  mean: number;
};

export type StageKey =
  | "rwEnriched"
  | "rwExpanded"
  | "chRwEnriched"
  | "chRwExpanded"
  | "chGoEnriched"
  | "chGoExpanded";

export type Segment = {
  key: string;
  label: string;
  kind: "polled" | "stamped";
  stage?: StageKey;
  group: "api" | "risingwave" | "clickhouse-rw" | "clickhouse-go" | "usage" | "wallet" | "breakdown";
  from: string;
  to: string;
  clocks: string[];
  note?: string;
  whenDirectProduce?: { label?: string; from?: string; to?: string; clocks?: string[]; note?: string };
};

export type RunSpec = {
  rateEps: number;
  totalEvents: number;
  ramp: { enabled: boolean; fromEps: number; overSec: number };
  probeEvery: number;
  send: { transport: "api" | "kafka"; batchSize: number; maxInFlight: number };
  targetIds: string[];
  probeTargetId: string | null;
  walletProbeTargetId: string | null;
  stages: Record<StageKey, boolean>;
  guards: { maxErrorRatePct: number };
  spread: { groupKeyValues: number; includeDefaultBucket: boolean; maxVariantsPerTarget: number };
};

export type PreflightCheck = { name: string; ok: boolean; detail: string; gates: string[] };

export type Snapshot = {
  id?: string;
  prefix?: string;
  phase: "idle" | "preflight" | "sending" | "draining" | "done" | "stopped" | "failed";
  spec?: RunSpec;
  startedAt?: number;
  endedAt?: number;
  elapsedMs?: number;
  counters?: {
    sent: number;
    accepted: number;
    failed: number;
    probes: number;
    usageProbes: number;
    usageTimeouts: number;
    walletProbes: number;
    walletTimeouts: number;
    pendingProbes: number;
  };
  stageCounts?: Partial<Record<StageKey, number>>;
  stats?: Record<string, Percentiles | undefined>;
  histograms?: Record<string, { edges: number[]; counts: number[] } | undefined>;
  rate?: { t: number; sent: number; failed: number }[];
  clocks?: { lago: number | null; risingwave: number | null; clickhouse: number | null; measuredAt: number };
  preflight?: PreflightCheck[];
  unavailable?: string[];
  errors?: { msg: string; count: number }[];
  logs?: { t: number; level: "info" | "warn" | "error"; msg: string }[];
  usageMode?: "exact" | "watermark" | "off";
  usageFreshness?: {
    staleAtStart: boolean;
    worstBatch: number;
    batches: number;
    batchShare: number;
    stalePolls: number;
    verdict: "unknown" | "incremental" | "coarse" | "batched";
  };
  usagePoll?: {
    issued: number;
    completed: number;
    failed: number;
    inFlight: number;
    perSecond: number;
    rttP50: number | null;
    rttP95: number | null;
    resolutionMs: number | null;
    bracketP95Ms?: number | null;
  };
  probeTarget?: {
    subscription: string;
    metric: string;
    baseline: number;
    expected: number;
    attributed?: number;
  } | null;
  walletMode?: "exact" | "watermark" | "refresh" | "off";
  walletFreshness?: {
    staleAtStart: boolean;
    worstBatch: number;
    batches: number;
    batchShare: number;
    stalePolls: number;
    verdict: "unknown" | "incremental" | "coarse" | "batched";
  };
  walletPoll?: {
    issued: number;
    completed: number;
    failed: number;
    inFlight: number;
    perSecond: number;
    rttP50: number | null;
    rttP95: number | null;
    resolutionMs: number | null;
    bracketP95Ms?: number | null;
  };
  walletProbe?: {
    customer: string;
    subscription: string;
    metric: string;
    wallets: number;
    baselineCents: number;
    aligned: boolean;
    centsFactor: number;
    perEventCents: number | null;
    canary: string;
    refreshes: number;
    eventsPerRefresh: number | null;
    refreshesExact: boolean;
    expected: number;
    attributed: number;
  } | null;
  targets?: { id: string; subscription: string; metric: string; aggregation: string; filters: number; groupKeys: string[] }[];
  spread?: {
    target: string;
    label: string;
    kind: "filter" | "default";
    grouped: boolean;
    properties: Record<string, string>;
    sent: number;
  }[];
  spreadTruncated?: number;
};

export type Target = {
  id: string;
  subscriptionExternalId: string;
  customerExternalId: string;
  subscriptionName: string | null;
  planCode: string;
  metricCode: string;
  aggregationType: string;
  fieldName: string | null;
  chargeModel: string;
  filters: { id: string; label: string | null; values: Record<string, string[]>; groupKeys: string[]; amount: number | null }[];
  amount: number | null;
  groupKeys: string[];
  servedByRealtimeBuckets: boolean;
  wallets: WalletInfo[];
};

export type WalletInfo = {
  customerExternalId: string;
  code: string | null;
  name: string | null;
  currency: string;
  balanceCents: number;
  ongoingUsageCents: number;
  metricCodes: string[];
  feeTypes: string[];
  exposesSyncStamp: boolean;
};

export type Discovery = {
  targets: Target[];
  subscriptions: {
    subscriptionExternalId: string;
    customerExternalId: string;
    name: string | null;
    planCode: string;
    status: string;
    metricCount: number;
  }[];
  wallets: WalletInfo[];
  warnings: string[];
  scannedAt: number;
};

export type Health = {
  lago: { ok: boolean; error?: string; metrics?: number };
  risingwave: { ok: boolean; version?: string; error?: string };
  clickhouse: { ok: boolean; version?: string; error?: string };
  redpanda: {
    ok: boolean;
    error?: string;
    brokers?: string;
    clusterId?: string;
    topic?: string;
    partitions?: number;
    topicExists?: boolean;
  };
  checkedAt: number;
};

export type ConfigView = {
  lago: { apiUrl: string; apiKey: string; apiKeySet: boolean };
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
    passwordSet?: boolean;
  };
  kafka: {
    brokers: string;
    topic: string;
    clientId: string;
    acks: number;
    compression: "none" | "gzip";
    ssl: boolean;
    sasl: {
      mechanism: "" | "plain" | "scram-sha-256" | "scram-sha-512";
      username: string;
      password: string;
      passwordSet?: boolean;
    };
    organizationId: string;
    source: string;
  };
  http: { connections: number; h2: boolean };
  measurement: {
    pollTickMs: number;
    sweepMs: number;
    probeTimeoutMs: number;
    usagePollMs: number;
    usagePollConcurrency: number;
    walletPollMs: number;
    walletPollConcurrency: number;
  };
};

export type StoreInfo = {
  dbPath: string;
  savedAt: number | null;
  importedFrom: string | null;
  configured: boolean;
};

async function json<T>(url: string, init?: RequestInit): Promise<T> {
  // Only declare a JSON body when one is actually being sent: a POST with
  // Content-Type: application/json and no body is a 400 by spec.
  const res = await fetch(url, {
    ...init,
    headers: {
      ...(init?.body != null ? { "Content-Type": "application/json" } : {}),
      ...(init?.headers ?? {}),
    },
  });
  const text = await res.text();
  const body = text ? JSON.parse(text) : {};
  if (!res.ok) throw Object.assign(new Error(body.error ?? `HTTP ${res.status}`), { status: res.status, body });
  return body as T;
}

export const api = {
  segments: () => json<{ segments: Segment[]; defaultSpec: RunSpec }>("/api/segments"),
  getConfig: () => json<{ config: ConfigView; store: StoreInfo }>("/api/config"),
  putConfig: (patch: unknown) =>
    json<{ config: ConfigView; store: StoreInfo }>("/api/config", { method: "PUT", body: JSON.stringify(patch) }),
  health: () => json<Health>("/api/health"),
  discover: () => json<Discovery>("/api/discover", { method: "POST" }),
  lastDiscovery: () => json<Discovery>("/api/discover"),
  startRun: (spec: Partial<RunSpec>) => json<{ runId: string; run: Snapshot }>("/api/runs", { method: "POST", body: JSON.stringify(spec) }),
  stopRun: () => json<{ stopping: boolean }>("/api/runs/current/stop", { method: "POST" }),
  runs: () => json<{ runs: { id: string; phase: string; startedAt: number; endedAt: number; sent: number; rateEps: number; stats: Record<string, Percentiles | undefined> }[] }>("/api/runs"),
  run: (id: string) => json<Snapshot>(`/api/runs/${id}`),
};

/** Live snapshots over SSE, with automatic reconnect. */
export function useLiveSnapshot(): { snap: Snapshot | null; connected: boolean } {
  const [snap, setSnap] = useState<Snapshot | null>(null);
  const [connected, setConnected] = useState(false);
  const esRef = useRef<EventSource | null>(null);

  useEffect(() => {
    let stopped = false;
    const open = () => {
      if (stopped) return;
      const es = new EventSource("/api/stream");
      esRef.current = es;
      es.onopen = () => setConnected(true);
      es.onmessage = (e) => {
        try {
          setSnap(JSON.parse(e.data) as Snapshot);
        } catch {
          /* ignore a partial frame */
        }
      };
      es.onerror = () => {
        setConnected(false);
        es.close();
        setTimeout(open, 1500);
      };
    };
    open();
    return () => {
      stopped = true;
      esRef.current?.close();
    };
  }, []);

  return { snap, connected };
}

// ------------------------------------------------------------------ formatting

export function ms(v: number | undefined | null, digits = 0): string {
  if (v == null || !Number.isFinite(v)) return "—";
  if (Math.abs(v) >= 10_000) return `${(v / 1000).toFixed(1)}s`;
  if (Math.abs(v) < 1) return `${v.toFixed(2)}ms`;
  return `${v.toFixed(digits)}ms`;
}

export function num(v: number | undefined | null): string {
  if (v == null || !Number.isFinite(v)) return "—";
  return v.toLocaleString();
}

export function pct(part: number, whole: number): string {
  if (!whole) return "—";
  return `${((part / whole) * 100).toFixed(1)}%`;
}

export function duration(msValue: number | undefined): string {
  if (!msValue || msValue < 0) return "—";
  const s = Math.round(msValue / 1000);
  if (s < 60) return `${s}s`;
  return `${Math.floor(s / 60)}m ${String(s % 60).padStart(2, "0")}s`;
}
