import { DateTime } from 'luxon'
import { z } from 'zod'

import { CurrencyEnum } from '~/generated/graphql'

export const editQuoteAsideSchema = z
  .object({
    orderTypeLabel: z.string(),
    customerName: z.string(),
    billingEntityId: z.string(),
    currency: z.nativeEnum(CurrencyEnum).optional(),
    subscriptionLabel: z.string().optional(),
    startDate: z.string().optional(),
    endDate: z.string().optional(),
    netPaymentTermLabel: z.string().optional(),
  })
  .superRefine((data, ctx) => {
    if (data.startDate && data.endDate) {
      const start = DateTime.fromISO(data.startDate)
      const end = DateTime.fromISO(data.endDate)

      if (end <= start) {
        ctx.addIssue({
          code: 'custom',
          message: 'text_64ef55a730b88e3d2117b3d4',
          path: ['endDate'],
        })
      }
    }
  })

export type EditQuoteAsideFormValues = z.infer<typeof editQuoteAsideSchema>

export const editQuoteAsideDefaultValues: EditQuoteAsideFormValues = {
  orderTypeLabel: '',
  customerName: '',
  billingEntityId: '',
  currency: undefined,
  subscriptionLabel: undefined,
  startDate: undefined,
  endDate: undefined,
  netPaymentTermLabel: undefined,
}
