# integrations/accounting — outbound accounting contract (exactly-once)

This is the **executable contract** for the future "Lago → accounting" connector,
built gate-first: the exactly-once guarantee is defined and enforced **before** the
real connector exists, so when it's built it has to satisfy these tests.

Run it: `make accounting` (or `./repo-gates/accounting-contract.sh`). It is pure
Go (no CGO), so it builds and tests anywhere — locally and in CI.

## The contract

> **Given usage event X, the *selected* accounting target receives entry Y —
> exactly once.**

Exactly-once is guaranteed by two things together:

1. **An idempotency key on every entry** — the Lago `transaction_id`. Events
   without one are *refused* (`ErrNoIdempotencyKey`) rather than risk a
   double-booking.
2. **An idempotent target** — `AccountingTarget.Post` must book a given key once.
   `Dispatch` may be retried, redelivered, or called concurrently; the target
   still ends with one entry per key. Tests prove this under 64-goroutine races
   and across a transient-failure-then-retry.

## Target selection (defaults to Gridiron)

`SelectTarget(name)` returns the chosen accounting destination. An **empty
selection defaults to the in-house Gridiron module** (`DefaultTarget`); external
ERPs are opt-in. Unknown names error rather than silently misroute revenue.

```go
target, _ := accounting.SelectTarget("")        // -> "gridiron" (default)
d := accounting.NewDispatcher(target, accounting.NewMemoryStore())
res, err := d.Dispatch(ctx, accounting.UsageEvent{TransactionID: "txn_123", /* ... */})
```

## The real connector (NetSuite) — implemented

`netsuite.go` is a working `AccountingTarget` for NetSuite SuiteTalk REST:

- **Idempotent by design** — it upserts by NetSuite `externalId`
  (`PUT …/record/v1/{type}/eid:{transaction_id}`), so the same key books one
  record even if delivered twice.
- **Real auth** — OAuth 1.0a Token-Based-Auth (HMAC-SHA256) built with the stdlib.
- **Honest errors** — non-2xx returns a `*PostError`; 4xx (except 429) is marked
  `Permanent` so a caller can dead-letter instead of retrying forever.
- **Registered** — `SelectTarget("netsuite")` works; it reads `NETSUITE_*` env vars.

It's validated against a simulated SuiteTalk server in `netsuite_test.go` (no live
account needed): target-level idempotency, the OAuth header + upsert path, and
error classification. The JSON body is a minimal template — map it to your
NetSuite record schema; auth/idempotency/transport are production-ready as is.

```bash
export NETSUITE_ACCOUNT_ID=1234567_SB1 NETSUITE_BASE_URL=https://1234567.suitetalk.api.netsuite.com
export NETSUITE_CONSUMER_KEY=… NETSUITE_CONSUMER_SECRET=… NETSUITE_TOKEN_ID=… NETSUITE_TOKEN_SECRET=…
```

## Durable idempotency store (Redis) — implemented

`redis_store.go` is a durable `IdempotencyStore` backed by Redis (`Seen` = EXISTS,
`Record` = SETNX+TTL). It depends only on a tiny `RedisCmdable` interface, so this
module stays dependency-free and the gate runs offline; production passes a real
client. A ~6-line adapter over `github.com/redis/go-redis/v9`:

```go
type goRedis struct{ c *redis.Client }
func (g goRedis) SetNX(ctx context.Context, k string, ttl time.Duration) (bool, error) {
    return g.c.SetNX(ctx, k, "1", ttl).Result()
}
func (g goRedis) Exists(ctx context.Context, k string) (bool, error) {
    n, err := g.c.Exists(ctx, k).Result(); return n > 0, err
}
// then: store := accounting.NewRedisStore(goRedis{client}, "lago:acct:idemp:", 30*24*time.Hour)
//       d := accounting.NewDispatcher(target, store)
```

A Postgres-backed store implements the same two methods (`Seen` via
`SELECT EXISTS`, `Record` via `INSERT … ON CONFLICT DO NOTHING`).

## Add another ERP target later

1. Implement `accounting.AccountingTarget` (keep `Post` idempotent on the key).
2. `accounting.Register("sap", func() AccountingTarget { return NewSAP(cfg) })` in
   its `init()` — it then appears in `AvailableTargets()` for the ERP selector.
3. Keep `make accounting` green; add target-specific cases to its test.

| File | Role |
|---|---|
| `contract.go` | Event/entry types, `AccountingTarget`/`IdempotencyStore` interfaces, the `Dispatcher` |
| `targets.go` | Target registry + selection (default = Gridiron); in-house Gridiron target |
| `netsuite.go` | NetSuite target: OAuth1 TBA + externalId-upsert idempotency |
| `store.go` | Reference in-memory idempotency store |
| `redis_store.go` | Durable Redis-backed idempotency store |
| `*_test.go` | The exactly-once contract tests (the gate) |
