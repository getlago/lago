import { screen } from '@testing-library/react'

import { BillingEntityTaxAlerts } from '~/components/billingEntity/BillingEntityTaxAlerts'
import { BillingEntityOption } from '~/hooks/useBillingEntitiesOptions'
import { render } from '~/test-utils'

// Distinguishing clause of each banner — `translate` resolves the real copy
// asynchronously in tests, so we match on text rather than the translation key.
const CURRENT_ENTITY_ALERT_COPY = /Changing the billing entity may change how taxes/i
const SELECTED_ENTITY_ALERT_COPY = /Switching to it may change how taxes/i
const ALERT_INFO_TEST_ID = 'alert-type-info'

const NON_EU_ENTITY = { code: 'TBE', euTaxManagement: false }
const EU_ENTITY = { code: 'ABE', euTaxManagement: true }

const billingEntities: BillingEntityOption[] = [
  { id: '1', value: 'TBE', label: 'TBE', name: 'TBE', isDefault: true, euTaxManagement: false },
  { id: '2', value: 'ABE', label: 'ABE', name: 'ABE', isDefault: false, euTaxManagement: true },
  { id: '3', value: 'CBE', label: 'CBE', name: 'CBE', isDefault: false, euTaxManagement: true },
  { id: '4', value: 'XBE', label: 'XBE', name: 'XBE', isDefault: false, euTaxManagement: false },
]

describe('BillingEntityTaxAlerts', () => {
  describe('WHEN the current entity uses EU tax management', () => {
    it('THEN shows the "current entity" alert when a different entity is selected', async () => {
      render(
        <BillingEntityTaxAlerts
          currentBillingEntity={EU_ENTITY}
          selectedBillingEntityCode="TBE"
          billingEntities={billingEntities}
        />,
      )

      expect(await screen.findByText(CURRENT_ENTITY_ALERT_COPY)).toBeInTheDocument()
      expect(screen.queryByText(SELECTED_ENTITY_ALERT_COPY)).not.toBeInTheDocument()
    })

    it('THEN still shows the "current entity" alert when switching to another EU-tax entity', async () => {
      render(
        <BillingEntityTaxAlerts
          currentBillingEntity={EU_ENTITY}
          selectedBillingEntityCode="CBE"
          billingEntities={billingEntities}
        />,
      )

      expect(await screen.findByText(CURRENT_ENTITY_ALERT_COPY)).toBeInTheDocument()
      expect(screen.queryByText(SELECTED_ENTITY_ALERT_COPY)).not.toBeInTheDocument()
    })

    it('THEN shows no alert when the selected entity matches the saved one', () => {
      render(
        <BillingEntityTaxAlerts
          currentBillingEntity={EU_ENTITY}
          selectedBillingEntityCode="ABE"
          billingEntities={billingEntities}
        />,
      )

      expect(screen.queryByTestId(ALERT_INFO_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('WHEN the current entity does NOT use EU tax management', () => {
    it('THEN shows the "selected entity" alert when switching to an EU-tax entity', async () => {
      render(
        <BillingEntityTaxAlerts
          currentBillingEntity={NON_EU_ENTITY}
          selectedBillingEntityCode="ABE"
          billingEntities={billingEntities}
        />,
      )

      expect(await screen.findByText(SELECTED_ENTITY_ALERT_COPY)).toBeInTheDocument()
      expect(screen.queryByText(CURRENT_ENTITY_ALERT_COPY)).not.toBeInTheDocument()
    })

    it('THEN shows no alert when switching to another non-EU-tax entity', () => {
      render(
        <BillingEntityTaxAlerts
          currentBillingEntity={NON_EU_ENTITY}
          selectedBillingEntityCode="XBE"
          billingEntities={billingEntities}
        />,
      )

      expect(screen.queryByTestId(ALERT_INFO_TEST_ID)).not.toBeInTheDocument()
    })
  })

  describe('WHEN there is no saved customer entity (create mode)', () => {
    it('THEN shows no alert even if the selected entity uses EU tax', () => {
      render(
        <BillingEntityTaxAlerts
          currentBillingEntity={null}
          selectedBillingEntityCode="ABE"
          billingEntities={billingEntities}
        />,
      )

      expect(screen.queryByTestId(ALERT_INFO_TEST_ID)).not.toBeInTheDocument()
    })
  })
})
