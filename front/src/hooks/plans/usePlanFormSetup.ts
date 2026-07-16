import { gql } from '@apollo/client'
import { revalidateLogic, useStore } from '@tanstack/react-form'
import { useEffect, useMemo, useRef } from 'react'

import type { PlanFormInput } from '~/components/plans/types'
import { isPlanIntervalAnnual } from '~/components/plans/utils'
import { type PLAN_FORM_TYPE } from '~/core/apolloClient/reactiveVars/duplicatePlanVar'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import {
  BillingItemPlan,
  fromPlanBillingItems,
} from '~/core/serializers/serializeQuotePlanBillingItems'
import { planFormSchema } from '~/formValidation/planFormSchema'
import {
  CurrencyEnum,
  type EditPlanFragment,
  LagoApiError,
  useGetSinglePlanQuery,
  useGetSubscriptionForQuotePricingQuery,
} from '~/generated/graphql'
import { useAppForm } from '~/hooks/forms/useAppform'

import { buildDefaultValues } from './usePlanForm'

gql`
  query getSubscriptionForQuotePricing($subscriptionId: ID!) {
    subscription(id: $subscriptionId) {
      id
      name
      externalId
      subscriptionAt
      endingAt
      billingTime
      plan {
        id
        parent {
          id
        }
        ...EditPlan
      }
    }
  }
`

/**
 * Lightweight hook that fetches a plan by ID and creates a TanStack form.
 * No Router, no mutations, no navigation — safe to use in drawers and other
 * non-routed contexts.
 *
 * `usePlanForm` calls this internally and layers CRUD on top via `onSubmit`.
 *
 * Three initialization paths:
 *  Case 2: billingItemPlan — form values come from deserialized billing items
 *  Case 3: subscriptionId — fetch subscription's plan (override child plan → parent)
 *  Case 4: planIdToFetch — existing behavior (fetch plan by id directly)
 */
export const usePlanFormSetup = ({
  planIdToFetch,
  initialCurrency,
  formType = FORM_TYPE_ENUM.creation,
  hasAnyPricingUnitConfigured = false,
  onSubmit,
  billingItemPlan,
  subscriptionId,
}: {
  planIdToFetch?: string
  initialCurrency?: CurrencyEnum
  formType?: PLAN_FORM_TYPE
  hasAnyPricingUnitConfigured?: boolean
  onSubmit?: (value: PlanFormInput) => void
  billingItemPlan?: BillingItemPlan
  subscriptionId?: string
}) => {
  // Case 2: billing item deserialization
  const billingItemData = useMemo(
    () => (billingItemPlan ? fromPlanBillingItems([billingItemPlan]) : null),
    [billingItemPlan],
  )

  // Case 3: subscription query
  const { data: subscriptionData } = useGetSubscriptionForQuotePricingQuery({
    variables: { subscriptionId: subscriptionId as string },
    skip: !subscriptionId || !!billingItemPlan,
  })
  const subscription = subscriptionData?.subscription
  const subscriptionPlan = subscription?.plan
  // If the subscription has overrides, plan.parent is the original plan.
  // If no overrides, plan IS the original — use its own ID.
  const parentPlanId = subscriptionPlan?.parent?.id ?? subscriptionPlan?.id

  // Extract subscription settings from case 3 subscription query
  const subscriptionQuerySettings = subscription
    ? {
        externalId: subscription.externalId ?? '',
        subscriptionName: subscription.name ?? '',
        billingTime: (subscription.billingTime ?? 'anniversary') as 'anniversary' | 'calendar',
        startDate: subscription.subscriptionAt ?? '',
        endDate: subscription.endingAt ?? '',
      }
    : undefined

  // Resolve which plan ID to fetch (case 4 / case 3 fallback)
  const resolvedPlanId = billingItemPlan?.id ?? parentPlanId ?? planIdToFetch

  // Cases 2 & 3 don't need a separate plan query
  const skipPlanQuery = !!billingItemPlan || !!subscriptionPlan
  const {
    data,
    loading: planLoading,
    error,
  } = useGetSinglePlanQuery({
    context: { silentError: LagoApiError.NotFound },
    variables: { id: resolvedPlanId as string },
    skip: !resolvedPlanId || skipPlanQuery,
  })

  const plan = skipPlanQuery ? undefined : data?.plan
  const effectivePlan = plan ?? (subscriptionPlan as EditPlanFragment | undefined)
  const currency =
    initialCurrency || (effectivePlan?.amountCurrency as CurrencyEnum) || CurrencyEnum.Usd

  const form = useAppForm({
    defaultValues:
      billingItemData?.formValues ??
      buildDefaultValues(effectivePlan, formType, currency, hasAnyPricingUnitConfigured),
    validationLogic: revalidateLogic(),
    validators: {
      onDynamic: planFormSchema,
    },
    onSubmit: onSubmit ? ({ value }) => onSubmit(value) : undefined,
  })

  // Re-initialize form when plan data or billing item data loads
  const prevPlanRef = useRef(effectivePlan)
  const prevBillingItemRef = useRef(billingItemData)

  useEffect(() => {
    if (billingItemData?.formValues && billingItemData !== prevBillingItemRef.current) {
      form.reset(billingItemData.formValues, { keepDefaultValues: false })
      prevBillingItemRef.current = billingItemData
      return
    }
    if (effectivePlan && effectivePlan !== prevPlanRef.current) {
      form.reset(
        buildDefaultValues(effectivePlan, formType, currency, hasAnyPricingUnitConfigured),
        { keepDefaultValues: false },
      )
      prevPlanRef.current = effectivePlan
    }
  }, [effectivePlan, billingItemData, formType, currency, hasAnyPricingUnitConfigured, form])

  // Auto-reset billChargesMonthly when conditions aren't met
  const charges = useStore(form.store, (s) => s.values.charges)
  const billChargesMonthly = useStore(form.store, (s) => s.values.billChargesMonthly)
  const interval = useStore(form.store, (s) => s.values.interval)
  const isAnnual = isPlanIntervalAnnual(interval)

  useEffect(() => {
    if ((!charges?.length || !isAnnual) && !!billChargesMonthly) {
      form.setFieldValue('billChargesMonthly', false)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [charges, billChargesMonthly, interval])

  const loading = planLoading || (!!subscriptionId && !subscriptionData && !billingItemPlan)

  // Form is ready when we have data from any source
  const formReady = !!billingItemData?.formValues || !!effectivePlan

  return {
    form,
    plan: effectivePlan as EditPlanFragment | undefined,
    formReady,
    loading,
    error,
    resolvedPlanId,
    subscriptionSettings: billingItemData?.subscriptionSettings ?? subscriptionQuerySettings,
    invoicingSettings: billingItemData?.invoicingSettings,
  }
}
