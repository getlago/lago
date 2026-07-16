import { useStore } from '@tanstack/react-form'

import { AnrokIntegration } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

type AnrokTaxProviderContentProps = {
  hadInitialAnrokIntegrationCustomer: boolean
  selectedAnrokIntegration?: AnrokIntegration
  isEdition?: boolean
}

const defaultProps: AnrokTaxProviderContentProps = {
  hadInitialAnrokIntegrationCustomer: false,
  selectedAnrokIntegration: undefined,
  isEdition: false,
}

const AnrokTaxProviderContent = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({
    form,
    hadInitialAnrokIntegrationCustomer,
    selectedAnrokIntegration,
    isEdition,
  }) {
    const { translate } = useInternationalization()

    const syncWithProvider = useStore(
      form.store,
      (state) => state.values.taxCustomer?.syncWithProvider,
    )

    const handleSyncWithProviderChange = (value: boolean | undefined) => {
      if (!value || isEdition) return

      form.setFieldValue('taxCustomer.taxCustomerId', '')
    }

    return (
      <>
        <form.AppField name="taxCustomer.taxCustomerId">
          {(field) => (
            <field.TextInputField
              disabled={!!syncWithProvider || hadInitialAnrokIntegrationCustomer}
              label={translate('text_66b4e77677f8c600c8d50ea3')}
              placeholder={translate('text_66b4e77677f8c600c8d50ea5')}
            />
          )}
        </form.AppField>
        <form.AppField
          name="taxCustomer.syncWithProvider"
          listeners={{
            onChange: ({ value }) => handleSyncWithProviderChange(value),
          }}
        >
          {(field) => (
            <field.CheckboxField
              disabled={hadInitialAnrokIntegrationCustomer}
              label={translate('text_66b4e77677f8c600c8d50ea7', {
                connectionName: selectedAnrokIntegration?.name ?? 'Anrok',
              })}
            />
          )}
        </form.AppField>
      </>
    )
  },
})

export default AnrokTaxProviderContent
