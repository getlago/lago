import { useStore } from '@tanstack/react-form'

import { XeroIntegration } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

type XeroAccountingProviderContentProps = {
  hadInitialXeroIntegrationCustomer: boolean
  selectedXeroIntegration?: XeroIntegration
  isEdition?: boolean
}

const defaultProps: XeroAccountingProviderContentProps = {
  hadInitialXeroIntegrationCustomer: false,
  selectedXeroIntegration: undefined,
  isEdition: false,
}

const XeroAccountingProviderContent = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({
    form,
    hadInitialXeroIntegrationCustomer,
    selectedXeroIntegration,
    isEdition,
  }) {
    const { translate } = useInternationalization()

    const syncWithProvider = useStore(
      form.store,
      (state) => state.values.accountingCustomer?.syncWithProvider,
    )

    const handleSyncWithProviderChange = (value: boolean | undefined) => {
      if (!value || isEdition) return

      form.setFieldValue('accountingCustomer.accountingCustomerId', '')
    }

    return (
      <>
        <form.AppField name="accountingCustomer.accountingCustomerId">
          {(field) => (
            <field.TextInputField
              disabled={!!syncWithProvider || hadInitialXeroIntegrationCustomer}
              label={translate('text_667d39dc1a765800d28d0604')}
              placeholder={translate('text_667d39dc1a765800d28d0605')}
            />
          )}
        </form.AppField>
        <form.AppField
          name="accountingCustomer.syncWithProvider"
          listeners={{
            onChange: ({ value }) => handleSyncWithProviderChange(value),
          }}
        >
          {(field) => (
            <field.CheckboxField
              disabled={hadInitialXeroIntegrationCustomer}
              label={translate('text_66423cad72bbad009f2f569e', {
                connectionName: selectedXeroIntegration?.name ?? 'Xero',
              })}
            />
          )}
        </form.AppField>
      </>
    )
  },
})

export default XeroAccountingProviderContent
