import { gql, useApolloClient } from '@apollo/client'

import { LocalFixedChargeInput } from '~/components/plans/types'
import { addToast } from '~/core/apolloClient'
import { serializeFixedChargeProperties } from '~/core/serializers/serializePlanInput'
import {
  FixedChargeForDetailsV2Fragment,
  UpdateSubscriptionFixedChargeInput,
  useUpdateSubscriptionFixedChargeMutation,
} from '~/generated/graphql'

// Intentionally select only `id` on the mutation result. FixedCharge is
// normalised by id in the Apollo cache, and the mutation returns the
// subscription-scoped (override-aware) units. Writing that back would
// overwrite the plan-default units that plan-scope pages read from the same
// cache entry. Override-aware reads use the dedicated
// getSubscriptionFixedChargeUnitsOverrides query (fetchPolicy: 'no-cache').
gql`
  mutation updateSubscriptionFixedCharge($input: UpdateSubscriptionFixedChargeInput!) {
    updateSubscriptionFixedCharge(input: $input) {
      id
    }
  }
`

// Baseline for diffing the drawer values against the plan-level fixed charge.
export type BaselineFixedCharge = Pick<
  FixedChargeForDetailsV2Fragment,
  'code' | 'invoiceDisplayName' | 'chargeModel' | 'properties' | 'taxes'
>

type Args = {
  subscriptionId: string
  // Plan-level fixed charges. Used to send only the fields the user actually
  // changed (see buildInput). When absent, every field is sent.
  fixedCharges?: BaselineFixedCharge[] | null
  // The `refetch` of the no-cache getSubscriptionFixedChargeUnitsOverrides query
  // (owned by SubscriptionDetailsV2Plan). Calling the query's OWN refetch
  // reliably pushes the fresh override units into its React hook; the
  // name-based `client.refetchQueries({ include })` fires the network request
  // but does not reliably update a no-cache query's rendered data, leaving the
  // row showing the stale plan default. When absent, falls back to the
  // name-based refresh.
  refetchOverrides?: () => Promise<unknown>
}

// Recursively drops __typename and sorts object keys, so cached values
// (with __typename, selection-set key order) compare equal to drawer values
// (no __typename, form key order) when nothing changed.
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

const comparableProperties = (
  properties: LocalFixedChargeInput['properties'],
  chargeModel: LocalFixedChargeInput['chargeModel'],
): string =>
  JSON.stringify(
    sortedWithoutTypename(serializeFixedChargeProperties(properties ?? {}, chargeModel)),
  )

const comparableTaxCodes = (taxes: BaselineFixedCharge['taxes']): string =>
  JSON.stringify((taxes ?? []).map((tax) => tax.code).sort((a, b) => a.localeCompare(b)))

export const useSubscriptionFixedChargeMutations = ({
  subscriptionId,
  fixedCharges,
  refetchOverrides,
}: Args) => {
  const client = useApolloClient()
  const [updateSubscriptionFixedCharge] = useUpdateSubscriptionFixedChargeMutation({
    // Only the cached plan query is refreshed here. The override-aware units
    // query is fetchPolicy: 'no-cache', and Apollo's name-based refetchQueries
    // does not reliably re-run no-cache queries — it is refreshed explicitly in
    // handleSaveCharge instead (see below).
    refetchQueries: ['getSubscriptionForDetailsV2Plan'],
    awaitRefetchQueries: true,
    onCompleted(data) {
      if (data?.updateSubscriptionFixedCharge?.id) {
        addToast({ severity: 'success', translateKey: 'text_1779477955768pjf35u2m3ac' })
      }
    },
  })

  // The BE only takes the per-subscription units-override fast path when the
  // params carry nothing but `units` (+ `applyUnitsImmediately`) — any other
  // key, even an unchanged one, falls through to legacy plan-cloning. So each
  // optional field is included only when it differs from the plan-level value.
  // `units` is always sent: on a mixed edit that does clone, it bakes the
  // subscription's current units into the clone so the customer can't
  // silently snap back to the plan default.
  const buildInput = (charge: LocalFixedChargeInput): UpdateSubscriptionFixedChargeInput => {
    const original = fixedCharges?.find((fixedCharge) => fixedCharge.code === charge.code)

    const invoiceDisplayNameChanged =
      !original || (charge.invoiceDisplayName ?? '') !== (original.invoiceDisplayName ?? '')
    // The charge model is not editable in subscription mode, so the drawer's
    // model is also the baseline's — serialize both sides through it.
    const propertiesChanged =
      !original ||
      comparableProperties(charge.properties, charge.chargeModel) !==
        comparableProperties(original.properties, charge.chargeModel)
    const taxesChanged =
      !original || comparableTaxCodes(charge.taxes) !== comparableTaxCodes(original.taxes)

    return {
      subscriptionId,
      fixedChargeCode: charge.code ?? '',
      units: charge.units ? String(charge.units) : '0',
      applyUnitsImmediately: charge.applyUnitsImmediately ?? false,
      ...(invoiceDisplayNameChanged && {
        invoiceDisplayName: charge.invoiceDisplayName || undefined,
      }),
      ...(propertiesChanged && {
        properties: charge.properties
          ? serializeFixedChargeProperties(charge.properties, charge.chargeModel)
          : undefined,
      }),
      ...(taxesChanged && { taxCodes: charge.taxes?.map((t) => t.code) ?? [] }),
    }
  }

  // Sub tab edits only (no create/delete), so the shared handler's index arg is
  // unused here - a narrower-arity fn stays assignable to FixedChargeMutations.
  const handleSaveCharge = async (charge: LocalFixedChargeInput): Promise<boolean> => {
    // Report success only when the mutation actually returned a charge. On error
    // (e.g. a 500, surfaced as a resolved result with `data: null` by the error
    // link) return false so the drawer stays open and the user can re-submit.
    const { data } = await updateSubscriptionFixedCharge({
      variables: { input: buildInput(charge) },
    })

    if (!data?.updateSubscriptionFixedCharge?.id) {
      return false
    }

    // For a units-only override the plan is not cloned, so the cached plan
    // query keeps showing plan defaults — the new units live only in the
    // no-cache getSubscriptionFixedChargeUnitsOverrides query. Refresh it and
    // await it so the list shows the new units once the drawer closes, instead
    // of racing the stale plan default. Prefer the query's OWN refetch (pushes
    // the result into its hook); fall back to the name-based refresh when no
    // refetcher was provided.
    if (refetchOverrides) {
      await refetchOverrides()
    } else {
      await client.refetchQueries({ include: ['getSubscriptionFixedChargeUnitsOverrides'] })
    }

    return true
  }

  // Delete is hidden on the sub tab; no-op to satisfy the shared handler shape.
  const handleDeleteCharge = async (): Promise<boolean> => false

  return { handleSaveCharge, handleDeleteCharge }
}
