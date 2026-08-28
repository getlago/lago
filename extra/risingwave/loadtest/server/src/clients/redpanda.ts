import { Kafka, Partitioners, CompressionTypes, logLevel, type Producer, type SASLOptions } from "kafkajs";
import { getConfig } from "../config.js";
import type { EventPayload, SendResult } from "./lago.js";

/**
 * Direct produce to Redpanda — the same topic, the same message, without the
 * Lago API in the way.
 *
 * The API path is what a customer's integration exercises, but as a load
 * generator it caps out on Lago's own ingest cost (rate = in-flight / round
 * trip, and a POST is ~150ms against a remote API). Producing straight to the
 * broker removes that ceiling entirely: one produce request carries thousands
 * of events, so the throughput the pipeline is measured at stops being a
 * property of the sender.
 *
 * The message MUST be byte-shape identical to what `Events::KafkaProducerService`
 * writes, or the pipeline being measured is not the pipeline that runs in
 * production:
 *
 *  * `timestamp` is a JSON **string** of float seconds — RisingWave declares the
 *    column VARCHAR and casts downstream; a JSON number changes the parse path.
 *  * `ingested_at` is ISO-8601 with milliseconds and **no trailing Z** (Ruby's
 *    `iso8601(3)[...-1]`), which is what ClickHouse and the Go processor parse.
 *  * `precise_total_amount_cents` defaults to the string `"0.0"`, never null.
 *  * `source` is `http_ruby`, which both consumers read as "the Ruby API already
 *    evaluated custom expressions" — sending anything else makes the Go
 *    processor re-evaluate them and measures a different code path.
 *  * `source_metadata.api_post_processed` is `!clickhouse_events_store?`, read
 *    from the organization rather than guessed.
 *  * the key is `<organization_id>-<external_subscription_id>` when
 *    `kafka.partitionKey` is `subscription`, so per-subscription ordering is
 *    preserved exactly as the API produces it. The default is `none`: a run's
 *    key set is only as wide as its target list, and 2 targets pin all traffic
 *    to at most 2 partitions — which silently caps RisingWave's source
 *    parallelism to the same 2 readers. Unkeyed messages round-robin over every
 *    partition, and nothing downstream is partition-affine.
 *
 * What is NOT reproduced, because the API does it and Kafka cannot: the Postgres
 * `events` row and `Events::PostProcessJob` for an organization whose events
 * store is Postgres. Preflight says so rather than letting a dead read path look
 * like latency.
 */

/** Everything about the producer that is the same for every event of a run. */
export type RawEventEnvelope = {
  organizationId: string;
  /** `http_ruby`: expressions already evaluated. */
  source: string;
  /** `!organization.clickhouse_events_store?`, as the API stamps it. */
  apiPostProcessed: boolean;
};

/** Ruby's `Time#iso8601(3)` with the trailing Z removed, as the API stamps it. */
export const ingestedAtStamp = (ms: number): string => new Date(ms).toISOString().slice(0, -1);

export function buildRawEvent(p: EventPayload, env: RawEventEnvelope, ingestedAtMs: number) {
  return {
    organization_id: env.organizationId,
    // The v1 events endpoint takes no customer id, so the API produces null
    // here and both consumers resolve the customer from the subscription.
    external_customer_id: null,
    external_subscription_id: p.external_subscription_id,
    transaction_id: p.transaction_id,
    // A STRING, deliberately — see the note above.
    timestamp: String(p.timestamp),
    code: p.code,
    precise_total_amount_cents: p.precise_total_amount_cents ?? "0.0",
    properties: p.properties ?? {},
    ingested_at: ingestedAtStamp(ingestedAtMs),
    source: env.source,
    source_metadata: { api_post_processed: env.apiPostProcessed },
  };
}

const brokerList = (brokers: string): string[] =>
  brokers
    .split(",")
    .map((b) => b.trim())
    .filter(Boolean);

function saslOf(): SASLOptions | undefined {
  const { sasl } = getConfig().kafka;
  if (!sasl.mechanism || !sasl.username) return undefined;
  return { mechanism: sasl.mechanism, username: sasl.username, password: sasl.password } as SASLOptions;
}

/** Identity of the connection, so a Setup change rebuilds it instead of being ignored. */
function connectionKey(): string {
  const k = getConfig().kafka;
  return JSON.stringify([k.brokers, k.clientId, k.ssl, k.sasl.mechanism, k.sasl.username, k.sasl.password]);
}

function kafka(opts?: { fastFail?: boolean }): Kafka {
  const k = getConfig().kafka;
  return new Kafka({
    clientId: k.clientId || "lago-rw-loadtest",
    brokers: brokerList(k.brokers),
    ssl: k.ssl,
    sasl: saslOf(),
    logLevel: logLevel.NOTHING,
    connectionTimeout: 5_000,
    requestTimeout: 30_000,
    // A health check must answer, not spend 30s in exponential backoff.
    retry: opts?.fastFail ? { retries: 0, initialRetryTime: 100 } : { retries: 5, initialRetryTime: 100 },
  });
}

let producer: Producer | null = null;
let producerKey = "";
/** Shared so a burst of concurrent sends performs ONE connect, not hundreds. */
let connecting: Promise<Producer> | null = null;

async function ensureProducer(): Promise<Producer> {
  const key = connectionKey();
  if (producer && producerKey === key) return producer;
  if (connecting && producerKey === key) return connecting;
  const previous = producer;
  producer = null;
  producerKey = key;
  connecting = (async () => {
    const p = kafka().producer({
      // A typo in the topic name must fail loudly, not silently create a topic
      // that no consumer of the pipeline is subscribed to.
      allowAutoTopicCreation: false,
      // Java-compatible murmur2 hashing. The Ruby side goes through rdkafka,
      // whose default partitioner differs, so the same key can land on a
      // different partition — irrelevant here (per-key ordering still holds and
      // nothing downstream is partition-affine) but worth not pretending
      // otherwise.
      createPartitioner: Partitioners.DefaultPartitioner,
      idempotent: false,
    });
    await p.connect();
    producer = p;
    connecting = null;
    return p;
  })();
  void previous?.disconnect().catch(() => {});
  return connecting;
}

export async function disconnectProducer(): Promise<void> {
  const p = producer;
  producer = null;
  producerKey = "";
  connecting = null;
  await p?.disconnect().catch(() => {});
}

const compressionOf = (): CompressionTypes =>
  getConfig().kafka.compression === "gzip" ? CompressionTypes.GZIP : CompressionTypes.None;

/**
 * One produce request carrying one or many events.
 *
 * The returned shape is the API sender's, so the runner records a produce
 * exactly as it records a POST: `sentAt` is the instant the batch was handed
 * over and `apiMs` is the time to the broker's ack — which with `acks: 0` is
 * only the local write, and is labelled as such in the UI.
 */
export async function produceEvents(payloads: EventPayload[], env: RawEventEnvelope): Promise<SendResult> {
  const { topic, acks } = getConfig().kafka;
  const sentAt = Date.now();
  const t0 = performance.now();
  try {
    const p = await ensureProducer();
    // A null key makes kafkajs' DefaultPartitioner round-robin instead of
    // hashing, which is the whole point: the hashed form can only ever reach as
    // many partitions as the run has distinct subscriptions.
    const keyed = getConfig().kafka.partitionKey === "subscription";
    const messages = payloads.map((payload) => ({
      key: keyed ? `${env.organizationId}-${payload.external_subscription_id}` : null,
      value: JSON.stringify(buildRawEvent(payload, env, Date.now())),
    }));
    await p.send({ topic, acks, compression: compressionOf(), messages });
    return { ok: true, status: 0, sentAt, apiMs: performance.now() - t0 };
  } catch (e) {
    return {
      ok: false,
      status: 0,
      sentAt,
      apiMs: performance.now() - t0,
      error: describeKafkaError(e),
    };
  }
}

/** kafkajs errors carry the useful part in `type`/`cause`, not always in the message. */
export function describeKafkaError(e: unknown): string {
  const err = e as { message?: string; type?: string; cause?: { message?: string }; broker?: string };
  const parts = [err?.type, err?.message ?? String(e), err?.cause?.message].filter(Boolean);
  // The broker caps a produce request by BYTES, not by message count, so this
  // one depends on how fat `properties` is and is worth naming its own fix.
  if (err?.type === "MESSAGE_TOO_LARGE")
    parts.push(
      "the produce request exceeded the broker's max.message.bytes (1MB by default) — lower `events per produce` on the Run tab",
    );
  if (err?.type === "UNKNOWN_TOPIC_OR_PARTITION")
    parts.push("auto-creation is deliberately off: check the topic name in Setup against LAGO_KAFKA_RAW_EVENTS_TOPIC");
  return [...new Set(parts)].join(" — ").slice(0, 300);
}

export type RedpandaHealth = {
  ok: boolean;
  error?: string;
  /** "host:port, host:port" as the cluster advertises itself, which is what a
   * client actually connects to — a mismatch with the configured broker is the
   * usual reason a produce hangs from outside Docker. */
  brokers?: string;
  clusterId?: string;
  topic?: string;
  partitions?: number;
  topicExists?: boolean;
};

export async function redpandaHealth(): Promise<RedpandaHealth> {
  const { brokers, topic } = getConfig().kafka;
  if (brokerList(brokers).length === 0) return { ok: false, error: "no broker configured" };
  const admin = kafka({ fastFail: true }).admin();
  try {
    await admin.connect();
    const cluster = await admin.describeCluster();
    const advertised = cluster.brokers.map((b) => `${b.host}:${b.port}`).join(", ");
    let partitions: number | undefined;
    let topicExists = false;
    try {
      const meta = await admin.fetchTopicMetadata({ topics: [topic] });
      partitions = meta.topics[0]?.partitions.length;
      topicExists = Boolean(meta.topics[0]);
    } catch (e) {
      return {
        ok: false,
        brokers: advertised,
        clusterId: cluster.clusterId,
        topic,
        topicExists: false,
        error: `topic "${topic}" is not readable: ${describeKafkaError(e)}`,
      };
    }
    return { ok: true, brokers: advertised, clusterId: cluster.clusterId, topic, partitions, topicExists };
  } catch (e) {
    return { ok: false, error: describeKafkaError(e) };
  } finally {
    await admin.disconnect().catch(() => {});
  }
}
