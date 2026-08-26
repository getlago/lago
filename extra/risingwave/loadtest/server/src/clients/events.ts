import { postEvents, type EventPayload, type SendResult } from "./lago.js";
import { produceEvents, type RawEventEnvelope } from "./redpanda.js";

/**
 * The two ways this app can put an event into the pipeline.
 *
 *  api    POST /events (or /events/batch). What a customer's integration does,
 *         so it measures Lago's ingest cost as part of every latency — and caps
 *         the achievable rate at Lago's own round trip.
 *
 *  kafka  produce straight to the raw events topic, byte-shape identical to what
 *         the API would have produced. The API is then out of the send path
 *         entirely, so the send rate stops being the bottleneck and the pipeline
 *         can be pushed to where it actually breaks.
 */
export type Transport = "api" | "kafka";

/**
 * Lago refuses a batch longer than 100. A produce request has no count limit,
 * but the broker caps a batch by SIZE (Redpanda's default max.message.bytes is
 * 1MB), so the real ceiling depends on how fat `properties` is: ~330-byte events
 * fit ~2800 per request. 2000 leaves room for that and is past the point where
 * more batching buys anything — measured locally against the dev broker,
 * 100 000 events took 0.46s at 500/request and 0.63s at 2000.
 */
export const MAX_KAFKA_BATCH = 2_000;

/**
 * One request — HTTP or produce — carrying one or many events.
 *
 * Both transports return the same shape, so everything downstream of the send
 * (recording, attribution, the API-latency histogram) is transport-blind and
 * cannot drift between the two.
 */
export function sendEvents(
  transport: Transport,
  payloads: EventPayload[],
  envelope: RawEventEnvelope | null,
): Promise<SendResult> {
  if (transport === "kafka") {
    if (!envelope) {
      return Promise.resolve({
        ok: false,
        status: 0,
        sentAt: Date.now(),
        apiMs: 0,
        error: "direct produce is not initialised (no organization id resolved)",
      });
    }
    return produceEvents(payloads, envelope);
  }
  return postEvents(payloads);
}
