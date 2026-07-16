import { useInternationalization } from '~/hooks/core/useInternationalization'
import { useBillingEntitiesOptions } from '~/hooks/useBillingEntitiesOptions'

type CustomerBillingEntityRef = { name?: string | null; code?: string | null } | null | undefined

type BillingEntityLabelProps = {
  /** UUID stored on the row (Subscription.billingEntityId / Wallet.billingEntityId). */
  ownId?: string | null
  /** Fallback used when `ownId` is null — typically `customer.billingEntity`. */
  customerEntity?: CustomerBillingEntityRef
}

/**
 * Renders a billing-entity label following the dive-in precedence:
 *
 *   1. If the row has its own `billingEntityId`, resolve it to the entity's
 *      label via the org's billing-entities collection.
 *   2. Otherwise, fall back to the customer's default entity with an
 *      "(inherit from customer)" suffix to surface the implicit semantics.
 *   3. If neither is available, render `-`.
 *
 * Returns a plain string. Callers wrap with Typography when needed.
 */
export const BillingEntityLabel = ({ ownId, customerEntity }: BillingEntityLabelProps) => {
  const { translate } = useInternationalization()
  const { options } = useBillingEntitiesOptions()

  if (ownId) {
    const own = options.find((o) => o.id === ownId)
    const ownLabel = own?.name || own?.value

    if (ownLabel) {
      return <>{ownLabel}</>
    }
  }

  const inheritedLabel = customerEntity?.name || customerEntity?.code

  if (!inheritedLabel) return <>-</>
  return <>{`${inheritedLabel} (${translate('text_1764327933607jgtpungo2pp')})`}</>
}
