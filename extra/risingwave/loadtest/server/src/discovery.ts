import {
  amountOf,
  groupKeysOf,
  listBillableMetrics,
  listPlans,
  listSubscriptions,
  listWallets,
  type LagoBillableMetric,
} from "./clients/lago.js";

/** An active wallet, as far as the load test needs to know it. */
export type WalletInfo = {
  customerExternalId: string;
  code: string | null;
  name: string | null;
  currency: string;
  balanceCents: number;
  ongoingUsageCents: number;
  /** Wallet restricted to these metric codes; empty = applies to everything. */
  metricCodes: string[];
  feeTypes: string[];
  /** True when this Lago serializes last_ongoing_balance_sync_at. */
  exposesSyncStamp: boolean;
};

/** One thing the load generator can send events for. */
export type Target = {
  id: string;
  subscriptionExternalId: string;
  customerExternalId: string;
  subscriptionName: string | null;
  planCode: string;
  metricCode: string;
  aggregationType: string;
  fieldName: string | null;
  chargeModel: string;
  /** Every charge filter, so load can be spread across all of them. */
  filters: {
    id: string;
    label: string | null;
    values: Record<string, string[]>;
    groupKeys: string[];
    /** Per-filter price override, in currency units. */
    amount: number | null;
  }[];
  /** Charge-level per-unit price, in currency units (standard charges only). */
  amount: number | null;
  /** Charge-level pricing group keys (grouped_by), if any. */
  groupKeys: string[];
  /** count/sum recompose across 15-minute buckets; the rest do not (yet). */
  servedByRealtimeBuckets: boolean;
  /** Active wallets of this target's customer — a wallet probe needs one. */
  wallets: WalletInfo[];
};

export type DiscoveryResult = {
  targets: Target[];
  subscriptions: {
    subscriptionExternalId: string;
    customerExternalId: string;
    name: string | null;
    planCode: string;
    status: string;
    metricCount: number;
  }[];
  wallets: WalletInfo[];
  warnings: string[];
  scannedAt: number;
};

const AGG_SERVED = new Set(["count_agg", "sum_agg"]);

/**
 * Walks Lago: subscriptions -> plan -> charges -> billable metrics, and turns the
 * result into targets the UI can tick. Only active subscriptions are offered, and
 * only metrics whose plan actually charges for them (an event for an uncharged
 * metric never reaches events_expanded, so it could never be measured past stage 0).
 */
export async function discover(): Promise<DiscoveryResult> {
  const warnings: string[] = [];
  // Labelled so a failure names the endpoint that broke rather than collapsing
  // into one anonymous rejection from Promise.all.
  const step = async <T>(label: string, f: () => Promise<T>): Promise<T> => {
    try {
      return await f();
    } catch (e) {
      throw new Error(`discovery failed while listing ${label}: ${(e as Error).message}`);
    }
  };
  const [subs, plans, metrics] = await Promise.all([
    step("subscriptions", listSubscriptions),
    step("plans", listPlans),
    step("billable metrics", listBillableMetrics),
  ]);

  // Wallets are listed separately and NON-fatally: an instance with no wallet is
  // a perfectly valid load-test target, it just cannot measure the wallet hop.
  const wallets: WalletInfo[] = [];
  try {
    for (const w of await listWallets()) {
      if (w.status !== "active") continue;
      wallets.push({
        customerExternalId: w.external_customer_id,
        code: w.code ?? null,
        name: w.name ?? null,
        currency: w.currency,
        balanceCents: Number(w.balance_cents) || 0,
        ongoingUsageCents: Number(w.ongoing_usage_balance_cents) || 0,
        metricCodes: w.applies_to?.billable_metric_codes ?? [],
        feeTypes: w.applies_to?.fee_types ?? [],
        exposesSyncStamp: w.last_ongoing_balance_sync_at !== undefined,
      });
    }
  } catch (e) {
    warnings.push(`wallets could not be listed (${(e as Error).message}) — wallet latency will not be measurable`);
  }
  const walletsByCustomer = new Map<string, WalletInfo[]>();
  for (const w of wallets) {
    const list = walletsByCustomer.get(w.customerExternalId) ?? [];
    list.push(w);
    walletsByCustomer.set(w.customerExternalId, list);
  }

  const planByCode = new Map(plans.map((p) => [p.code, p]));
  const bmByCode = new Map(metrics.map((m) => [m.code, m]));

  const targets: Target[] = [];
  const subscriptions: DiscoveryResult["subscriptions"] = [];

  for (const s of subs) {
    if (s.status !== "active") continue;
    const plan = planByCode.get(s.plan_code);
    if (!plan) {
      warnings.push(`subscription ${s.external_id}: plan ${s.plan_code} not readable, skipped`);
      continue;
    }
    const charges = plan.charges ?? [];
    if (charges.length === 0) warnings.push(`plan ${plan.code} has no charges — nothing to measure`);

    let metricCount = 0;
    for (const charge of charges) {
      const bm = bmByCode.get(charge.billable_metric_code);
      if (!bm) {
        warnings.push(`charge ${charge.lago_id}: billable metric ${charge.billable_metric_code} not readable`);
        continue;
      }
      metricCount++;
      targets.push({
        id: `${s.external_id}::${bm.code}::${charge.lago_id}`,
        subscriptionExternalId: s.external_id,
        customerExternalId: s.external_customer_id,
        subscriptionName: s.name ?? null,
        planCode: plan.code,
        metricCode: bm.code,
        aggregationType: bm.aggregation_type,
        fieldName: bm.field_name ?? null,
        chargeModel: charge.charge_model,
        filters: (charge.filters ?? []).map((f, i) => ({
          id: `${charge.lago_id}#${i}`,
          label: f.invoice_display_name ?? null,
          values: f.values ?? {},
          groupKeys: groupKeysOf(f.properties),
          amount: amountOf(f.properties),
        })),
        amount: amountOf(charge.properties),
        groupKeys: groupKeysOf(charge.properties),
        servedByRealtimeBuckets: AGG_SERVED.has(bm.aggregation_type),
        wallets: walletsByCustomer.get(s.external_customer_id) ?? [],
      });
    }
    subscriptions.push({
      subscriptionExternalId: s.external_id,
      customerExternalId: s.external_customer_id,
      name: s.name ?? null,
      planCode: s.plan_code,
      status: s.status,
      metricCount,
    });
  }

  if (targets.length === 0) warnings.push("no active subscription with a charged billable metric was found");
  if (wallets.length > 0 && targets.every((t) => t.wallets.length === 0))
    warnings.push(
      `${wallets.length} active wallet(s) exist, but none belong to a customer with a chargeable subscription — ` +
        "wallet latency needs a customer that both holds a wallet and can receive events",
    );
  const notServed = targets.filter((t) => !t.servedByRealtimeBuckets).length;
  if (notServed > 0)
    warnings.push(
      `${notServed} target(s) use an aggregation the realtime bucket path does not serve yet ` +
        `(only count and sum recompose across buckets) — usage latency for those measures the fallback read path`,
    );
  return { targets, subscriptions, wallets, warnings, scannedAt: Date.now() };
}


