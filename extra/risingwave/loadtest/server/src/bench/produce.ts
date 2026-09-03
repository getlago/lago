/**
 * What can the SENDER do, with no pipeline in the way?
 *
 * Every load-test result is a claim about the pipeline, and that claim is only
 * worth anything if the generator was not itself the ceiling. This produces the
 * runner's exact message bytes, through the runner's exact producer settings,
 * into a THROWAWAY topic that nothing consumes — so what it measures is this
 * process plus the broker, and nothing else.
 *
 *   npm run bench --workspace server -- [events] [batch] [inFlight] [acks] [broker]
 *
 * Delete the scratch topic when you are done:
 *   rpk topic delete lt-bench-scratch
 */
import { Kafka, Partitioners, CompressionTypes, logLevel } from "kafkajs";
import { envelopeKey, rawEventJson, type RawEventEnvelope } from "../clients/redpanda.js";
import type { EventPayload } from "../clients/lago.js";

const TOPIC = "lt-bench-scratch";
const TOTAL = Number(process.argv[2] ?? 1_000_000);
const BATCH = Number(process.argv[3] ?? 2_000);
const IN_FLIGHT = Number(process.argv[4] ?? 16);
const ACKS = Number(process.argv[5] ?? 1);
const BROKER = process.argv[6] ?? "localhost:19092";

const env: RawEventEnvelope = {
  organizationId: "00000000-0000-4000-8000-000000000000",
  source: "http_ruby",
  apiPostProcessed: true,
};
const envKey = envelopeKey(env);
// As many distinct event shapes as a run's plan would round-robin over.
const shapes = Array.from({ length: 20 }, (_, i) => ({ region: `eu-west-${i}`, size: i * 7, tier: "gold" }));

const kafka = new Kafka({
  clientId: "lago-rw-loadtest-bench",
  brokers: [BROKER],
  logLevel: logLevel.NOTHING,
  retry: { retries: 2 },
});

const admin = kafka.admin();
await admin.connect();
await admin.createTopics({ topics: [{ topic: TOPIC, numPartitions: 12 }], waitForLeaders: true }).catch(() => {});
await admin.disconnect();

const producer = kafka.producer({
  allowAutoTopicCreation: false,
  createPartitioner: Partitioners.DefaultPartitioner,
  idempotent: false,
});
await producer.connect();

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
let seq = 0;
let inFlight = 0;
let done = 0;
let failed = 0;
let peakHeap = 0;
const t0 = Date.now();

while (done < TOTAL) {
  while (seq < TOTAL && inFlight < IN_FLIGHT) {
    const n = Math.min(BATCH, TOTAL - seq);
    const at = Date.now();
    const messages = new Array<{ key: null; value: string }>(n);
    for (let i = 0; i < n; i++) {
      const s = seq + i;
      const payload: EventPayload = {
        transaction_id: `lt-bench-b${s}`,
        external_subscription_id: `sub_${s % 4}`,
        code: "api_calls",
        timestamp: at / 1000,
        properties: shapes[s % shapes.length]!,
      };
      messages[i] = { key: null, value: rawEventJson(payload, env, at, envKey) };
    }
    seq += n;
    inFlight++;
    void producer
      .send({ topic: TOPIC, acks: ACKS, compression: CompressionTypes.None, messages })
      .catch((e: Error) => {
        failed += n;
        if (failed === n) console.error(`produce failed: ${e.message}`);
      })
      .finally(() => {
        done += n;
        inFlight--;
      });
  }
  const used = process.memoryUsage().heapUsed;
  if (used > peakHeap) peakHeap = used;
  await sleep(1);
}
while (inFlight > 0) await sleep(5);
await producer.disconnect();

const secs = (Date.now() - t0) / 1000;
console.log(
  `${TOTAL.toLocaleString()} events in ${secs.toFixed(2)}s = ${Math.round(TOTAL / secs).toLocaleString()} events/s\n` +
    `batch ${BATCH}, ${IN_FLIGHT} produce requests in flight, acks ${ACKS}, broker ${BROKER}\n` +
    `${failed.toLocaleString()} failed, peak heap ${(peakHeap / 1e6).toFixed(0)}MB\n` +
    `topic ${TOPIC} still holds these events — \`rpk topic delete ${TOPIC}\` when you are done`,
);
