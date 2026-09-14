-- minmax skip index on enriched_at for the two RisingWave shadow tables.
--
-- Why: enriched_at (stamped by ClickHouse at insert) is the column every
-- latency question filters on — the load test's stamp sweeps, the Grafana
-- risingwave-latency panels ("enriched_at > now() - 1 minute") — and it is in
-- neither table's ORDER BY, so such a predicate on its own reads every row the
-- other predicates admit: a full 527M-row scan per Grafana panel refresh, and
-- the load test rescanning its whole run every 2 s. Measured 2026-09-07 at
-- 20k events/s: ClickHouse spent 3.6 cores on those reads and 0.17 on writes.
--
-- Rows are inserted in enriched_at order, so every granule's [min, max] is a
-- narrow, disjoint range and a minmax index prunes almost perfectly. Cheap to
-- maintain (two DateTime64 per 4 granules).
--
-- Applied by setup.sh after the CREATE TABLEs (zz_ sorts last); the CREATE
-- TABLE files also declare the index for fresh tables, so this is a no-op
-- there. MATERIALIZE INDEX builds it for parts that predate the index — a
-- background mutation over the existing data, run it once; new parts get the
-- index at insert regardless.
ALTER TABLE default.events_enriched_rw_shadow
    ADD INDEX IF NOT EXISTS idx_enriched_at enriched_at TYPE minmax GRANULARITY 4;
ALTER TABLE default.events_enriched_expanded_rw_shadow
    ADD INDEX IF NOT EXISTS idx_enriched_at enriched_at TYPE minmax GRANULARITY 4;
ALTER TABLE default.events_enriched_rw_shadow MATERIALIZE INDEX idx_enriched_at;
ALTER TABLE default.events_enriched_expanded_rw_shadow MATERIALIZE INDEX idx_enriched_at;
