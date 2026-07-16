import { useStore } from '@tanstack/react-form'

import { SalesforceIntegration } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

type SalesforceCrmProviderContentProps = {
  hadInitialSalesforceIntegrationCustomer: boolean
  selectedSalesforceIntegration?: SalesforceIntegration
  isEdition?: boolean
}

const defaultProps: SalesforceCrmProviderContentProps = {
  hadInitialSalesforceIntegrationCustomer: false,
  selectedSalesforceIntegration: undefined,
  isEdition: false,
}

const SalesforceCrmProviderContent = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({
    form,
    hadInitialSalesforceIntegrationCustomer,
    selectedSalesforceIntegration,
    isEdition,
  }) {
    const { translate } = useInternationalization()

    const syncWithProvider = useStore(
      form.store,
      (state) => state.values.crmCustomer?.syncWithProvider,
    )

    const handleSyncWithProviderChange = (value: boolean | undefined) => {
      if (!value || isEdition) return

      form.setFieldValue('crmCustomer.crmCustomerId', '')
    }

    return (
      <>
        <form.AppField name="crmCustomer.crmCustomerId">
          {(field) => (
            <field.TextInputField
              disabled={!!syncWithProvider || hadInitialSalesforceIntegrationCustomer}
              label={translate('text_1731677317443jcgfo7s0iqh')}
              placeholder={translate('text_1731677317443j3iga5orbb6')}
            />
          )}
        </form.AppField>
        <form.AppField
          name="crmCustomer.syncWithProvider"
          listeners={{
            onChange: ({ value }) => handleSyncWithProviderChange(value),
          }}
        >
          {(field) => (
            <field.CheckboxField
              disabled={hadInitialSalesforceIntegrationCustomer}
              label={translate('text_66423cad72bbad009f2f569e', {
                connectionName: selectedSalesforceIntegration?.name ?? 'Salesforce',
              })}
            />
          )}
        </form.AppField>
      </>
    )
  },
})

export default SalesforceCrmProviderContent
