import { ChargeUsage, ProjectedChargeUsage } from '~/generated/graphql'

export const NO_ID_FILTER_DEFAULT_VALUE = 'NO_ID_FILTER_DEFAULT_VALUE'

export type SubscriptionUsageDetailDrawerUsage = ChargeUsage | ProjectedChargeUsage

export type PresentationBreakdownRow = {
  id: string
  __isBreakdown: true
  presentationBy: Record<string, unknown>
  breakdownUnits: string
}

export const isBreakdownRow = (row: unknown): row is PresentationBreakdownRow =>
  typeof row === 'object' && row !== null && '__isBreakdown' in row

export const sumBreakdownUnits = (
  breakdowns: ReadonlyArray<{ units: string }> | null | undefined,
): number => (breakdowns ?? []).reduce((acc, b) => acc + (Number(b.units) || 0), 0)

// A "meaningful" presentation value is one that's actually present — we
// suppress null/undefined/empty-string entries so the UI never renders
// blank chips (or worse, the literal string "undefined").
export const isMeaningfulPresentationValue = (value: unknown): boolean => {
  if (value === null || value === undefined) return false
  if (typeof value === 'string') return value.length > 0
  return true
}

// Build a stable key from a `presentationBy` object — sorted by key so
// `{a:1,b:2}` and `{b:2,a:1}` collapse to the same string. Same shape as the
// internal key used by `makeBreakdownRows` so dedupe stays consistent across
// helpers.
const stableKeyForPresentationBy = (presentationBy: unknown): string => {
  const pby = (presentationBy ?? {}) as Record<string, unknown>

  return JSON.stringify(
    Object.keys(pby)
      .sort((a, b) => a.localeCompare(b))
      .map((k) => [k, pby[k]]),
  )
}

// Filter `tail` to only entries whose `presentationBy` key doesn't already
// appear in `alreadyRendered`. We need this because the backend sometimes
// includes the same breakdown both under a filter AND on the parent's
// `presentationBreakdowns` (observed when a group has a no-id "catch-all"
// filter — the filter and the tail describe the same fees). Without dedupe
// the UI renders the row twice.
export const dedupeTailBreakdowns = <T extends { presentationBy: unknown; units: string }>(
  alreadyRendered: ReadonlyArray<ReadonlyArray<T> | null | undefined>,
  tail: ReadonlyArray<T> | null | undefined,
): T[] => {
  if (!tail?.length) return []

  const seen = new Set<string>()

  for (const set of alreadyRendered) {
    for (const b of set ?? []) {
      seen.add(stableKeyForPresentationBy(b.presentationBy))
    }
  }

  return tail.filter((b) => !seen.has(stableKeyForPresentationBy(b.presentationBy)))
}

export const makeBreakdownRows = (
  parentId: string,
  breakdowns: ReadonlyArray<{ presentationBy: unknown; units: string }> | null | undefined,
): PresentationBreakdownRow[] => {
  // The backend emits one breakdown per fee — when a parent (grouped usage or
  // charge usage) spans multiple fees, identical `presentationBy` keys repeat
  // and the displayed units would over-count vs the parent row. Aggregate here
  // so the breakdown rows partition the parent's units.
  const grouped = new Map<string, { presentationBy: Record<string, unknown>; total: number }>()

  for (const b of breakdowns ?? []) {
    const presentationBy = (b.presentationBy ?? {}) as Record<string, unknown>

    // We KEEP breakdowns whose `presentationBy` has no meaningful values —
    // the QA team wants those rendered as an empty name cell + the units.
    // Per-value null filtering happens inside `BreakdownNameCell` so the chips
    // stay clean while the row remains visible.
    const stableKey = JSON.stringify(
      Object.keys(presentationBy)
        .sort((keyA, keyB) => keyA.localeCompare(keyB))
        .map((k) => [k, presentationBy[k]]),
    )
    const units = Number(b.units) || 0
    const existing = grouped.get(stableKey)

    if (existing) {
      existing.total += units
    } else {
      grouped.set(stableKey, { presentationBy, total: units })
    }
  }

  return Array.from(grouped.values()).map((entry, i) => ({
    id: `${parentId}__breakdown__${i}`,
    __isBreakdown: true,
    presentationBy: entry.presentationBy,
    breakdownUnits: String(entry.total),
  }))
}
