#!/usr/bin/env node
// Raw event producer for the stage-0 throughput gate.
//
// Deliberately NOT the loadtest app in extra/risingwave/loadtest: that one
// measures END-TO-END latency through RisingWave, ClickHouse, usage and
// wallets, and is wired to the staging cluster through its SQLite setup. What
// the Flink/RisingWave A/B needs first is much smaller and must be identical
// for both engines — a pacer that puts realistic events on a local topic as
// fast as asked and reports what it actually achieved.
//
// Messages are produced UNKEYED so kafkajs' DefaultPartitioner round-robins
// them over every partition (the RisingWave load tests learned this the hard
// way: a keyed produce reached only 2 of 3 partitions and looked like a
// pipeline ceiling). Nothing downstream of stage 0 is partition-affine — the
// dedup shuffles by its own key.
//
//   node bench-produce.mjs --brokers redpanda:9092 --topic events-raw-bench \
//        --shapes /tmp/shapes.json --rate 20000 --duration 60 [--ramp 10]
import { readFileSync } from 'node:fs';
import { Kafka, Partitioners, CompressionTypes } from 'kafkajs';

const argv = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = argv.indexOf(`--${name}`);
  if (i >= 0 && i + 1 < argv.length) return argv[i + 1];
  if (fallback === undefined) throw new Error(`missing --${name}`);
  return fallback;
};

const brokers = arg('brokers', 'redpanda:9092').split(',');
const topic = arg('topic', 'events-raw-bench');
const shapes = JSON.parse(readFileSync(arg('shapes'), 'utf8'));
const rate = Number(arg('rate', '10000'));           // target events/second
const duration = Number(arg('duration', '60'));      // seconds at full rate
const ramp = Number(arg('ramp', '0'));               // seconds ramping up to it
const batchSize = Number(arg('batch', '2000'));      // events per produce call
const inflight = Number(arg('inflight', '8'));       // concurrent produce calls
const source = arg('source', 'bench');

if (!Array.isArray(shapes) || shapes.length === 0) throw new Error('shapes file is empty');

const kafka = new Kafka({
  clientId: 'lago-bench-producer',
  brokers,
  retry: { retries: 3 },
  logLevel: 1,
});
const producer = kafka.producer({
  createPartitioner: Partitioners.DefaultPartitioner,
  allowAutoTopicCreation: false,
  // acks=1 in send(); the broker's own durability is not what is being measured.
  maxInFlightRequests: null,
  idempotent: false,
});

let seq = 0;
const build = (nowMs) => {
  const s = shapes[seq % shapes.length];
  const n = seq++;
  const ts = (nowMs / 1000).toFixed(3);
  const props = { ...(s.properties ?? {}) };
  return {
    value: JSON.stringify({
      organization_id: s.organization_id,
      external_subscription_id: s.external_subscription_id,
      // Unique per event: the dedup key is (org, code, ext_sub, ts, txn), so a
      // repeated transaction_id would collapse the run into a handful of rows
      // and measure the dedup's hit path instead of its insert path.
      transaction_id: `bench-${process.pid}-${n}`,
      code: s.code,
      properties: props,
      precise_total_amount_cents: '0',
      source,
      timestamp: ts,
      source_metadata: { api_post_processed: false },
      ingested_at: new Date(nowMs).toISOString().slice(0, 19),
    }),
  };
};

let sent = 0;
let failed = 0;
let lastReport = Date.now();
let lastSent = 0;

const sendBatch = async (count) => {
  const now = Date.now();
  const messages = new Array(count);
  for (let i = 0; i < count; i++) messages[i] = build(now);
  try {
    await producer.send({ topic, messages, acks: 1, compression: CompressionTypes.None });
    sent += count;
  } catch (e) {
    failed += count;
    if (failed <= count) console.error('produce error:', e.message);
  }
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const run = async () => {
  await producer.connect();
  const t0 = Date.now();
  const totalSeconds = ramp + duration;
  console.log(`==> ${topic} @ ${brokers.join(',')} | target ${rate}/s, ramp ${ramp}s, hold ${duration}s, ${shapes.length} shapes`);

  let budget = 0;          // events owed at the current instant
  let lastTick = t0;
  const pending = new Set();

  while (true) {
    const now = Date.now();
    const elapsed = (now - t0) / 1000;
    if (elapsed >= totalSeconds) break;
    const currentRate = ramp > 0 && elapsed < ramp ? rate * (elapsed / ramp) : rate;
    budget += currentRate * ((now - lastTick) / 1000);
    lastTick = now;

    while (budget >= batchSize && pending.size < inflight) {
      budget -= batchSize;
      const p = sendBatch(batchSize).finally(() => pending.delete(p));
      pending.add(p);
    }
    // Never let the debt grow unboundedly: if the broker cannot keep up, the
    // achieved rate is the answer, not a queue to catch up on later.
    if (budget > rate) budget = rate;

    if (now - lastReport >= 1000) {
      const achieved = Math.round(((sent - lastSent) * 1000) / (now - lastReport));
      console.log(`t=${elapsed.toFixed(0)}s target=${Math.round(currentRate)}/s achieved=${achieved}/s sent=${sent} failed=${failed} inflight=${pending.size}`);
      lastReport = now;
      lastSent = sent;
    }
    if (pending.size >= inflight || budget < batchSize) await sleep(2);
  }

  await Promise.allSettled([...pending]);
  await producer.disconnect();
  const wall = (Date.now() - t0) / 1000;
  console.log(`==> done: ${sent} sent, ${failed} failed, ${wall.toFixed(1)}s wall, ${Math.round(sent / wall)}/s average`);
};

run().catch((e) => { console.error(e); process.exit(1); });
