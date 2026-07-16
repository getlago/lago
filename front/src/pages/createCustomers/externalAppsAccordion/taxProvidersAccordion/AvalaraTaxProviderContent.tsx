import { useStore } from '@tanstack/react-form'

import { AvalaraIntegration } from '~/generated/graphql'
import { useInternationalization } from '~/hooks/core/useInternationalization'
import { withForm } from '~/hooks/forms/useAppform'
import { emptyCreateCustomerDefaultValues } from '~/pages/createCustomers/formInitialization/validationSchema'

type AvalaraTaxProviderContentProps = {
  hadInitialAvalaraIntegrationCustomer: boolean
  selectedAvalaraIntegration?: AvalaraIntegration
  isEdition?: boolean
}

const defaultProps: AvalaraTaxProviderContentProps = {
  hadInitialAvalaraIntegrationCustomer: false,
  selectedAvalaraIntegration: undefined,
  isEdition: false,
}

const AvalaraTaxProviderContent = withForm({
  defaultValues: emptyCreateCustomerDefaultValues,
  props: defaultProps,
  render: function Render({
    form,
    hadInitialAvalaraIntegrationCustomer,
    selectedAvalaraIntegration,
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
              disabled={!!syncWithProvider || hadInitialAvalaraIntegrationCustomer}
              label={translate('text_1745827156646ff5h5i281gc')}
              placeholder={translate('text_1745827156646zoyf7wmog2m')}
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
              disabled={hadInitialAvalaraIntegrationCustomer}
              label={translate('text_66423cad72bbad009f2f569e', {
                connectionName: selectedAvalaraIntegration?.name ?? 'Avalara',
              })}
            />
          )}
        </form.AppField>
      </>
    )
  },
})

export default AvalaraTaxProviderContent
