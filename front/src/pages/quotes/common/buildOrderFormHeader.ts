import { TranslateFunc } from '~/hooks/core/useInternationalization'

import { QuotePdfHeaderData } from './buildQuotePreviewProps'

export const buildOrderFormHeader = (
  orderForm: { number?: string | null; expiresAt?: string | null },
  translate: TranslateFunc,
  formatDate: (iso: string) => string,
): QuotePdfHeaderData => {
  const orderFormNumber = orderForm.number ?? ''

  const rows = [translate('text_1781778938224iupllzr5sgb', { orderFormNumber })]

  if (orderForm.expiresAt) {
    rows.push(translate('text_1781874334924qwjnv1swbo2', { date: formatDate(orderForm.expiresAt) }))
  }

  return { documentNumber: orderFormNumber, rows }
}
