#!/usr/bin/env python3
"""Rate-controlled load generator for the realtime pipeline.

Emits one JSON event per line to stdout at `rate` events/second for
`duration` seconds, spread across `subs` load-test subscriptions with a
mix of count / charge-filtered / group-keyed metrics. Pipe into:
  docker exec -i lago_redpanda_dev rpk topic produce events-raw

Usage: producer.py <rate> <duration_s> <subs> [run_id]
Progress goes to stderr; a summary JSON is written as the last stderr line.
"""
import json
import random
import sys
import time
import uuid

rate = int(sys.argv[1])
duration = int(sys.argv[2])
subs = int(sys.argv[3])
run_id = sys.argv[4] if len(sys.argv) > 4 else uuid.uuid4().hex[:8]

ORG = "791d70ac-ec99-41ca-b3ce-af19ee5171fa"
TICKS_PER_S = 10
per_tick = rate / TICKS_PER_S

start = time.time()
sent = 0
carry = 0.0
tick = 0

while time.time() - start < duration:
    tick_start = start + tick * (1.0 / TICKS_PER_S)
    carry += per_tick
    n = int(carry)
    carry -= n
    now = time.time()
    ingested = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(now)) + f".{int(now * 1000) % 1000:03d}"
    lines = []
    for _ in range(n):
        i = random.randrange(subs)
        r = random.random()
        if r < 0.3:
            code, props = "rwb_count", {}
        elif r < 0.7:
            code = "rwb_sum_filtered"
            props = {"tier": random.choice(["gold", "silver", "bronze"]), "amount": str(random.randint(1, 10))}
        else:
            code = "rwb_sum_grouped"
            props = {"region": random.choice(["eu", "us", "ap"]), "amount": str(random.randint(1, 10))}
        lines.append(json.dumps({
            "organization_id": ORG,
            "external_subscription_id": f"rwbl_sub_{i}",
            "transaction_id": f"load-{run_id}-{sent}",
            "timestamp": f"{now:.3f}",
            "code": code,
            "precise_total_amount_cents": "0.0",
            "properties": props,
            "ingested_at": ingested,
            "source": "http_ruby",
            "source_metadata": {"api_post_processed": False},
        }, separators=(",", ":")))
        sent += 1
    if lines:
        sys.stdout.write("\n".join(lines) + "\n")
        sys.stdout.flush()
    tick += 1
    sleep_for = (start + tick * (1.0 / TICKS_PER_S)) - time.time()
    if sleep_for > 0:
        time.sleep(sleep_for)
    if tick % (TICKS_PER_S * 15) == 0:
        elapsed = time.time() - start
        print(f"[producer] {sent} events in {elapsed:.0f}s ({sent / elapsed:.0f}/s)", file=sys.stderr)

elapsed = time.time() - start
print(json.dumps({"run_id": run_id, "sent": sent, "elapsed_s": round(elapsed, 1), "avg_rate": round(sent / elapsed, 1)}), file=sys.stderr)
