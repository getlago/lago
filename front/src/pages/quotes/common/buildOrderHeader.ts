import { TranslateFunc } from '~/hooks/core/useInternationalization'

import { QuotePdfHeaderData } from './buildQuotePreviewProps'

export const buildOrderHeader = (
  order: { number?: string | null },
  translate: TranslateFunc,
): QuotePdfHeaderData => {
  const orderNumber = order.number ?? ''

  return {
    documentNumber: orderNumber,
    rows: [translate('text_1782723591984l12xpznkwqd', { orderNumber })],
  }
}
