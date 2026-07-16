import { gql } from '@apollo/client'
import { GraphQLFormattedError } from 'graphql'

import { useCascadeFormDialog } from '~/components/plans/details-v2/shared/useCascadeFormDialog'
import { LocalPricingUnitType, LocalUsageChargeInput } from '~/components/plans/types'
import { addToast } from '~/core/apolloClient'
import { cacheArrayInsert, cacheArrayRemove } from '~/core/apolloClient/cacheHelpers'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import { serializeFilters, serializeProperties } from '~/core/serializers/serializePlanInput'
import {
  ChargeCreateInput,
  ChargeUpdateInput,
  CurrencyEnum,
  LagoApiError,
  UsageChargeForDetailsV2FragmentDoc,
  useCreateChargeMutation,
  useDestroyChargeMutation,
  useUpdateChargeMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { buildChargeSaveResult } from './buildChargeSaveResult'

gql`
  mutation createCharge($input: ChargeCreateInput!) {
    createCharge(input: $input) {
      ...UsageChargeForDetailsV2
    }
  }

  mutation updateCharge($input: ChargeUpdateInput!) {
    updateCharge(input: $input) {
      ...UsageChargeForDetailsV2
    }
  }

  mutation destroyCharge($input: DestroyChargeInput!) {
    destroyCharge(input: $input) {
      id
    }
  }

  ${UsageChargeForDetailsV2FragmentDoc}
`

type Args = {
  planId: string
  hasOverriddenPlans: boolean
  currency: CurrencyEnum
}

const serializeAppliedPricingUnit = (
  appliedPricingUnit: LocalUsageChargeInput['appliedPricingUnit'],
) =>
  !appliedPricingUnit || appliedPricingUnit.type === LocalPricingUnitType.Fiat
    ? undefined
    : {
        code: appliedPricingUnit.code,
        conversionRate: Number(appliedPricingUnit.conversionRate),
      }

export const useChargeMutationsWithCascade = ({ planId, hasOverriddenPlans, currency }: Args) => {
  const { translate } = useInternationalization()
  const { openCascadeDialog } = useCascadeFormDialog()

  const [createCharge] = useCreateChargeMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    update(cache, { data }) {
      const created = data?.createCharge

      if (!created) return
      cacheArrayInsert(cache, { __typename: 'Plan', id: planId }, 'charges', created)
    },
    onCompleted(data) {
      if (data?.createCharge?.id) {
        addToast({ severity: 'success', translateKey: 'text_1779736085470e2zwa6li5e2' })
      }
    },
  })

  const [updateCharge] = useUpdateChargeMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted(data) {
      if (data?.updateCharge?.id) {
        addToast({ severity: 'success', translateKey: 'text_1779736085470h5bm2lrvwsp' })
      }
    },
  })

  const [destroyCharge] = useDestroyChargeMutation({
    update(cache, { data }) {
      const id = data?.destroyCharge?.id

      if (!id) return
      cacheArrayRemove(cache, { __typename: 'Plan', id: planId }, 'charges', id, 'Charge')
    },
    onCompleted(data) {
      if (data?.destroyCharge?.id) {
        addToast({ severity: 'success', translateKey: 'text_17797360854706p74smyip4m' })
      }
    },
  })

  const buildCreateInput = (
    charge: LocalUsageChargeInput,
    cascadeUpdates: boolean,
  ): ChargeCreateInput => ({
    planId,
    billableMetricId: charge.billableMetric.id,
    chargeModel: charge.chargeModel,
    code: charge.code || undefined,
    appliedPricingUnit: serializeAppliedPricingUnit(charge.appliedPricingUnit),
    invoiceDisplayName: charge.invoiceDisplayName || undefined,
    invoiceable: charge.invoiceable,
    minAmountCents:
      !!charge.minAmountCents && !charge.payInAdvance
        ? Number(serializeAmount(charge.minAmountCents, currency) || 0)
        : undefined,
    payInAdvance: charge.payInAdvance || false,
    prorated: charge.prorated || false,
    regroupPaidFees: charge.regroupPaidFees || undefined,
    taxCodes: charge.taxes?.map((t) => t.code) ?? [],
    properties: charge.properties
      ? serializeProperties(charge.properties, charge.chargeModel)
      : undefined,
    filters: serializeFilters(charge.filters, charge.chargeModel),
    cascadeUpdates,
  })

  const buildUpdateInput = (
    charge: LocalUsageChargeInput,
    cascadeUpdates: boolean,
  ): ChargeUpdateInput => ({
    id: charge.id ?? '',
    chargeModel: charge.chargeModel,
    code: charge.code || undefined,
    appliedPricingUnit: serializeAppliedPricingUnit(charge.appliedPricingUnit),
    invoiceDisplayName: charge.invoiceDisplayName || undefined,
    invoiceable: charge.invoiceable,
    minAmountCents:
      !!charge.minAmountCents && !charge.payInAdvance
        ? Number(serializeAmount(charge.minAmountCents, currency) || 0)
        : undefined,
    payInAdvance: charge.payInAdvance || false,
    prorated: charge.prorated || false,
    regroupPaidFees: charge.regroupPaidFees || undefined,
    taxCodes: charge.taxes?.map((t) => t.code) ?? [],
    properties: charge.properties
      ? serializeProperties(charge.properties, charge.chargeModel)
      : undefined,
    filters: serializeFilters(charge.filters, charge.chargeModel),
    cascadeUpdates,
  })

  const handleSaveCharge = async (
    charge: LocalUsageChargeInput,
    index: number | null,
  ): Promise<boolean | FORM_ERRORS_ENUM.existingCode> => {
    const isCreate = index === null
    let mutationErrors: readonly GraphQLFormattedError[] | undefined

    const confirmed = await openCascadeDialog({
      title: translate('text_1729604107534r3hsj7i64gp'),
      mainActionLabel: translate('text_1729604107534dfyz8j53ho5'),
      hasOverriddenPlans,
      onConfirm: async (cascadeUpdates) => {
        const { errors } = isCreate
          ? await createCharge({ variables: { input: buildCreateInput(charge, cascadeUpdates) } })
          : await updateCharge({ variables: { input: buildUpdateInput(charge, cascadeUpdates) } })

        mutationErrors = errors ?? undefined
      },
    })

    return buildChargeSaveResult(mutationErrors, confirmed)
  }

  const handleDeleteCharge = async (chargeId: string): Promise<boolean> => {
    return openCascadeDialog({
      title: translate('text_1729604107534r3hsj7i64gp'),
      mainActionLabel: translate('text_1729604107534dfyz8j53ho5'),
      hasOverriddenPlans,
      danger: true,
      onConfirm: async (cascadeUpdates) => {
        await destroyCharge({ variables: { input: { id: chargeId, cascadeUpdates } } })
      },
    })
  }

  return { handleSaveCharge, handleDeleteCharge }
}
