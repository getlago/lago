export interface AddOnItem {
  localId: string
  addOnId: string
  name: string
  invoiceDisplayName: string
  code: string
  description: string
  units: string
  unitAmountCents: string
  totalAmount: string
  fromDatetime: string
  toDatetime: string
}

export const pricingDrawerDefaultValues = {
  planId: '',
  addOnItems: [] as AddOnItem[],
}
