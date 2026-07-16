import { gql } from '@apollo/client'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useCallback, useMemo } from 'react'
import { z } from 'zod'

import { scrollToFirstInputError } from '~/core/form/scrollToFirstInputError'
import { deserializeAmount, serializeAmount } from '~/core/serializers/serializeAmount'
import {
  CurrencyEnum,
  UseSubscriptionForProgressiveBillingFormFragment,
  useUpdateSubscriptionProgressiveBillingMutation,
} from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'

gql`
  fragment ThresholdForProgressiveBillingForm on UsageThreshold {
    id
    amountCents
    recurring
    thresholdDisplayName
  }

  fragment UseSubscriptionForProgressiveBillingForm on Subscription {
    progressiveBillingDisabled
    usageThresholds {
      ...ThresholdForProgressiveBillingForm
    }
    plan {
      applicableUsageThresholds {
        ...ThresholdForProgressiveBillingForm
      }
    }
  }
`

// Error message identifiers for validation
const ERROR_REQUIRED = 'REQUIRED'

export const ERROR_ASCENDING_ORDER = 'ASCENDING_ORDER'

export const DEFAULT_PROGRESSIVE_BILLING = {
  amountCents: '1',
  thresholdDisplayName: '',
  recurring: false,
}

interface ThresholdInput {
  amountCents: string
  thresholdDisplayName: string
  recurring: boolean
  [key: string]: unknown
}

export interface ProgressiveBillingFormValues {
  progressiveBillingDisabled: boolean
  nonRecurringThresholds: ThresholdInput[]
  hasRecurring: boolean
  recurringThreshold: ThresholdInput
}

interface UseProgressiveBillingTanstackFormProps {
  subscriptionId: string
  subscription: UseSubscriptionForProgressiveBillingFormFragment | null | undefined
  currency: CurrencyEnum
  onSuccess: () => void
}

export const useProgressiveBillingTanstackForm = ({
  subscriptionId,
  subscription,
  currency,
  onSuccess,
}: UseProgressiveBillingTanstackFormProps) => {
  const [updateSubscription] = useUpdateSubscriptionProgressiveBillingMutation({
    onCompleted({ updateSubscription: result }) {
      if (result?.id) {
        onSuccess()
      }
    },
  })

  const initialValues = useMemo((): ProgressiveBillingFormValues => {
    let thresholds:
      | UseSubscriptionForProgressiveBillingFormFragment['usageThresholds']
      | UseSubscriptionForProgressiveBillingFormFragment['plan']['applicableUsageThresholds'] = []

    if (!!subscription?.usageThresholds?.length) {
      thresholds = subscription.usageThresholds
    } else if (!!subscription?.plan?.applicableUsageThresholds?.length) {
      thresholds = subscription.plan.applicableUsageThresholds
    }

    const nonRecurring = thresholds.filter((t) => !t.recurring)
    const recurring = thresholds.find((t) => t.recurring)

    return {
      progressiveBillingDisabled: subscription?.progressiveBillingDisabled ?? false,
      nonRecurringThresholds:
        nonRecurring.length > 0
          ? nonRecurring.map((t) => ({
              amountCents: t.amountCents ? String(deserializeAmount(t.amountCents, currency)) : '',
              thresholdDisplayName: t.thresholdDisplayName || '',
              recurring: false,
            }))
          : [DEFAULT_PROGRESSIVE_BILLING],
      hasRecurring: !!recurring,
      recurringThreshold: recurring
        ? {
            amountCents: recurring.amountCents
              ? String(deserializeAmount(recurring.amountCents, currency))
              : '',
            thresholdDisplayName: recurring.thresholdDisplayName || '',
            recurring: true,
          }
        : { amountCents: '', thresholdDisplayName: '', recurring: true },
    }
  }, [subscription, currency])

  const thresholdSchema = z.object({
    amountCents: z.string(),
    thresholdDisplayName: z.string(),
    recurring: z.boolean(),
  })

  const validationSchema = z
    .object({
      progressiveBillingDisabled: z.boolean(),
      nonRecurringThresholds: z.array(thresholdSchema),
      hasRecurring: z.boolean(),
      recurringThreshold: thresholdSchema,
    })
    .superRefine((data, ctx) => {
      // Skip threshold validation when progressive billing is disabled
      if (data.progressiveBillingDisabled) {
        return
      }

      // Validate non-recurring thresholds
      data.nonRecurringThresholds.forEach((threshold, index) => {
        const amountCents = threshold.amountCents?.trim() || ''

        // Check required
        if (amountCents.length === 0) {
          ctx.addIssue({
            code: 'custom',
            message: ERROR_REQUIRED,
            path: ['nonRecurringThresholds', index, 'amountCents'],
          })
          return
        }

        // Check ascending order (each row must be greater than the previous)
        if (index > 0) {
          const currentAmount = parseFloat(amountCents)
          const previousAmount = parseFloat(
            data.nonRecurringThresholds[index - 1]?.amountCents || '0',
          )

          if (!isNaN(currentAmount) && !isNaN(previousAmount) && currentAmount <= previousAmount) {
            ctx.addIssue({
              code: 'custom',
              message: ERROR_ASCENDING_ORDER,
              path: ['nonRecurringThresholds', index, 'amountCents'],
            })
          }
        }
      })

      // Validate recurring threshold only when hasRecurring is true
      if (data.hasRecurring) {
        if (
          !data.recurringThreshold.amountCents ||
          data.recurringThreshold.amountCents.trim().length === 0
        ) {
          ctx.addIssue({
            code: 'custom',
            message: ERROR_REQUIRED,
            path: ['recurringThreshold', 'amountCents'],
          })
        }
      }
    })

  const form = useAppForm({
    defaultValues: initialValues,
    validationLogic: revalidateLogic(),
    validators: {
      onChange: validationSchema,
      onDynamic: validationSchema,
    },
    onSubmit: async ({ value }) => {
      const thresholds: Array<{
        amountCents: number
        thresholdDisplayName?: string
        recurring: boolean
      }> = []

      // Add non-recurring thresholds
      value.nonRecurringThresholds.forEach((t) => {
        if (t.amountCents) {
          thresholds.push({
            amountCents: Number(serializeAmount(t.amountCents, currency)),
            thresholdDisplayName: t.thresholdDisplayName || undefined,
            recurring: false,
          })
        }
      })

      // Add recurring threshold if enabled
      if (value.hasRecurring && value.recurringThreshold.amountCents) {
        thresholds.push({
          amountCents: Number(serializeAmount(value.recurringThreshold.amountCents, currency)),
          thresholdDisplayName: value.recurringThreshold.thresholdDisplayName || undefined,
          recurring: true,
        })
      }

      await updateSubscription({
        variables: {
          input: {
            id: subscriptionId,
            progressiveBillingDisabled: value.progressiveBillingDisabled,
            usageThresholds: thresholds,
          },
        },
      })
    },
    onSubmitInvalid({ formApi }) {
      scrollToFirstInputError(
        'create-subscription-progressive-billing',
        formApi.state.errorMap.onDynamic || {},
      )
    },
  })

  const {
    progressiveBillingDisabled,
    nonRecurringThresholds,
    hasRecurring,
    recurringThreshold,
    isDirty,
  } = useStore(form.store, (state) => ({
    progressiveBillingDisabled: state.values.progressiveBillingDisabled,
    nonRecurringThresholds: state.values.nonRecurringThresholds,
    hasRecurring: state.values.hasRecurring,
    recurringThreshold: state.values.recurringThreshold,
    isDirty: state.isDirty,
  }))

  const handleAddThreshold = useCallback(() => {
    const lastThreshold = nonRecurringThresholds[nonRecurringThresholds.length - 1]
    const lastAmount = parseFloat(lastThreshold?.amountCents) || 0
    const newAmountCents = String(lastAmount + 1)

    form.pushFieldValue('nonRecurringThresholds', {
      amountCents: newAmountCents,
      thresholdDisplayName: '',
      recurring: false,
    })
  }, [form, nonRecurringThresholds])

  const handleDeleteThreshold = useCallback(
    (index: number) => {
      if (nonRecurringThresholds.length <= 1) {
        // Keep at least one row, reset it to default
        form.setFieldValue('nonRecurringThresholds', [DEFAULT_PROGRESSIVE_BILLING])
      } else {
        form.removeFieldValue('nonRecurringThresholds', index)
      }
    },
    [form, nonRecurringThresholds],
  )

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    await form.handleSubmit()
  }

  return {
    form,
    // Form values
    progressiveBillingDisabled,
    nonRecurringThresholds,
    hasRecurring,
    recurringThreshold,
    isDirty,
    // Handlers
    handleAddThreshold,
    handleDeleteThreshold,
    handleSubmit,
  }
}
