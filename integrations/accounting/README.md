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

## Wiring the real connector later

1. Implement `accounting.AccountingTarget` for the ERP (e.g. NetSuite), keeping
   `Post` idempotent on `entry.IdempotencyKey`.
2. `accounting.Register("netsuite", func() AccountingTarget { return NewNetSuite(cfg) })`
   in its `init()`. It then appears in `AvailableTargets()` for the ERP selector.
3. Back `IdempotencyStore` with Postgres/Redis instead of `MemoryStore`.
4. Keep `make accounting` green. Add target-specific cases to `contract_test.go`.

| File | Role |
|---|---|
| `contract.go` | Event/entry types, `AccountingTarget`/`IdempotencyStore` interfaces, the `Dispatcher` |
| `targets.go` | Target registry + selection (default = Gridiron); in-house Gridiron target |
| `store.go` | Reference in-memory idempotency store |
| `contract_test.go` | The exactly-once contract tests (the gate) |
