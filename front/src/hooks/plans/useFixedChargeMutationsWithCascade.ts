import { gql } from '@apollo/client'
import { GraphQLFormattedError } from 'graphql'

import { useCascadeFormDialog } from '~/components/plans/details-v2/shared/useCascadeFormDialog'
import { LocalFixedChargeInput } from '~/components/plans/types'
import { addToast } from '~/core/apolloClient'
import { cacheArrayInsert, cacheArrayRemove } from '~/core/apolloClient/cacheHelpers'
import { FORM_ERRORS_ENUM } from '~/core/constants/form'
import { serializeFixedChargeProperties } from '~/core/serializers/serializePlanInput'
import {
  FixedChargeCreateInput,
  FixedChargeForDetailsV2FragmentDoc,
  FixedChargeUpdateInput,
  LagoApiError,
  useCreateFixedChargeMutation,
  useDestroyFixedChargeMutation,
  useUpdateFixedChargeMutation,
} from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'

import { buildChargeSaveResult } from './buildChargeSaveResult'

gql`
  mutation createFixedCharge($input: FixedChargeCreateInput!) {
    createFixedCharge(input: $input) {
      ...FixedChargeForDetailsV2
    }
  }

  mutation updateFixedCharge($input: FixedChargeUpdateInput!) {
    updateFixedCharge(input: $input) {
      ...FixedChargeForDetailsV2
    }
  }

  mutation destroyFixedCharge($input: DestroyFixedChargeInput!) {
    destroyFixedCharge(input: $input) {
      id
    }
  }

  ${FixedChargeForDetailsV2FragmentDoc}
`

type Args = {
  planId: string
  hasOverriddenPlans: boolean
}

export const useFixedChargeMutationsWithCascade = ({ planId, hasOverriddenPlans }: Args) => {
  const { translate } = useInternationalization()
  const { openCascadeDialog } = useCascadeFormDialog()

  const [createFixedCharge] = useCreateFixedChargeMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    update(cache, { data }) {
      const created = data?.createFixedCharge

      if (!created) return
      cacheArrayInsert(cache, { __typename: 'Plan', id: planId }, 'fixedCharges', created)
    },
    onCompleted(data) {
      if (data?.createFixedCharge?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_17794779557685zdm1q8ll85',
        })
      }
    },
  })

  const [updateFixedCharge] = useUpdateFixedChargeMutation({
    context: { silentErrorCodes: [LagoApiError.UnprocessableEntity] },
    onCompleted(data) {
      if (data?.updateFixedCharge?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_1779477955768pjf35u2m3ac',
        })
      }
    },
  })

  const [destroyFixedCharge] = useDestroyFixedChargeMutation({
    update(cache, { data }) {
      const id = data?.destroyFixedCharge?.id

      if (!id) return
      cacheArrayRemove(cache, { __typename: 'Plan', id: planId }, 'fixedCharges', id, 'FixedCharge')
    },
    onCompleted(data) {
      if (data?.destroyFixedCharge?.id) {
        addToast({
          severity: 'success',
          translateKey: 'text_1779477955768h3bx1xogeeu',
        })
      }
    },
  })

  const buildCreateInput = (
    charge: LocalFixedChargeInput,
    cascadeUpdates: boolean,
  ): FixedChargeCreateInput => ({
    planId,
    addOnId: charge.addOn.id,
    chargeModel: charge.chargeModel,
    code: charge.code || undefined,
    invoiceDisplayName: charge.invoiceDisplayName || undefined,
    payInAdvance: charge.payInAdvance ?? false,
    properties: charge.properties
      ? serializeFixedChargeProperties(charge.properties, charge.chargeModel)
      : undefined,
    prorated: charge.prorated ?? false,
    units: charge.units ? String(charge.units) : '0',
    taxCodes: charge.taxes?.map((t) => t.code) ?? [],
    applyUnitsImmediately: charge.applyUnitsImmediately ?? false,
    cascadeUpdates,
  })

  const buildUpdateInput = (
    charge: LocalFixedChargeInput,
    cascadeUpdates: boolean,
  ): FixedChargeUpdateInput => ({
    id: charge.id ?? '',
    chargeModel: charge.chargeModel,
    code: charge.code || undefined,
    invoiceDisplayName: charge.invoiceDisplayName || undefined,
    payInAdvance: charge.payInAdvance ?? false,
    properties: charge.properties
      ? serializeFixedChargeProperties(charge.properties, charge.chargeModel)
      : undefined,
    prorated: charge.prorated ?? false,
    units: charge.units ? String(charge.units) : '0',
    taxCodes: charge.taxes?.map((t) => t.code) ?? [],
    applyUnitsImmediately: charge.applyUnitsImmediately ?? false,
    cascadeUpdates,
  })

  const handleSaveCharge = async (
    charge: LocalFixedChargeInput,
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
          ? await createFixedCharge({
              variables: { input: buildCreateInput(charge, cascadeUpdates) },
            })
          : await updateFixedCharge({
              variables: { input: buildUpdateInput(charge, cascadeUpdates) },
            })

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
        await destroyFixedCharge({
          variables: { input: { id: chargeId, cascadeUpdates } },
        })
      },
    })
  }

  return { handleSaveCharge, handleDeleteCharge }
}
