import { DateTime } from 'luxon'
import { z } from 'zod'

import { InvoiceCustomSectionInput } from '~/components/invoceCustomFooter/types'
import { SelectedPaymentMethod } from '~/components/paymentMethodSelection/types'
import { ActivationRuleFormTypeEnum } from '~/core/constants/subscriptionActivationRules'
import { BillingTimeEnum } from '~/generated/graphql'

export interface SubscriptionFormValues {
  planId: string
  name: string
  externalId: string
  subscriptionAt: string
  endingAt?: string
  billingTime: BillingTimeEnum
  paymentMethod?: SelectedPaymentMethod
  invoiceCustomSection?: InvoiceCustomSectionInput
  billingEntityId?: string
  consolidateInvoice: boolean
  activationRuleType?: ActivationRuleFormTypeEnum
  activationRuleTimeoutHours?: string
}

export const subscriptionFormSchema = z
  .custom<SubscriptionFormValues>()
  .superRefine((data, ctx) => {
    if (!data.planId) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_624ea7c29103fd010732ab7d',
        path: ['planId'],
      })
    }

    if (!data.subscriptionAt) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_624ea7c29103fd010732ab7d',
        path: ['subscriptionAt'],
      })
    }

    if (data.activationRuleType === ActivationRuleFormTypeEnum.OnPayment) {
      // An empty timeout is valid and means "no timeout" (sent as null to the BE).
      // Only validate the format when the user actually provided a value.
      const hasTimeoutValue =
        data.activationRuleTimeoutHours !== undefined && data.activationRuleTimeoutHours !== ''

      if (hasTimeoutValue) {
        const timeoutHours = Number(data.activationRuleTimeoutHours)

        if (!Number.isInteger(timeoutHours) || timeoutHours < 0) {
          ctx.addIssue({
            code: 'custom',
            message: 'text_1779882021466eoq8jjhfteu',
            path: ['activationRuleTimeoutHours'],
          })
        }
      }
    }

    if (!data.endingAt) return

    if (!DateTime.fromISO(data.endingAt).isValid) {
      ctx.addIssue({
        code: 'custom',
        message: 'text_64ef55a730b88e3d2117b3d4',
        path: ['endingAt'],
      })
      return
    }

    if (data.subscriptionAt) {
      const subscriptionAt = DateTime.fromISO(data.subscriptionAt)
      const endingAt = DateTime.fromISO(data.endingAt)

      if (endingAt <= subscriptionAt || DateTime.now().diff(endingAt, 'days').days >= 0) {
        ctx.addIssue({
          code: 'custom',
          message: 'text_64ef55a730b88e3d2117b3d4',
          path: ['endingAt'],
        })
      }
    }
  })
