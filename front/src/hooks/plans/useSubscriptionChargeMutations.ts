import { gql } from '@apollo/client'

import { LocalPricingUnitType, LocalUsageChargeInput } from '~/components/plans/types'
import { addToast } from '~/core/apolloClient'
import { serializeAmount } from '~/core/serializers/serializeAmount'
import { serializeFilters, serializeProperties } from '~/core/serializers/serializePlanInput'
import {
  CurrencyEnum,
  UpdateSubscriptionChargeInput,
  UsageChargeForDetailsV2FragmentDoc,
  useUpdateSubscriptionChargeMutation,
} from '~/generated/graphql'

gql`
  mutation updateSubscriptionCharge($input: UpdateSubscriptionChargeInput!) {
    updateSubscriptionCharge(input: $input) {
      ...UsageChargeForDetailsV2
    }
  }

  ${UsageChargeForDetailsV2FragmentDoc}
`

type Args = {
  subscriptionId: string
  currency: CurrencyEnum
}

const serializeAppliedPricingUnit = (
  appliedPricingUnit: LocalUsageChargeInput['appliedPricingUnit'],
) =>
  !appliedPricingUnit || appliedPricingUnit.type === LocalPricingUnitType.Fiat
    ? undefined
    : { conversionRate: Number(appliedPricingUnit.conversionRate) }

export const useSubscriptionChargeMutations = ({ subscriptionId, currency }: Args) => {
  const [updateSubscriptionCharge] = useUpdateSubscriptionChargeMutation({
    // First override-creating edit changes plan + charge ids; refetch the tab
    // query by operation name (the query is created in a later task; refetch by
    // name avoids importing its Document).
    refetchQueries: ['getSubscriptionForDetailsV2Plan'],
    awaitRefetchQueries: true,
    onCompleted(data) {
      if (data?.updateSubscriptionCharge?.id) {
        addToast({ severity: 'success', translateKey: 'text_1779736085470h5bm2lrvwsp' })
      }
    },
  })

  const buildInput = (charge: LocalUsageChargeInput): UpdateSubscriptionChargeInput => ({
    subscriptionId,
    chargeCode: charge.code ?? '',
    appliedPricingUnit: serializeAppliedPricingUnit(charge.appliedPricingUnit),
    invoiceDisplayName: charge.invoiceDisplayName || undefined,
    minAmountCents:
      !!charge.minAmountCents && !charge.payInAdvance
        ? Number(serializeAmount(charge.minAmountCents, currency) || 0)
        : undefined,
    taxCodes: charge.taxes?.map((t) => t.code) ?? [],
    properties: charge.properties
      ? serializeProperties(charge.properties, charge.chargeModel)
      : undefined,
    filters: serializeFilters(charge.filters, charge.chargeModel),
  })

  // Sub tab edits only (no create/delete), so the shared handler's index arg is
  // unused here - a narrower-arity fn stays assignable to UsageChargeMutations.
  const handleSaveCharge = async (charge: LocalUsageChargeInput): Promise<boolean> => {
    // Report success only when the mutation actually returned a charge. On error
    // (e.g. a 500, surfaced as a resolved result with `data: null` by the error
    // link) return false so the drawer stays open and the user can re-submit.
    const { data } = await updateSubscriptionCharge({ variables: { input: buildInput(charge) } })

    return !!data?.updateSubscriptionCharge?.id
  }

  // Delete is hidden on the sub tab; no-op to satisfy the shared handler shape.
  const handleDeleteCharge = async (): Promise<boolean> => false

  return { handleSaveCharge, handleDeleteCharge }
}
