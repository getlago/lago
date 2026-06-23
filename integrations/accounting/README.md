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

## Target selection (defaults to Bigcapital)

`SelectTarget(name)` returns the chosen accounting destination. An **empty
selection defaults to the in-house Bigcapital module** (`DefaultTarget`);
QuickBooks, Xero and NetSuite are opt-in. Unknown names error rather than silently
misroute revenue, and `AvailableTargets()` feeds the Gridiron ERP selector.

```go
target, _ := accounting.SelectTarget("")        // -> "bigcapital" (default)
// or: SelectTarget("quickbooks") / "xero" / "netsuite"
d := accounting.NewDispatcher(target, accounting.NewMemoryStore())
res, err := d.Dispatch(ctx, accounting.UsageEvent{TransactionID: "txn_123", /* ... */})
```

## The ERP targets — implemented

Four working `AccountingTarget`s, each idempotent via its API's **native**
mechanism, each authenticated, each validated offline against a simulated server
(no live account needed) for idempotency, auth, and error classification:

| Target | Default? | Idempotency mechanism | Auth | Env vars |
|---|---|---|---|---|
| **Bigcapital** (`bigcapital.go`) | ✅ yes | `Idempotency-Key` header + unique `reference`; 409 = already booked | `x-access-token` + `organization-id` | `BIGCAPITAL_*` |
| **QuickBooks** (`quickbooks.go`) | | `?requestid=<key>` (QBO idempotent create) | OAuth2 Bearer | `QUICKBOOKS_*` |
| **Xero** (`xero.go`) | | `Idempotency-Key` header (Xero native) | OAuth2 Bearer + `Xero-Tenant-Id` | `XERO_*` |
| **NetSuite** (`netsuite.go`) | | `externalId` upsert (`PUT …/eid:{key}`) | OAuth 1.0a TBA (HMAC-SHA256) | `NETSUITE_*` |

All non-2xx (except 409) become a `*PostError`; 4xx other than 429 is flagged
`Permanent` so callers can dead-letter instead of retrying forever. The JSON
bodies are minimal templates — map the journal lines to your chart of accounts;
auth/idempotency/transport are production-ready as written.

```bash
# Bigcapital (default, your self-hosted instance)
export BIGCAPITAL_BASE_URL=https://accounting.gridiron.internal \
       BIGCAPITAL_ACCESS_TOKEN=… BIGCAPITAL_ORGANIZATION_ID=…
# QuickBooks Online
export QUICKBOOKS_REALM_ID=… QUICKBOOKS_ACCESS_TOKEN=…
# Xero
export XERO_TENANT_ID=… XERO_ACCESS_TOKEN=…
# NetSuite
export NETSUITE_ACCOUNT_ID=1234567_SB1 NETSUITE_BASE_URL=https://1234567.suitetalk.api.netsuite.com \
       NETSUITE_CONSUMER_KEY=… NETSUITE_CONSUMER_SECRET=… NETSUITE_TOKEN_ID=… NETSUITE_TOKEN_SECRET=…
```

> OAuth2 bearer tokens (QuickBooks, Xero) are injected via config/secret; token
> refresh is handled upstream. NetSuite TBA is fully self-contained.

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

## Add another ERP target later (e.g. SAP)

1. Implement `accounting.AccountingTarget` (keep `Post` idempotent on the key,
   using the API's native mechanism; reuse `doJSONRequest` for execution).
2. `accounting.Register("sap", func() AccountingTarget { return NewSAP(cfg) })` in
   its `init()` — it then appears in `AvailableTargets()` for the ERP selector.
3. Add a row to the table in `targets_http_test.go`; keep `make accounting` green.

| File | Role |
|---|---|
| `contract.go` | Event/entry types, `AccountingTarget`/`IdempotencyStore` interfaces, the `Dispatcher` |
| `targets.go` | Target registry + selection (default = Bigcapital); `MemoryLedger` reference target |
| `httptarget.go` | Shared HTTP execution + `*PostError` classification for all targets |
| `bigcapital.go` | **Default** in-house target |
| `quickbooks.go` / `xero.go` / `netsuite.go` | QuickBooks, Xero, NetSuite targets |
| `store.go` | Reference in-memory idempotency store |
| `redis_store.go` | Durable Redis-backed idempotency store |
| `*_test.go` | The exactly-once contract tests (the gate) |
