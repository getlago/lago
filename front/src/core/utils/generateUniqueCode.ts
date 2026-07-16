// Builds a code that doesn't collide with `existing`, appending an incrementing
// numeric suffix from 2 onwards (e.g. `base`, `base_2`, `base_3`). Final
// uniqueness is still enforced by the backend; this only seeds a sensible default.
export const generateUniqueCode = (
  base: string,
  existing: (string | null | undefined)[],
): string => {
  const taken = new Set(existing.filter((code): code is string => !!code))

  if (!base || !taken.has(base)) return base

  let suffix = 2

  while (taken.has(`${base}_${suffix}`)) {
    suffix++
  }

  return `${base}_${suffix}`
}
