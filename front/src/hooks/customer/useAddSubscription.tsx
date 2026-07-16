import { gql } from '@apollo/client'
import { DateTime } from 'luxon'
import { useMemo } from 'react'
import { generatePath, useSearchParams } from 'react-router-dom'

import { PlanFormInput } from '~/components/plans/types'
import { REDIRECTION_ORIGIN_SUBSCRIPTION_USAGE } from '~/components/subscriptions/SubscriptionUsageLifetimeGraph'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import { FORM_TYPE_ENUM } from '~/core/constants/form'
import { CustomerSubscriptionDetailsTabsOptionsEnum } from '~/core/constants/tabsOptions'
import {
  CUSTOMER_DETAILS_ROUTE,
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  useLocation,
  useNavigate,
} from '~/core/router'
import { serializePlanInput } from '~/core/serializers'
import {
  BillingTimeEnum,
  CreateSubscriptionInput,
  CustomerDetailsFragmentDoc,
  GetSubscriptionForCreateSubscriptionQuery,
  LagoApiError,
  PlanOverridesInput,
  useCreateSubscriptionMutation,
  useUpdateSubscriptionMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useIframeConfig } from '~/hooks/useIframeConfig'

gql`
  mutation createSubscription($input: CreateSubscriptionInput!) {
    createSubscription(input: $input) {
      id
      status
      cancellationReason
      startedAt
      subscriptionAt
      endingAt
      name
      externalId
      activationRules {
        id
        type
        timeoutHours
        status
        expiresAt
      }
      paymentMethodType
      paymentMethod {
        id
      }
      consolidateInvoice
      skipInvoiceCustomSections
      selectedInvoiceCustomSections {
        id
        name
      }
      customer {
        id
        activeSubscriptionsCount
        ...CustomerDetails
      }
      plan {
        id
        name
        code
        interval
      }
    }
  }

  mutation updateSubscription($input: UpdateSubscriptionInput!) {
    updateSubscription(input: $input) {
      id
      status
      cancellationReason
      startedAt
      subscriptionAt
      endingAt
      name
      externalId
      activationRules {
        id
        type
        timeoutHours
        status
        expiresAt
      }
      paymentMethodType
      paymentMethod {
        id
      }
      consolidateInvoice
      skipInvoiceCustomSections
      selectedInvoiceCustomSections {
        id
        name
      }
      customer {
        id
        activeSubscriptionsCount
        ...CustomerDetails
      }
      plan {
        id
        name
        code
        interval
      }
    }
  }

  ${CustomerDetailsFragmentDoc}
`

type UseAddSubscriptionReturn = {
  billingTimeHelper?: string
  errorCode?: LagoApiError
  formType: keyof typeof FORM_TYPE_ENUM
  onSave: (
    customerId: string,
    values: Omit<CreateSubscriptionInput, 'customerId'>,
    planValues: PlanFormInput,
    hasPlanBeingChangedFromInitial: boolean,
    // The plan's baseline (unedited) values, used to send only the fields the
    // user actually changed. See buildPlanOverridesInput.
    planBaselineValues?: PlanFormInput | null,
  ) => Promise<string | undefined>
}

type UseAddSubscription = (args: {
  existingSubscription?: GetSubscriptionForCreateSubscriptionQuery['subscription']
  billingTime?: BillingTimeEnum
  subscriptionAt?: string
}) => UseAddSubscriptionReturn

// Recursively drops __typename and sorts object keys so two values produced by
// the same serialization compare equal regardless of key order / __typename.
const sortedWithoutTypename = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(sortedWithoutTypename)

  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([key]) => key !== '__typename')
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, entry]) => [key, sortedWithoutTypename(entry)]),
    )
  }

  return value
}

const comparable = (value: unknown): string => JSON.stringify(sortedWithoutTypename(value))

// The override-meaningful content of a (serialized + cleaned) fixed charge,
// excluding `units` (compared separately) and identity fields. The edit drawer
// writes the whole charge back and augments it with normalization-only fields
// (e.g. `applyUnitsImmediately`) that the untouched baseline charge lacks, so we
// compare an explicit whitelist instead of the whole object to avoid reading
// that noise as a real change.
const comparableChargeContent = (charge: {
  invoiceDisplayName?: string | null
  properties?: unknown
  taxCodes?: Array<string> | null
}): string =>
  comparable({
    invoiceDisplayName: charge.invoiceDisplayName || '',
    properties: charge.properties ?? null,
    taxCodes: [...(charge.taxCodes ?? [])].sort((a, b) => a.localeCompare(b)),
  })

// Clean plan values (non editable fields not accepted by BE / Graph fails if they are sent)
export const cleanPlanValues = (planValues: PlanOverridesInput) => {
  return {
    ...planValues,
    code: undefined,
    interval: undefined,
    taxes: undefined,
    payInAdvance: undefined,
    billChargesMonthly: undefined,
    billFixedChargesMonthly: undefined,
    cascadeUpdates: undefined,
    entitlements: undefined,
    usageThresholds: undefined,
    charges: planValues?.charges?.map((charge) => ({
      ...charge,
      appliedPricingUnit: charge.appliedPricingUnit
        ? {
            conversionRate: Number(charge.appliedPricingUnit.conversionRate),
          }
        : undefined,
      taxes: undefined,
      payInAdvance: undefined,
      billableMetric: undefined,
      chargeModel: undefined,
      invoiceable: undefined,
      prorated: undefined,
      regroupPaidFees: undefined,
    })),
    fixedCharges: planValues?.fixedCharges?.map((fixedCharge) => ({
      ...fixedCharge,
      chargeModel: undefined,
      payInAdvance: undefined,
      prorated: undefined,
    })),
  }
}

// Builds the `planOverrides` payload from the edited plan values, diffed against
// the original plan (the form's baseline values).
//
// When the only difference is fixed-charge units, returns a minimal
// `{ fixedCharges: [{ id, units }] }` so the BE takes its per-subscription
// units-override fast path instead of cloning the whole plan. Any other change
// (a plan-level field, or a non-units field on a fixed charge) sends the full
// cleaned payload, the existing behaviour.
//
// Fixed charges cannot be added or removed from the subscription form, so they
// always match the baseline 1:1 by id.
export const buildPlanOverridesInput = (
  currentValues: PlanFormInput,
  baselineValues?: PlanFormInput | null,
): PlanOverridesInput => {
  const current = cleanPlanValues(serializePlanInput(currentValues) as PlanOverridesInput)

  // No baseline to diff against (plan still loading) → send the full payload.
  if (!baselineValues) return current

  const baseline = cleanPlanValues(serializePlanInput(baselineValues) as PlanOverridesInput)

  const { fixedCharges: currentFixedCharges, ...currentRest } = current
  const { fixedCharges: baselineFixedCharges, ...baselineRest } = baseline

  // Any plan-level (non fixed-charge) field changed → full payload.
  if (comparable(currentRest) !== comparable(baselineRest)) {
    return current
  }

  const changedUnits: Array<{ id: string; units: string }> = []

  for (const charge of currentFixedCharges ?? []) {
    const original = baselineFixedCharges?.find((fixedCharge) => fixedCharge.id === charge.id)

    // No baseline match → can't prove it's units-only, send the full payload.
    if (!original) return current

    // A non-units content field changed on this charge → full payload.
    if (comparableChargeContent(charge) !== comparableChargeContent(original)) {
      return current
    }

    if (String(charge.units ?? '') !== String(original.units ?? '')) {
      changedUnits.push({ id: charge.id as string, units: String(charge.units ?? '') })
    }
  }

  // Nothing units-related changed → keep the full payload behaviour.
  if (changedUnits.length === 0) return current

  return { fixedCharges: changedUnits }
}

export const useAddSubscription: UseAddSubscription = ({
  existingSubscription,
}): UseAddSubscriptionReturn => {
  const location = useLocation()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const { translate } = useInternationalization()
  const {
    emitIframeMessage,
    emitSalesForceEvent,
    isRunningInIframeContext,
    isRunningInSalesForceIframe,
  } = useIframeConfig()

  const formType = useMemo(() => {
    if (location.pathname.includes('/update/subscription/')) return FORM_TYPE_ENUM.edition
    if (location.pathname.includes('/upgrade-downgrade/subscription/'))
      return FORM_TYPE_ENUM.upgradeDowngrade

    return FORM_TYPE_ENUM.creation
  }, [location.pathname])

  const [create] = useCreateSubscriptionMutation({
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
    onCompleted: async (res) => {
      if (!!res?.createSubscription) {
        addToast({
          message: translate('text_65118a52df984447c186962f'),
          severity: 'success',
        })

        if (isRunningInSalesForceIframe) {
          emitSalesForceEvent({
            action: 'close',
            rel: 'create-subscription',
            subscriptionId: res?.createSubscription.id,
          })
        } else if (isRunningInIframeContext) {
          emitIframeMessage({
            action: 'DONE',
            rel: 'create-subscription',
            subscriptionId: res?.createSubscription.id,
          })
        } else {
          navigate(
            generatePath(CUSTOMER_DETAILS_ROUTE, {
              customerId: res.createSubscription.customer.id as string,
            }),
          )
        }
      }
    },
  })
  const [update] = useUpdateSubscriptionMutation({
    context: {
      silentErrorCodes: [LagoApiError.UnprocessableEntity],
    },
    onCompleted: async (res) => {
      if (!!res?.updateSubscription) {
        const origin = searchParams.get('origin')
        const originSubscriptionId = searchParams.get('subscriptionId')
        const originCustomerId = searchParams.get('customerId')

        addToast({
          message: translate(
            formType === FORM_TYPE_ENUM.upgradeDowngrade
              ? 'text_65118a52df984447c18695f9'
              : 'text_65118a52df984447c186962e',
          ),
          severity: 'success',
        })

        if (
          origin === REDIRECTION_ORIGIN_SUBSCRIPTION_USAGE &&
          originSubscriptionId &&
          !!originCustomerId
        ) {
          navigate(
            generatePath(CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE, {
              customerId: originCustomerId,
              subscriptionId: originSubscriptionId,
              tab: CustomerSubscriptionDetailsTabsOptionsEnum.usage,
            }),
          )
        } else if (
          origin === REDIRECTION_ORIGIN_SUBSCRIPTION_USAGE &&
          !!originSubscriptionId &&
          res?.updateSubscription?.plan?.id
        ) {
          navigate(
            generatePath(PLAN_SUBSCRIPTION_DETAILS_ROUTE, {
              planId: res?.updateSubscription?.plan?.id,
              subscriptionId: originSubscriptionId,
              tab: CustomerSubscriptionDetailsTabsOptionsEnum.usage,
            }),
          )
        } else {
          navigate(
            generatePath(CUSTOMER_DETAILS_ROUTE, {
              customerId: res?.updateSubscription?.customer.id as string,
            }),
          )
        }
      }
    },
  })

  return {
    formType,
    onSave: async (
      customerId,
      {
        subscriptionAt: subsDate,
        name,
        externalId,
        endingAt: subEndDate,
        planId,
        billingTime,
        paymentMethod,
        billingEntityId,
        ...values
      },
      { ...planValues },
      hasPlanBeingChangedFromInitial,
      planBaselineValues,
    ) => {
      const planOverrides = hasPlanBeingChangedFromInitial
        ? buildPlanOverridesInput(planValues, planBaselineValues)
        : undefined

      const parsedPaymentMethod = paymentMethod
        ? {
            paymentMethodId: paymentMethod?.paymentMethodId,
            paymentMethodType: paymentMethod?.paymentMethodType,
          }
        : undefined

      const subscriptionAtForUpdate = DateTime.fromISO(
        existingSubscription?.startedAt || subsDate || '',
      )
        .toUTC()
        .toISO()

      const { errors } =
        formType === FORM_TYPE_ENUM.creation || formType === FORM_TYPE_ENUM.upgradeDowngrade
          ? await create({
              variables: {
                input: {
                  customerId,
                  planId,
                  billingTime,
                  // `null` (not `undefined`) on clear → BE stores NULL on the
                  // subscription column, meaning "inherit from customer".
                  billingEntityId: billingEntityId || null,
                  ...(!existingSubscription
                    ? {
                        subscriptionAt: DateTime.fromISO(subsDate).toUTC().toISO(),
                        endingAt: !!subEndDate
                          ? DateTime.fromISO(subEndDate).toUTC().toISO()
                          : undefined,
                      } // Format to UTC only if it's a new creation (no upgrade, downgrade, edit)
                    : {
                        subscriptionId: existingSubscription.id,
                        subscriptionAt: !!existingSubscription.startedAt
                          ? DateTime.fromISO(existingSubscription.startedAt).toUTC().toISO()
                          : undefined,
                        endingAt: !!subEndDate
                          ? DateTime.fromISO(subEndDate).toUTC().toISO()
                          : null,
                      }),
                  name: name || undefined,
                  externalId: externalId || undefined,
                  paymentMethod: parsedPaymentMethod,
                  ...values,
                  planOverrides,
                },
              },
            })
          : await update({
              variables: {
                input: {
                  ...values,
                  id: existingSubscription?.id as string,
                  subscriptionAt: subscriptionAtForUpdate,
                  endingAt: !!subEndDate ? DateTime.fromISO(subEndDate).toUTC().toISO() : null,
                  name: name ?? undefined,
                  // `null` (not `undefined`) on clear → BE stores NULL on the
                  // subscription column, meaning "inherit from customer".
                  billingEntityId: billingEntityId || null,
                  paymentMethod: parsedPaymentMethod,
                  planOverrides,
                },
              },
            })

      if (hasDefinedGQLError('CurrenciesDoesNotMatch', errors)) {
        return 'CurrenciesDoesNotMatch'
      } else if (hasDefinedGQLError('ValueAlreadyExist', errors)) {
        return 'ValueAlreadyExist'
      }

      return
    },
  }
}
