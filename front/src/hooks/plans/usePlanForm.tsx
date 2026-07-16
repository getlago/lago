import { gql } from '@apollo/client'
import { useStore } from '@tanstack/react-form'
import { useEffect, useMemo } from 'react'
import { generatePath, useParams, useSearchParams } from 'react-router-dom'

import {
  LocalPricingUnitType,
  LocalUsageChargeInput,
  PlanFormInput,
} from '~/components/plans/types'
import { transformFilterObjectToString } from '~/components/plans/utils'
import { REDIRECTION_ORIGIN_SUBSCRIPTION_USAGE } from '~/components/subscriptions/SubscriptionUsageLifetimeGraph'
import { addToast, hasDefinedGQLError } from '~/core/apolloClient'
import {
  PLAN_FORM_TYPE,
  resetDuplicatePlanVar,
  useDuplicatePlanVar,
} from '~/core/apolloClient/reactiveVars/duplicatePlanVar'
import { FORM_ERRORS_ENUM, FORM_TYPE_ENUM } from '~/core/constants/form'
import {
  CustomerSubscriptionDetailsTabsOptionsEnum,
  PlanDetailsTabsOptionsEnum,
} from '~/core/constants/tabsOptions'
import {
  CUSTOMER_SUBSCRIPTION_DETAILS_ROUTE,
  ERROR_404_ROUTE,
  PLAN_DETAILS_ROUTE,
  PLAN_SUBSCRIPTION_DETAILS_ROUTE,
  useNavigate,
} from '~/core/router'
import { serializePlanInput } from '~/core/serializers'
import getPropertyShape from '~/core/serializers/getPropertyShape'
import { deserializeAmount } from '~/core/serializers/serializeAmount'
import { scrollToTop } from '~/core/utils/domUtils'
import {
  CurrencyEnum,
  DeletePlanDialogFragmentDoc,
  EditPlanFragment,
  EditPlanFragmentDoc,
  LagoApiError,
  PlanDetailsV2FragmentDoc,
  PlanItemFragmentDoc,
  useCreatePlanMutation,
} from '~/generated/graphql'
import { useCustomPricingUnits } from '~/hooks/plans/useCustomPricingUnits'
import { usePlanFormSetup } from '~/hooks/plans/usePlanFormSetup'
import { usePlanUpdate } from '~/hooks/plans/usePlanUpdate'
import { buildPlanSettingsValues } from '~/hooks/plans/utils'
import { useOrganizationInfos } from '~/hooks/useOrganizationInfos'

gql`
  query getSinglePlan($id: ID!) {
    plan(id: $id) {
      ...EditPlan
    }
  }

  mutation createPlan($input: CreatePlanInput!) {
    createPlan(input: $input) {
      id
    }
  }

  mutation updatePlan($input: UpdatePlanInput!) {
    updatePlan(input: $input) {
      ...PlanItem
      ...DeletePlanDialog
      ...EditPlan
      ...PlanDetailsV2
    }
  }

  ${PlanItemFragmentDoc}
  ${DeletePlanDialogFragmentDoc}
  ${EditPlanFragmentDoc}
  ${PlanDetailsV2FragmentDoc}
`

export type PlanFormType = ReturnType<typeof usePlanForm>['form']

export const buildDefaultValues = (
  plan: EditPlanFragment | undefined | null,
  type: PLAN_FORM_TYPE,
  initialCurrency: CurrencyEnum,
  hasAnyPricingUnitConfigured: boolean,
): PlanFormInput => {
  const settingsDefaults = buildPlanSettingsValues(plan ?? {})

  return {
    ...settingsDefaults,
    name: type === FORM_TYPE_ENUM.duplicate ? '' : settingsDefaults.name,
    code: type === FORM_TYPE_ENUM.duplicate ? '' : settingsDefaults.code,
    amountCurrency: initialCurrency,
    entitlements:
      plan?.entitlements?.map(({ code, privileges, name, ...restEntitlement }) => ({
        featureName: name || '',
        featureCode: code,
        privileges: privileges.map(
          ({ code: privilegeCode, name: privilegeName, value, ...restPrivilege }) => ({
            privilegeCode,
            privilegeName,
            value: value || '',
            ...restPrivilege,
          }),
        ),
        ...restEntitlement,
      })) || [],
    invoiceDisplayName: plan?.invoiceDisplayName || undefined,
    payInAdvance: plan?.payInAdvance || false,
    amountCents: isNaN(plan?.amountCents)
      ? '0'
      : String(deserializeAmount(plan?.amountCents || 0, initialCurrency)),
    trialPeriod: plan?.trialPeriod ?? 0,
    minimumCommitment: !!plan?.minimumCommitment
      ? {
          ...plan?.minimumCommitment,
          amountCents: String(
            deserializeAmount(plan?.minimumCommitment.amountCents || 0, initialCurrency),
          ),
        }
      : {},
    nonRecurringUsageThresholds:
      plan?.usageThresholds && plan?.usageThresholds.length > 0
        ? plan?.usageThresholds
            .filter(({ recurring }) => !recurring)
            .map((threshold) => ({
              ...threshold,
              amountCents: deserializeAmount(threshold.amountCents || 0, initialCurrency),
            }))
            .sort((a, b) => a.amountCents - b.amountCents)
        : undefined,
    recurringUsageThreshold: plan?.usageThresholds
      ?.map((threshold) => ({
        ...threshold,
        amountCents: deserializeAmount(threshold.amountCents || 0, initialCurrency),
      }))
      .find(({ recurring }) => !!recurring),
    fixedCharges: plan?.fixedCharges || [],
    charges: plan?.charges
      ? (plan?.charges.map(
          ({
            taxes,
            properties,
            minAmountCents,
            payInAdvance,
            invoiceDisplayName,
            filters,
            appliedPricingUnit,
            ...charge
          }) => {
            return {
              appliedPricingUnit:
                !hasAnyPricingUnitConfigured && !appliedPricingUnit
                  ? undefined
                  : {
                      code: appliedPricingUnit?.pricingUnit?.code || initialCurrency,
                      conversionRate: String(appliedPricingUnit?.conversionRate || ''),
                      shortName: appliedPricingUnit?.pricingUnit?.shortName || initialCurrency,
                      type: !!appliedPricingUnit?.pricingUnit?.code
                        ? LocalPricingUnitType.Custom
                        : LocalPricingUnitType.Fiat,
                    },
              invoiceDisplayName: invoiceDisplayName || '',
              taxes: taxes || [],
              minAmountCents:
                isNaN(minAmountCents) || minAmountCents === '0'
                  ? undefined
                  : String(
                      deserializeAmount(
                        minAmountCents || 0,
                        plan.amountCurrency || CurrencyEnum.Usd,
                      ),
                    ),
              payInAdvance: payInAdvance || false,
              properties: properties ? getPropertyShape(properties) : undefined,
              regroupPaidFees: charge.regroupPaidFees || null,
              filters: (filters || []).map((filter) => {
                const values = Object.entries(filter.values || {}).reduce<string[]>(
                  (acc, [key, objectValues]) => {
                    ;(objectValues as string[]).map((v) => {
                      acc.push(transformFilterObjectToString(key, v))
                    })

                    return acc
                  },
                  [],
                )

                return {
                  ...filter,
                  properties: getPropertyShape(filter.properties),
                  values,
                }
              }),
              ...charge,
            }
          },
        ) as LocalUsageChargeInput[])
      : ([] as LocalUsageChargeInput[]),
    cascadeUpdates: undefined,
  }
}

export const usePlanForm = ({
  planIdToFetch,
  isUsedInSubscriptionForm,
}: {
  planIdToFetch?: string
  isUsedInSubscriptionForm?: boolean
}) => {
  const navigate = useNavigate()
  const { organization } = useOrganizationInfos()
  const [searchParams] = useSearchParams()
  const { planId: id = '' } = useParams()
  const { hasAnyPricingUnitConfigured } = useCustomPricingUnits()
  const { parentId, type: actionType } = useDuplicatePlanVar()

  const isDuplicate = actionType === 'duplicate' && !!parentId
  const type = useMemo(() => {
    if (!!id) return FORM_TYPE_ENUM.edition
    if (isDuplicate) return FORM_TYPE_ENUM.duplicate
    return FORM_TYPE_ENUM.creation
  }, [id, isDuplicate])

  const isEdition = type === FORM_TYPE_ENUM.edition

  const initialCurrency =
    type === FORM_TYPE_ENUM.creation && !isUsedInSubscriptionForm
      ? organization?.defaultCurrency || CurrencyEnum.Usd
      : undefined // let usePlanFormSetup derive from plan data

  // --- Mutations (CRUD layer) ---

  const [create, { error: createError }] = useCreatePlanMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted({ createPlan }) {
      if (!!createPlan) {
        if (type === FORM_TYPE_ENUM.duplicate) {
          addToast({
            severity: 'success',
            translateKey: 'text_64fa176933e3b8008e3f15eb',
          })
        } else {
          addToast({
            severity: 'success',
            translateKey: 'text_633336532bdf72cb62dc0694',
          })
        }

        navigate(
          generatePath(PLAN_DETAILS_ROUTE, {
            planId: createPlan.id,
            tab: PlanDetailsTabsOptionsEnum.overview,
          }),
        )
      }
    },
  })
  const { update, error: updateError } = usePlanUpdate({
    onSuccess(updatePlan) {
      const origin = searchParams.get('origin')
      const originSubscriptionId = searchParams.get('subscriptionId')
      const originCustomerId = searchParams.get('customerId')

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
        updatePlan?.id
      ) {
        navigate(
          generatePath(PLAN_SUBSCRIPTION_DETAILS_ROUTE, {
            planId: updatePlan?.id,
            subscriptionId: originSubscriptionId,
            tab: CustomerSubscriptionDetailsTabsOptionsEnum.usage,
          }),
        )
      } else {
        navigate(
          generatePath(PLAN_DETAILS_ROUTE, {
            planId: updatePlan.id,
            tab: PlanDetailsTabsOptionsEnum.overview,
          }),
        )
      }
    },
  })

  // --- Delegate form setup to usePlanFormSetup ---

  const { form, plan, loading, error } = usePlanFormSetup({
    planIdToFetch: id || (parentId as string) || planIdToFetch,
    initialCurrency,
    formType: type,
    hasAnyPricingUnitConfigured,
    onSubmit: (value) => {
      const serializedInput = serializePlanInput(value)

      if (type === FORM_TYPE_ENUM.edition) {
        return update({
          variables: {
            input: { ...serializedInput, id },
          },
        })
      }

      return create({
        variables: {
          input: serializedInput,
        },
      })
    },
  })

  // --- CRUD-specific effects (Router-dependent) ---

  const errorCode = useMemo(() => {
    if (hasDefinedGQLError('ValueAlreadyExist', createError || updateError)) {
      return FORM_ERRORS_ENUM.existingCode
    }

    return undefined
  }, [createError, updateError])

  // Clear duplicate plan var when leaving the page
  useEffect(() => {
    return () => {
      if (type === FORM_TYPE_ENUM.duplicate) {
        resetDuplicatePlanVar()
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    if (hasDefinedGQLError('NotFound', error, 'plan')) {
      navigate(ERROR_404_ROUTE)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [error])

  // Propagate server-side code error to TanStack form
  useEffect(() => {
    if (errorCode === FORM_ERRORS_ENUM.existingCode) {
      form.setFieldMeta('code', (meta) => ({
        ...meta,
        errorMap: {
          ...meta.errorMap,
          onDynamic: { message: 'text_632a2d437e341dcc76817556' },
        },
      }))
      scrollToTop('[data-centered-page-wrapper]')
    }
  }, [errorCode, form])

  // Clear code error when the code field value changes
  const codeValue = useStore(form.store, (s) => s.values.code)

  useEffect(() => {
    if (errorCode === FORM_ERRORS_ENUM.existingCode) {
      form.setFieldMeta('code', (meta) => ({
        ...meta,
        errorMap: { ...meta.errorMap, onDynamic: undefined },
      }))
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [codeValue])

  return useMemo(
    () => ({
      form,
      isEdition,
      loading,
      type,
      plan,
    }),
    [form, isEdition, loading, type, plan],
  )
}
