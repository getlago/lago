import { z } from 'zod'

import { CurrencyEnum, OrderTypeEnum } from '~/generated/graphql'

export const createQuoteSchema = z
  .object({
    customerId: z.string().min(1, 'text_1776238919927l1m2n3o4p5q'),
    orderType: z.nativeEnum(OrderTypeEnum),
    subscriptionId: z.string(),
    owners: z.array(z.looseObject({ value: z.string() })).optional(),
    currency: z.nativeEnum(CurrencyEnum).optional(),
  })
  .refine(
    (data) => {
      if (data.orderType !== OrderTypeEnum.SubscriptionAmendment) return true

      return !!data.subscriptionId && data.subscriptionId.length > 0
    },
    {
      path: ['subscriptionId'],
      message: 'text_1776238919927d6e7f8g9h0i',
    },
  )

export type CreateQuoteFormValues = z.infer<typeof createQuoteSchema>
