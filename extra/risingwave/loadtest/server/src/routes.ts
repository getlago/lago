import { readdirSync, readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import type { FastifyInstance } from "fastify";
import { getConfig, isConfigured, redact, saveConfig, storeInfo, RUNS_DIR, type Config } from "./config.js";
import { discover, type DiscoveryResult, type Target } from "./discovery.js";
import { lagoHealth, MAX_EVENT_BATCH } from "./clients/lago.js";
import { MAX_KAFKA_BATCH } from "./clients/events.js";
import { redpandaHealth } from "./clients/redpanda.js";
import { rwHealth } from "./clients/risingwave.js";
import { chHealth } from "./clients/clickhouse.js";
import { Run } from "./run/runner.js";
import { SEGMENTS, type RunSpec, type StageKey } from "./types.js";
import { DEFAULT_SPREAD } from "./variants.js";

let currentRun: Run | null = null;
let lastDiscovery: DiscoveryResult | null = null;

const ALL_STAGES: StageKey[] = ["rwEnriched", "rwExpanded", "chRwEnriched", "chRwExpanded", "chGoEnriched", "chGoExpanded"];

function defaultSpec(): RunSpec {
  return {
    rateEps: 50,
    totalEvents: 1000,
    ramp: { enabled: false, fromEps: 10, overSec: 30 },
    probeEvery: 20,
    send: { transport: "api", batchSize: 1, maxInFlight: 0 },
    targetIds: [],
    probeTargetId: null,
    walletProbeTargetId: null,
    stages: Object.fromEntries(ALL_STAGES.map((s) => [s, true])) as Record<StageKey, boolean>,
    guards: { maxErrorRatePct: 5, hardCap: 100_000 },
    spread: { ...DEFAULT_SPREAD },
  };
}

export async function registerRoutes(app: FastifyInstance) {
  app.get("/api/segments", async () => ({ segments: SEGMENTS, defaultSpec: defaultSpec() }));

  app.get("/api/config", async () => ({ config: redact(getConfig()), store: storeInfo() }));

  app.put<{ Body: Partial<Config> }>("/api/config", async (req, reply) => {
    // Connection details are read per query, so changing them mid-run would
    // silently repoint the measurement half way through.
    if (currentRun && ["preflight", "sending", "draining"].includes(currentRun.phase)) {
      return reply.code(409).send({ error: "a run is in progress" });
    }
    return { config: redact(saveConfig(req.body ?? {})), store: storeInfo() };
  });

  app.get("/api/health", async () => {
    const [lago, rw, ch, rp] = await Promise.all([lagoHealth(), rwHealth(), chHealth(), redpandaHealth()]);
    return { lago, risingwave: rw, clickhouse: ch, redpanda: rp, checkedAt: Date.now() };
  });

  app.post("/api/discover", async (_req, reply) => {
    try {
      lastDiscovery = await discover();
      return lastDiscovery;
    } catch (e) {
      // Upstream is unreachable or refusing us: that is not a server fault, and
      // the UI needs the reason, not "Internal Server Error".
      return reply.code(502).send({ error: (e as Error).message });
    }
  });

  app.get(
    "/api/discover",
    async () => lastDiscovery ?? { targets: [], subscriptions: [], wallets: [], warnings: [], scannedAt: 0 },
  );

  app.post<{ Body: Partial<RunSpec> }>("/api/runs", async (req, reply) => {
    if (!isConfigured())
      return reply.code(400).send({ error: "not configured yet — fill in the connections on the Setup screen" });
    if (currentRun && ["preflight", "sending", "draining"].includes(currentRun.phase)) {
      return reply.code(409).send({ error: "a run is already in progress", runId: currentRun.id });
    }
    if (!lastDiscovery) return reply.code(400).send({ error: "run discovery first" });

    const spec: RunSpec = {
      ...defaultSpec(),
      ...req.body,
      stages: { ...defaultSpec().stages, ...req.body?.stages },
      spread: { ...DEFAULT_SPREAD, ...req.body?.spread },
      send: { ...defaultSpec().send, ...req.body?.send },
    };
    spec.send.transport = spec.send.transport === "kafka" ? "kafka" : "api";
    // The API refuses a batch over 100; a produce request has no such limit, so
    // the two transports cannot share one clamp.
    const maxBatch = spec.send.transport === "kafka" ? MAX_KAFKA_BATCH : MAX_EVENT_BATCH;
    spec.send.batchSize = Math.max(1, Math.min(maxBatch, Math.floor(spec.send.batchSize) || 1));
    if (spec.send.transport === "kafka" && !getConfig().kafka.brokers.trim())
      return reply
        .code(400)
        .send({ error: "direct produce needs a Redpanda broker — set it on the Setup screen (Direct produce)" });
    spec.send.maxInFlight = Math.max(0, Math.min(4096, Math.floor(spec.send.maxInFlight) || 0));
    const byId = new Map(lastDiscovery.targets.map((t) => [t.id, t]));
    const targets = spec.targetIds.map((id) => byId.get(id)).filter((t): t is Target => Boolean(t));
    if (targets.length === 0) return reply.code(400).send({ error: "no valid target selected" });
    const probeTarget = spec.probeTargetId ? byId.get(spec.probeTargetId) ?? null : null;
    if (spec.probeTargetId && !probeTarget) return reply.code(400).send({ error: "probe target not found" });
    const walletTarget = spec.walletProbeTargetId ? byId.get(spec.walletProbeTargetId) ?? null : null;
    if (spec.walletProbeTargetId && !walletTarget)
      return reply.code(400).send({ error: "wallet probe target not found" });

    const run = new Run(spec, targets, probeTarget, walletTarget);
    currentRun = run;
    const ok = await run.runPreflight();
    if (!ok) return reply.code(422).send({ error: "preflight failed", run: run.snapshot() });
    void run.start().catch((e) => {
      run.phase = "failed";
      app.log.error(e);
    });
    return { runId: run.id, run: run.snapshot() };
  });

  app.get("/api/runs/current", async (_req, reply) => {
    if (!currentRun) return reply.code(404).send({ error: "no run yet" });
    return currentRun.snapshot();
  });

  app.post("/api/runs/current/stop", async (_req, reply) => {
    if (!currentRun) return reply.code(404).send({ error: "no run yet" });
    currentRun.stop();
    return { stopping: true, runId: currentRun.id };
  });

  app.get("/api/runs", async () => {
    if (!existsSync(RUNS_DIR)) return { runs: [] };
    const runs = readdirSync(RUNS_DIR, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => {
        const f = resolve(RUNS_DIR, d.name, "summary.json");
        if (!existsSync(f)) return null;
        try {
          const s = JSON.parse(readFileSync(f, "utf8"));
          return {
            id: s.id,
            phase: s.phase,
            startedAt: s.startedAt,
            endedAt: s.endedAt,
            sent: s.counters?.sent ?? 0,
            rateEps: s.spec?.rateEps,
            stats: s.stats,
          };
        } catch {
          return null;
        }
      })
      .filter(Boolean)
      .sort((a: any, b: any) => b.startedAt - a.startedAt);
    return { runs };
  });

  app.get<{ Params: { id: string } }>("/api/runs/:id", async (req, reply) => {
    const f = resolve(RUNS_DIR, req.params.id, "summary.json");
    if (!existsSync(f)) return reply.code(404).send({ error: "unknown run" });
    return JSON.parse(readFileSync(f, "utf8"));
  });

  /** Live snapshots. One payload shape for live and historical, so the UI has one renderer. */
  app.get("/api/stream", (req, reply) => {
    reply.raw.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    });
    const send = () => {
      const payload = currentRun ? currentRun.snapshot() : { phase: "idle" };
      reply.raw.write(`data: ${JSON.stringify(payload)}\n\n`);
    };
    send();
    const timer = setInterval(send, 500);
    const stop = () => {
      clearInterval(timer);
      reply.raw.end();
    };
    req.raw.on("close", stop);
    req.raw.on("error", stop);
  });
}
