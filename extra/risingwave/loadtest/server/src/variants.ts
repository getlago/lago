import type { Target } from "./discovery.js";

/**
 * One concrete event shape to send. Spreading load across every variant is what
 * exercises the parts of the pipeline that only fire on real dimension variety:
 * `filter_match_score` picking between competing charge filters, the
 * default-bucket fallback when nothing matches, and `extract_grouped_by`
 * producing distinct grouped_by keys (each of which becomes its own
 * usage_buckets_15m row).
 */
export type EventVariant = {
  key: string;
  label: string;
  properties: Record<string, string>;
  /** The charge filter this variant is built to match; null = default bucket. */
  chargeFilterId: string | null;
  groupLabel: string | null;
};

export type SpreadSpec = {
  /** How many synthetic values to generate per pricing group key. */
  groupKeyValues: number;
  /** Also send events that match no filter, to exercise the default bucket. */
  includeDefaultBucket: boolean;
  /** Safety cap so a wide charge cannot explode into thousands of shapes. */
  maxVariantsPerTarget: number;
};

export const DEFAULT_SPREAD: SpreadSpec = {
  groupKeyValues: 3,
  includeDefaultBucket: true,
  maxVariantsPerTarget: 24,
};

const NO_MATCH = "lt_no_match";

/** The property the metric aggregates, always 1 so expected unit totals are exact. */
function metricProps(t: Target): Record<string, string> {
  if (t.aggregationType === "count_agg") return {};
  const field = t.fieldName?.trim();
  return field ? { [field]: "1" } : {};
}

/**
 * A charge filter matches when the event's properties satisfy its values. A
 * filter declaring several values for one key is ONE bucket, so covering it
 * needs one variant per value, not the cross product — that keeps coverage
 * complete while the count stays linear in the declared values.
 */
function filterVariants(values: Record<string, string[]>): Record<string, string>[] {
  const keys = Object.keys(values).filter((k) => (values[k] ?? []).some((v) => v && v !== "__ALL_FILTER_VALUES__"));
  if (keys.length === 0) return [{}];
  const usable = keys.map((k) => ({
    key: k,
    vals: (values[k] ?? []).filter((v) => v && v !== "__ALL_FILTER_VALUES__"),
  }));
  const rounds = Math.max(...usable.map((u) => u.vals.length));
  const out: Record<string, string>[] = [];
  for (let i = 0; i < rounds; i++) {
    const props: Record<string, string> = {};
    for (const u of usable) props[u.key] = u.vals[i % u.vals.length]!;
    out.push(props);
  }
  return out;
}

/** Cross a base variant with synthetic values for each pricing group key. */
function withGroupKeys(
  base: Record<string, string>,
  groupKeys: string[],
  perKey: number,
): { props: Record<string, string>; label: string | null }[] {
  if (groupKeys.length === 0 || perKey <= 1) {
    if (groupKeys.length === 0) return [{ props: base, label: null }];
    const props = { ...base };
    for (const k of groupKeys) props[k] = `${k}_g1`;
    return [{ props, label: groupKeys.map((k) => `${k}=${k}_g1`).join(", ") }];
  }
  // Rotate the keys in lockstep: N distinct grouped_by keys rather than N^k.
  const out: { props: Record<string, string>; label: string | null }[] = [];
  for (let i = 1; i <= perKey; i++) {
    const props = { ...base };
    const parts: string[] = [];
    for (const k of groupKeys) {
      props[k] = `${k}_g${i}`;
      parts.push(`${k}=${k}_g${i}`);
    }
    out.push({ props, label: parts.join(", ") });
  }
  return out;
}

export function buildVariants(t: Target, spread: SpreadSpec): { variants: EventVariant[]; truncated: number } {
  const base = metricProps(t);
  const out: EventVariant[] = [];

  for (const f of t.filters) {
    const groupKeys = f.groupKeys.length ? f.groupKeys : t.groupKeys;
    for (const fv of filterVariants(f.values)) {
      const filterLabel = Object.entries(fv)
        .map(([k, v]) => `${k}=${v}`)
        .join(", ");
      for (const g of withGroupKeys({ ...base, ...fv }, groupKeys, spread.groupKeyValues)) {
        out.push({
          key: `${f.id}:${filterLabel}:${g.label ?? ""}`,
          label: [filterLabel || "filter", g.label].filter(Boolean).join(" · "),
          properties: g.props,
          chargeFilterId: f.id,
          groupLabel: g.label,
        });
      }
    }
  }

  // The default bucket: properties that deliberately match no declared filter
  // value, so the event is attributed to the charge itself. Worth exercising —
  // it is a distinct code path (MatchingFilter/ToDefaultFilter) and a distinct
  // usage row.
  const filterKeys = [...new Set(t.filters.flatMap((f) => Object.keys(f.values)))];
  if (t.filters.length === 0 || (spread.includeDefaultBucket && filterKeys.length > 0)) {
    const props = { ...base };
    for (const k of filterKeys) props[k] = NO_MATCH;
    for (const g of withGroupKeys(props, t.groupKeys, spread.groupKeyValues)) {
      out.push({
        key: `default:${g.label ?? ""}`,
        label: [t.filters.length === 0 ? "no filters on charge" : "default bucket (no filter match)", g.label]
          .filter(Boolean)
          .join(" · "),
        properties: g.props,
        chargeFilterId: null,
        groupLabel: g.label,
      });
    }
  }

  const capped = out.slice(0, Math.max(1, spread.maxVariantsPerTarget));
  return { variants: capped, truncated: out.length - capped.length };
}

/** Units one event of this variant adds: 1 per event for count, else the field value. */
export function unitsOfVariant(t: Target, v: EventVariant): number {
  if (t.aggregationType === "count_agg") return 1;
  const field = t.fieldName?.trim();
  const n = Number(field ? v.properties[field] : undefined);
  return Number.isFinite(n) ? n : 1;
}
