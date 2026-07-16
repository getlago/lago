import { Alert } from '~/components/designSystem/Alert'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { BillingEntityOption } from '~/hooks/useBillingEntitiesOptions'

type BillingEntityTaxAlertsProps = {
  /** The billing entity the customer is currently saved with (only set in edit mode). */
  currentBillingEntity?: { code: string; euTaxManagement: boolean } | null
  /** The billing entity code currently selected in the picker. */
  selectedBillingEntityCode?: string | null
  /** All billing entity options — used to resolve the selected entity's EU-tax flag. */
  billingEntities: BillingEntityOption[]
}

/**
 * EU Tax Management is configured per billing entity, so re-pointing a customer
 * to a different entity can change how taxes are computed on future invoices.
 * Renders an info banner in two mutually-exclusive cases:
 *
 *  1. the customer's current entity uses EU tax management and a different
 *     entity is selected;
 *  2. the customer's current entity does NOT use EU tax management but the
 *     selected one does.
 *
 * Both cases require a saved entity to switch FROM, so nothing renders during
 * customer creation. The caller owns the `multi_entity_billing` feature-flag
 * gate; this component is purely the EU-tax display/business logic so it can be
 * unit-tested in isolation.
 */
export const BillingEntityTaxAlerts = ({
  currentBillingEntity,
  selectedBillingEntityCode,
  billingEntities,
}: BillingEntityTaxAlertsProps) => {
  const { translate } = useInternationalization()

  const selectedEntity = billingEntities.find((o) => o.value === selectedBillingEntityCode)
  // Requires a saved entity to switch FROM — naturally restricts to edit mode.
  const isDifferentEntity =
    !!currentBillingEntity?.code && selectedBillingEntityCode !== currentBillingEntity.code

  // Banner 1 — current entity uses EU tax, and a different entity is selected.
  const showCurrentEntityEuTaxAlert = !!currentBillingEntity?.euTaxManagement && isDifferentEntity
  // Banner 2 — current entity does NOT use EU tax, but the selected one does.
  const showSelectedEntityEuTaxAlert =
    !currentBillingEntity?.euTaxManagement && !!selectedEntity?.euTaxManagement && isDifferentEntity

  if (!showCurrentEntityEuTaxAlert && !showSelectedEntityEuTaxAlert) {
    return null
  }

  return (
    <>
      {showCurrentEntityEuTaxAlert && (
        <Alert type="info">{translate('text_1782378031093sfjoizk5vap')}</Alert>
      )}
      {showSelectedEntityEuTaxAlert && (
        <Alert type="info">{translate('text_1782378031093gnp1nv78zfv')}</Alert>
      )}
    </>
  )
}
