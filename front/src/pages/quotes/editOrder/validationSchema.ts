import { DateTime } from 'luxon'
import { z } from 'zod'

import { OrderExecutionModeEnum, UpdateOrderInput } from '~/generated/graphql'

export const editOrderValidationSchema = z
  .object({
    executionMode: z.nativeEnum(OrderExecutionModeEnum).optional(),
    executeAt: z.string().optional(),
  })
  .refine((data) => !!data.executionMode, {
    message: 'text_17816865941254uzl22ixohk',
    path: ['executionMode'],
  })
  // Execution must be scheduled for a future day — today and past are rejected by the backend
  .refine(
    (data) => {
      if (!data.executeAt) return true

      return DateTime.fromISO(data.executeAt).startOf('day') > DateTime.now().startOf('day')
    },
    {
      message: 'text_1781698831945d8qod1ugqsu',
      path: ['executeAt'],
    },
  )

export type EditOrderFormValues = z.infer<typeof editOrderValidationSchema>

export const buildUpdateOrderInput = (
  orderId: string,
  values: EditOrderFormValues,
): UpdateOrderInput => ({
  id: orderId,
  executionMode: values.executionMode,
  executeAt: values.executeAt,
})
