import { test } from "node:test";
import assert from "node:assert/strict";
import { scopeClause } from "../clients/clickhouse.js";

test("the ClickHouse scope leads with the organization and bounds on the event timestamp, which are in the key", () => {
  const sql = scopeClause({ orgId: "org-1", subs: ["s1", "s2"], codes: ["c1"], sinceMs: 1_700_000_000_123 });
  assert.match(sql, /^ AND organization_id = 'org-1' AND /);
  assert.match(sql, /external_subscription_id IN \('s1','s2'\)/);
  assert.match(sql, /code IN \('c1'\)/);
  assert.match(sql, /timestamp >= fromUnixTimestamp64Milli\(toInt64\(1700000000123\)\)/);
  // enriched_at is deliberately never part of the scope: it is not in the key.
  assert.doesNotMatch(sql, /enriched_at/);
});

test("an unknown organization degrades to the narrower predicates instead of failing", () => {
  const sql = scopeClause({ orgId: null, subs: [], codes: [], sinceMs: 0 });
  assert.equal(sql, "");
});
