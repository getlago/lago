import { test } from "node:test";
import assert from "node:assert/strict";
import { buildRawEvent, rawEventJson, type RawEventEnvelope } from "../clients/redpanda.js";
import type { EventPayload } from "../clients/lago.js";

const ENV: RawEventEnvelope = {
  organizationId: "1a2b3c4d-0000-4000-8000-000000000001",
  source: "http_ruby",
  apiPostProcessed: true,
};

const AT = Date.UTC(2026, 8, 2, 12, 34, 56, 789);

/**
 * The whole point of the shape fast path is that it changes the COST of building
 * a message and nothing else. A message that is not byte-identical to what
 * `Events::KafkaProducerService` writes measures a different pipeline, so this
 * pins the two paths together rather than trusting the template.
 */
function sameBytes(p: EventPayload, env = ENV) {
  assert.equal(rawEventJson(p, env, AT), JSON.stringify(buildRawEvent(p, env, AT)));
}

test("the fast path is byte-identical to the general path", () => {
  sameBytes({
    transaction_id: "lt-20260902120000-ab12-b7",
    external_subscription_id: "sub_load_1",
    code: "api_calls",
    timestamp: 1_756_819_200.123,
    properties: { region: "eu-west-1", size: 42 },
  });
});

test("an empty properties object still matches", () => {
  sameBytes({
    transaction_id: "lt-x-b0",
    external_subscription_id: "sub_load_1",
    code: "api_calls",
    timestamp: 1_756_819_200,
    properties: {},
  });
});

test("values needing JSON escaping match", () => {
  sameBytes({
    transaction_id: 'lt-"quote"-\\back\nnewline',
    external_subscription_id: 'sub "odd"',
    code: "métrique_ünicode",
    timestamp: 1_756_819_200.5,
    properties: { note: 'a "quoted" \\ value', "key\twith tab": "ok" },
  });
});

test("an event carrying its own amount takes the general path and still matches", () => {
  sameBytes({
    transaction_id: "lt-x-b1",
    external_subscription_id: "sub_load_1",
    code: "api_calls",
    timestamp: 1_756_819_200,
    properties: { region: "eu" },
    precise_total_amount_cents: "12.5",
  });
});

test("an event with no properties at all takes the general path and still matches", () => {
  sameBytes({
    transaction_id: "lt-x-b2",
    external_subscription_id: "sub_load_1",
    code: "api_calls",
    timestamp: 1_756_819_200,
  });
});

test("a properties object reused across subscriptions is not served the wrong shape", () => {
  // The cache is keyed on the identity of `properties`, which a run builds once
  // per shape — but nothing guarantees that, so a shared object must still
  // serialise the event it was actually given.
  const shared = { region: "eu-west-1" };
  const a: EventPayload = {
    transaction_id: "lt-x-b3",
    external_subscription_id: "sub_a",
    code: "api_calls",
    timestamp: 1_756_819_200,
    properties: shared,
  };
  const b: EventPayload = { ...a, transaction_id: "lt-x-b4", external_subscription_id: "sub_b", code: "storage" };
  sameBytes(a);
  sameBytes(b);
  sameBytes(a);
});

test("changing the envelope invalidates a cached shape", () => {
  const props = { region: "us-east-1" };
  const p: EventPayload = {
    transaction_id: "lt-x-b5",
    external_subscription_id: "sub_a",
    code: "api_calls",
    timestamp: 1_756_819_200,
    properties: props,
  };
  sameBytes(p);
  sameBytes(p, { ...ENV, organizationId: "other-org", apiPostProcessed: false });
  sameBytes(p);
});

test("the ingested_at memo does not serve a stale stamp", () => {
  const p: EventPayload = {
    transaction_id: "lt-x-b6",
    external_subscription_id: "sub_a",
    code: "api_calls",
    timestamp: 1_756_819_200,
    properties: { a: 1 },
  };
  assert.equal(rawEventJson(p, ENV, AT), JSON.stringify(buildRawEvent(p, ENV, AT)));
  assert.equal(rawEventJson(p, ENV, AT + 1), JSON.stringify(buildRawEvent(p, ENV, AT + 1)));
  assert.equal(rawEventJson(p, ENV, AT), JSON.stringify(buildRawEvent(p, ENV, AT)));
});
