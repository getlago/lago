export const normalizePurchaseOrderNumber = (value?: string | null) => {
  const trimmed = value?.trim()

  return trimmed || null
}
