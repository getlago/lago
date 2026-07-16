type Entitlement = { featureCode: string }

export const upsertEntitlement = <T extends Entitlement>(
  list: ReadonlyArray<T> | null | undefined,
  next: T,
): T[] => {
  const current = list ? [...list] : []
  const idx = current.findIndex((entitlement) => entitlement.featureCode === next.featureCode)

  if (idx >= 0) {
    current[idx] = next
    return current
  }
  current.push(next)
  return current
}

export const removeEntitlementByFeatureCode = <T extends Entitlement>(
  list: ReadonlyArray<T> | null | undefined,
  featureCode: string,
): T[] => (list ?? []).filter((entitlement) => entitlement.featureCode !== featureCode)
